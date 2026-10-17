import '../domain/account_read_session.dart';
import '../domain/scoped_cache_models.dart';
import '../domain/server_account_models.dart';
import '../domain/server_account_read_repository.dart';
import '../domain/server_character_lifecycle.dart';
import 'backend_account_read_api.dart';
import 'repositories/scoped_character_cache_repository.dart';

class RetirementContinuation {
  RetirementContinuation._(
    this._owner,
    this._scope,
    this._session,
    this._serial,
    this._cursor,
    this._revision,
    this._cursors,
    this._ids,
  );
  final Object _owner;
  final StorageScope _scope;
  final AccountReadScope _session;
  final int _serial, _revision;
  final String _cursor;
  final Set<String> _cursors, _ids;
  bool _used = false;
}

class RetirementRead {
  RetirementRead(this.page, this.next);
  final CharacterRetirementPage page;
  final RetirementContinuation? next;
}

/// Opt-in adapter only; no runtime DI, disk defaults, or legacy-ID writes.
/// The transport supplies Bearer/session recovery and preserves server errors.
class ServerCharacterLifecycleClient {
  ServerCharacterLifecycleClient(
    this.api, {
    ServerAccountReadRepository? registrations,
  }) : _baseUrl = api.dio.options.baseUrl,
       _registrations =
           registrations ?? ServerAccountReadRepository(api, api.session) {
    if (!identical(_registrations.api, api) ||
        !identical(_registrations.session, api.session)) {
      throw const AccountReadException('SCOPE_MISMATCH');
    }
  }
  final DioBackendAccountReadApi api;
  final String _baseUrl;
  final ServerAccountReadRepository _registrations;
  final Object _owner = Object();
  int _historySerial = 0;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _historySerial++;
  }

  StorageScope get _scope => StorageScope(
    baseUrl: _baseUrl,
    userId: accountReadScope(api.session).userId,
    allowHttp: true,
  );

  void _guard(StorageScope scope, AccountReadScope session) {
    if (_disposed) throw const AccountReadException('DISPOSED');
    requireAccountReadScope(api.session, session);
    final actual = StorageScope(
      baseUrl: api.dio.options.baseUrl,
      userId: session.userId,
      allowHttp: true,
    );
    if (_scope != scope || actual != scope) {
      throw const AccountReadException('ENVIRONMENT_CHANGED');
    }
  }

  void _cacheScope(ScopedCharacterCacheRepository cache, StorageScope scope) {
    if (!identical(cache.session, api.session) || cache.scope != scope) {
      throw const AccountReadException('SCOPE_MISMATCH');
    }
  }

  Future<Map<String, dynamic>> _get(
    String path,
    StorageScope scope,
    AccountReadScope session, {
    String? cursor,
  }) async {
    _guard(scope, session);
    final json = await api.request(
      path,
      query: {'limit': 50, 'cursor': ?cursor},
    );
    _guard(scope, session);
    if (json == null) throw const AccountReadException('INVALID_RESPONSE');
    return json;
  }

  Future<T> _decode<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  /// A failed/partial registration read never becomes an empty current list.
  Future<List<ServerAccountRegistration>> refreshRegistrations(
    ScopedCharacterCacheRepository cache, {
    bool shareInFlight = false,
  }) async {
    final session = accountReadScope(api.session), scope = _scope;
    _guard(scope, session);
    _cacheScope(cache, scope);
    final read = await cache.beginRegistrations();
    _guard(scope, session);
    final registrations = await _registrations.loadRegistrations(
      shareInFlight: shareInFlight,
    );
    _guard(scope, session);
    _cacheScope(cache, scope);
    final snapshots = registrations.map(_registration).toList(growable: false);
    await cache.applyRegistrations(read, snapshots);
    _guard(scope, session);
    return List.unmodifiable(registrations);
  }

  Future<CacheValidationReceipt?> refreshRoster(
    ScopedCharacterCacheRepository cache,
    ScopedRegistrationRef ref,
  ) => _decode(() async {
    final session = accountReadScope(api.session), scope = _scope;
    _guard(scope, session);
    _cacheScope(cache, scope);
    if (ref.scope != scope) throw const AccountReadException('SCOPE_MISMATCH');
    final read = await cache.beginRoster(ref);
    _guard(scope, session);
    if (read.registration.sourceContract != lifecycleContract) {
      throw const AccountReadException('CONTRACT_MISMATCH');
    }
    final characters = <LifecycleCharacter>[];
    final ids = <String>{}, cursors = <String>{};
    final names = <(String, String)>{};
    LifecycleCharacterPage? first;
    String? cursor;
    // At most 200 characters, including a possibly short page per character.
    for (var page = 0; page < 201; page++) {
      final result = LifecycleCharacterPage.fromJson(
        await _get(
          '/v2/me/game-accounts/${ref.registrationId}/characters',
          scope,
          session,
          cursor: cursor,
        ),
      );
      if (result.registrationId != ref.registrationId) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
      first ??= result;
      if (!first.sameStructure(result)) {
        throw const AccountReadException('CURSOR_STALE', status: 409);
      }
      final normalized = result.registration(read.registration.label);
      if (!read.registration.sameStructure(normalized) ||
          !sameLifecycleSettings(
            _settingsFromCache(read.registration),
            result.settingsWire,
          )) {
        throw const AccountReadException('REVISION_CONFLICT', status: 409);
      }
      for (final item in result.items) {
        if (!names.add((item.serverName, item.characterName)) ||
            (item.characterId != null && !ids.add(item.characterId!))) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        characters.add(item);
      }
      if (characters.length > 200) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
      cursor = result.nextCursor;
      if (cursor == null) {
        _guard(scope, session);
        _cacheScope(cache, scope);
        final snapshot = CacheRosterSnapshot(
          first.registration(read.registration.label, characters),
          characters
              .where((c) => c.characterId != null)
              .map(
                (c) => CacheCharacterObservation(
                  characterId: c.characterId!,
                  accountId: first!.accountId!,
                  serverName: c.serverName,
                  characterName: c.characterName,
                  lifecycleState: c.lifecycleState,
                  lifecycleRevision: c.lifecycleRevision,
                  usable: c.usable,
                  blockedReason: c.blockedReason,
                  profile: c.wire,
                ),
              ),
        );
        final receipt = await cache.applyRoster(read, snapshot);
        _guard(scope, session);
        return receipt;
      }
      if (result.items.isEmpty || !cursors.add(cursor)) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
    }
    throw const AccountReadException('INVALID_RESPONSE');
  });

  /// One page per explicit call. Continuations are client/member/session bound,
  /// single-use and invalidated by a fresh first-page read. No history is erased.
  Future<RetirementRead> readRetirements({RetirementContinuation? next}) =>
      _decode(() async {
        final session = accountReadScope(api.session), scope = _scope;
        _guard(scope, session);
        final serial = next == null ? ++_historySerial : next._serial;
        if (next != null) {
          if (!identical(next._owner, _owner) ||
              next._scope != scope ||
              next._session != session ||
              next._serial != _historySerial ||
              next._used) {
            throw const AccountReadException('STALE_READ');
          }
          next._used = true;
        }
        final page = CharacterRetirementPage.fromJson(
          await _get(
            '/v2/me/character-retirements',
            scope,
            session,
            cursor: next?._cursor,
          ),
        );
        if (serial != _historySerial) {
          throw const AccountReadException('STALE_READ');
        }
        if (next != null && next._revision != page.revision) {
          throw const AccountReadException('CURSOR_STALE', status: 409);
        }
        final cursors = {...?next?._cursors}, ids = {...?next?._ids};
        // Bound continuation memory; callers may start a fresh traversal.
        if (ids.length + page.items.length > 10000) {
          throw const AccountReadException('HISTORY_READ_LIMIT');
        }
        for (final item in page.items) {
          if (!ids.add(item.historyId)) {
            throw const AccountReadException('INVALID_RESPONSE');
          }
        }
        final cursor = page.nextCursor;
        if (cursor != null && (page.items.isEmpty || !cursors.add(cursor))) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        return RetirementRead(
          page,
          cursor == null
              ? null
              : RetirementContinuation._(
                  _owner,
                  scope,
                  session,
                  serial,
                  cursor,
                  page.revision,
                  Set.unmodifiable(cursors),
                  Set.unmodifiable(ids),
                ),
        );
      });
}

Map<String, dynamic> _settings(ServerCharacterSettings s) => {
  'configuration_state': s.configurationState,
  'activity_character_ids': s.activityCharacterIds,
  'representative_character_id': s.representativeCharacterId,
  'settings_version': s.settingsVersion,
  'ownership_revision': s.ownershipRevision,
  'next_change_at': s.nextChangeAt?.toIso8601String(),
  'selection_complete': s.selectionComplete,
  'ineligible_character_ids': s.ineligibleCharacterIds,
};

Map<String, dynamic> _settingsFromCache(CacheRegistrationSnapshot r) =>
    (r.toStorage()['display'] as Map<String, dynamic>)['settings']
        as Map<String, dynamic>;

CacheRegistrationSnapshot _registration(ServerAccountRegistration r) {
  if (r.rosterRevision == null && r.gameAccountId != null) {
    throw const AccountReadException('INCOMPLETE_METADATA');
  }
  return CacheRegistrationSnapshot(
    registrationId: r.registrationId,
    accountId: r.gameAccountId,
    version: r.version,
    isMain: r.isMain,
    label: r.label,
    ownershipStatus: r.ownershipStatus,
    ownershipRevision: r.ownershipRevision,
    // c91af2e lifecycle_reads.characters uses registration.version for preview.
    // V1 registration_out exposes null here when there is no canonical account.
    rosterRevision: r.rosterRevision ?? r.version,
    settings: CacheSettings(
      version: r.settings.settingsVersion,
      state: r.settings.configurationState,
      activityIds: r.settings.activityCharacterIds,
      representativeId: r.settings.representativeCharacterId,
    ),
    fetchedAt: r.serverFetchedAt,
    sourceContract: lifecycleContract,
    display: {'settings': _settings(r.settings)},
  );
}
