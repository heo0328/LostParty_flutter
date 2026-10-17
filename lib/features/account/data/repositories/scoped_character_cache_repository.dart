import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/account_read_session.dart';
import '../../domain/scoped_cache_models.dart';
import '../local/scoped_account_cache_database.dart';

abstract class CacheReadToken {
  CacheReadToken._(
    this.scope,
    this._owner,
    this._epoch,
    this._sequence,
    this._registrationSerial,
  );
  final StorageScope scope;
  final Object _owner;
  final int _epoch, _sequence, _registrationSerial;
  String get _target;
}

class RegistrationCacheRead extends CacheReadToken {
  RegistrationCacheRead._(
    super.scope,
    super.owner,
    super.epoch,
    super.sequence,
    super.registrationSerial,
    this.expectedVersion,
  ) : super._();
  final int expectedVersion;
  @override
  String get _target => 'registrations';
}

class RosterCacheRead extends CacheReadToken {
  RosterCacheRead._(
    super.scope,
    super.owner,
    super.epoch,
    super.sequence,
    super.registrationSerial,
    this.registration,
    this.scopeVersion,
    this.registrationSequence,
    this.registrationVersion,
    this.headVersion,
  ) : super._();
  final CacheRegistrationSnapshot registration;
  final int scopeVersion,
      registrationSequence,
      registrationVersion,
      headVersion;
  @override
  String get _target => registration.registrationId;
}

class CacheValidationReceipt {
  CacheValidationReceipt._(this._read, this._headVersion);
  final RosterCacheRead _read;
  final int _headVersion;
}

class CachedRosterView {
  CachedRosterView(
    this.registration,
    Iterable<CacheCharacterObservation> items, {
    required this.validated,
    required this.complete,
  }) : characters = List.unmodifiable(items);
  final CacheRegistrationSnapshot registration;
  final List<CacheCharacterObservation> characters;

  /// A current cache receipt, never a grant of server command authority.
  final bool validated, complete;
}

/// Uses only a separately supplied cache DB. It never opens a disk DB or invokes
/// AccountRepository, the legacy name-based writers, or a network transport.
class ScopedCharacterCacheRepository {
  ScopedCharacterCacheRepository(
    this.db,
    this.session, {
    required String baseUrl,
    bool allowHttp = false,
  }) : _baseUrl = baseUrl,
       _allowHttp = allowHttp {
    _sessionKey = (session.userId, session.generation, session.isAuthenticated);
    // Validate environment even when no member is signed in.
    StorageScope(
      baseUrl: baseUrl,
      userId: '00000000-0000-4000-8000-000000000000',
      allowHttp: allowHttp,
    );
    session.addListener(_onSession);
  }
  final ScopedAccountCacheDatabase db;
  final AccountReadSession session;
  String _baseUrl;
  final bool _allowHttp;
  final Object _owner = Object();
  int _epoch = 0, _serial = 0, _registrationSerial = 0;
  final Map<String, int> _latest = {};
  late (String?, int, bool) _sessionKey;
  bool _disposed = false;
  Future<void> _tail = Future.value();

  StorageScope get scope {
    cacheRequire(
      !_disposed && session.isAuthenticated && session.userId != null,
      'SCOPE_CHANGED',
    );
    return StorageScope(
      baseUrl: _baseUrl,
      userId: session.userId!,
      allowHttp: _allowHttp,
    );
  }

  void _onSession() {
    final key = (session.userId, session.generation, session.isAuthenticated);
    if (key == _sessionKey) return;
    _sessionKey = key;
    _invalidate();
  }

  void _invalidate() {
    _epoch++;
    _latest.clear();
    _registrationSerial = ++_serial;
  }

  /// Invalidate in-flight reads/receipts immediately, before queued metadata GET.
  /// Existing disk observations remain available as unvalidated history.
  void invalidateReads() => _invalidate();

  void changeEnvironment(String baseUrl) {
    final candidate = StorageScope(
      baseUrl: baseUrl,
      userId: session.userId ?? '00000000-0000-4000-8000-000000000000',
      allowHttp: _allowHttp,
    );
    final previous = StorageScope(
      baseUrl: _baseUrl,
      userId: candidate.userId,
      allowHttp: _allowHttp,
    );
    _baseUrl = baseUrl;
    if (candidate.environment != previous.environment) _invalidate();
  }

  void _requireScope(StorageScope expected) =>
      cacheRequire(scope == expected, 'SCOPE_CHANGED');
  bool _current(CacheReadToken read) =>
      !_disposed &&
      identical(read._owner, _owner) &&
      read._epoch == _epoch &&
      session.isAuthenticated &&
      session.userId?.toLowerCase() == read.scope.userId &&
      session.generation == _sessionKey.$2 &&
      _latest[read._target] == read._sequence &&
      read._registrationSerial == _registrationSerial;
  void _requireToken(CacheReadToken read) {
    cacheRequire(_current(read), 'STALE_READ');
    _requireScope(read.scope);
  }

  Future<T> _write<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<CacheScope?> _scopeRow(StorageScope key) =>
      (db.select(db.cacheScopes)..where(
            (t) =>
                t.environment.equals(key.environment) &
                t.userId.equals(key.userId),
          ))
          .getSingleOrNull();
  Future<CachedRegistration?> _registration(int sid, String id) =>
      (db.select(db.cachedRegistrations)
            ..where((t) => t.scopeId.equals(sid) & t.registrationId.equals(id)))
          .getSingleOrNull();
  Future<CachedAccountHead?> _head(int sid, String? id) async => id == null
      ? null
      : await (db.select(db.cachedAccountHeads)
              ..where((t) => t.scopeId.equals(sid) & t.accountId.equals(id)))
            .getSingleOrNull();
  CacheRegistrationSnapshot _decode(String data) =>
      CacheRegistrationSnapshot.fromStorage(
        jsonDecode(data) as Map<String, dynamic>,
      );

  Future<RegistrationCacheRead> beginRegistrations() async {
    final key = scope, epoch = _epoch, serial = ++_serial;
    _registrationSerial = serial;
    _latest['registrations'] = serial;
    final row = await _scopeRow(key);
    final result = RegistrationCacheRead._(
      key,
      _owner,
      epoch,
      serial,
      serial,
      row?.localVersion ?? 0,
    );
    _requireToken(result);
    return result;
  }

  Future<RosterCacheRead> beginRoster(ScopedRegistrationRef ref) async {
    _requireScope(ref.scope);
    final epoch = _epoch,
        serial = ++_serial,
        registrationSerial = _registrationSerial;
    _latest[ref.registrationId] = serial;
    final read = await db.transaction(() async {
      final s = await _scopeRow(ref.scope);
      cacheRequire(s != null, 'REGISTRATION_NOT_CURRENT');
      final r = await _registration(s!.id, ref.registrationId);
      cacheRequire(
        r != null && r.seenSequence == s.snapshotSequence,
        'REGISTRATION_NOT_CURRENT',
      );
      final value = _decode(r!.payload), head = await _head(s.id, r.accountId);
      return RosterCacheRead._(
        ref.scope,
        _owner,
        epoch,
        serial,
        registrationSerial,
        value,
        s.localVersion,
        s.snapshotSequence,
        r.localVersion,
        head?.localVersion ?? 0,
      );
    });
    _requireToken(read);
    return read;
  }

  void _progress(CachedAccountHead? previous, CacheRegistrationSnapshot next) {
    if (previous == null) return;
    cacheRequire(
      next.rosterRevision >= previous.rosterRevisionFloor,
      'REVISION_REGRESSION',
    );
    final revision = next.ownershipRevision,
        floor = previous.ownershipRevisionFloor;
    if (revision != null && floor != null) {
      cacheRequire(revision >= floor, 'REVISION_REGRESSION');
    }
    if (revision != null && revision == previous.settingsOwnershipRevision) {
      cacheRequire(
        next.settings.version >= previous.settingsVersionFloor,
        'REVISION_REGRESSION',
      );
    }
  }

  Future<void> _putHead(
    int sid,
    CacheRegistrationSnapshot value,
    CachedAccountHead? old, {
    required bool complete,
    required int sequence,
  }) async {
    _progress(old, value);
    final ownership = value.ownershipRevision ?? old?.ownershipRevisionFloor;
    final settingsOwner =
        value.ownershipRevision ?? old?.settingsOwnershipRevision;
    final settingsVersion = value.ownershipRevision == null
        ? (old?.settingsVersionFloor ?? 0)
        : value.settings.version;
    await db
        .into(db.cachedAccountHeads)
        .insertOnConflictUpdate(
          CachedAccountHeadsCompanion.insert(
            scopeId: sid,
            accountId: value.accountId!,
            payload: jsonEncode(value.toStorage()),
            localVersion: Value((old?.localVersion ?? 0) + 1),
            snapshotSequence: Value(sequence),
            complete: Value(complete),
            ownershipRevisionFloor: Value(ownership),
            rosterRevisionFloor: Value(value.rosterRevision),
            settingsOwnershipRevision: Value(settingsOwner),
            settingsVersionFloor: Value(settingsVersion),
          ),
        );
  }

  Future<void> applyRegistrations(
    RegistrationCacheRead read,
    Iterable<CacheRegistrationSnapshot> values,
  ) {
    final rows = List<CacheRegistrationSnapshot>.unmodifiable(values);
    return _write(() async {
      _requireToken(read);
      cacheRequire(
        rows.length <= 20 &&
            rows.where((r) => r.isMain).length <= 1 &&
            rows.map((r) => r.registrationId).toSet().length == rows.length &&
            rows.map((r) => r.accountId).whereType<String>().toSet().length ==
                rows.where((r) => r.accountId != null).length &&
            rows.map((r) => r.sourceContract).toSet().length <= 1,
      );
      await db.transaction(() async {
        var s = await _scopeRow(read.scope);
        cacheRequire(
          (s?.localVersion ?? 0) == read.expectedVersion,
          'CACHE_CONFLICT',
        );
        if (s == null) {
          final sid = await db
              .into(db.cacheScopes)
              .insert(
                CacheScopesCompanion.insert(
                  environment: read.scope.environment,
                  userId: read.scope.userId,
                ),
              );
          s = await (db.select(
            db.cacheScopes,
          )..where((t) => t.id.equals(sid))).getSingle();
        }
        final sequence = s.snapshotSequence + 1;
        for (final value in rows) {
          final old = await _registration(s.id, value.registrationId);
          if (old != null) {
            final before = _decode(old.payload);
            cacheRequire(
              value.version >= before.version,
              'REVISION_REGRESSION',
            );
            cacheRequire(
              value.accountId == before.accountId ||
                  value.version > before.version,
              'IDENTITY_CONFLICT',
            );
          }
          if (value.accountId != null) {
            final h = await _head(s.id, value.accountId);
            _progress(h, value);
            if (h == null) {
              await _putHead(s.id, value, null, complete: false, sequence: 0);
            } else {
              // Preserve the complete roster payload, but remember revision
              // high-water marks from newer registration observations too.
              await (db.update(db.cachedAccountHeads)..where(
                    (t) =>
                        t.scopeId.equals(s!.id) &
                        t.accountId.equals(value.accountId!),
                  ))
                  .write(
                    CachedAccountHeadsCompanion(
                      localVersion: Value(h.localVersion + 1),
                      ownershipRevisionFloor: Value(
                        value.ownershipRevision ?? h.ownershipRevisionFloor,
                      ),
                      rosterRevisionFloor: Value(value.rosterRevision),
                      settingsOwnershipRevision: Value(
                        value.ownershipRevision ?? h.settingsOwnershipRevision,
                      ),
                      settingsVersionFloor: Value(
                        value.ownershipRevision == null
                            ? h.settingsVersionFloor
                            : value.settings.version,
                      ),
                    ),
                  );
            }
          }
          await db
              .into(db.cachedRegistrations)
              .insertOnConflictUpdate(
                CachedRegistrationsCompanion.insert(
                  scopeId: s.id,
                  registrationId: value.registrationId,
                  accountId: Value(value.accountId),
                  payload: jsonEncode(value.toStorage()),
                  seenSequence: sequence,
                  localVersion: Value((old?.localVersion ?? 0) + 1),
                ),
              );
        }
        await (db.update(
          db.cacheScopes,
        )..where((t) => t.id.equals(s!.id))).write(
          CacheScopesCompanion(
            localVersion: Value(s.localVersion + 1),
            snapshotSequence: Value(sequence),
          ),
        );
        _requireToken(read);
      });
      _requireToken(read);
    });
  }

  Future<CacheValidationReceipt?> applyRoster(
    RosterCacheRead read,
    CacheRosterSnapshot snapshot,
  ) => _write(() async {
    _requireToken(read);
    cacheRequire(
      read.registration.sameStructure(snapshot.registration),
      'SNAPSHOT_MISMATCH',
    );
    final version = await db.transaction(() async {
      final s = await _scopeRow(read.scope);
      cacheRequire(
        s != null &&
            s.localVersion == read.scopeVersion &&
            s.snapshotSequence == read.registrationSequence,
        'CACHE_CONFLICT',
      );
      final r = await _registration(s!.id, read.registration.registrationId);
      cacheRequire(
        r != null &&
            r.localVersion == read.registrationVersion &&
            r.seenSequence == s.snapshotSequence,
        'CACHE_CONFLICT',
      );
      final old = await _head(s.id, r!.accountId);
      cacheRequire(
        (old?.localVersion ?? 0) == read.headVersion,
        'CACHE_CONFLICT',
      );
      final incoming = snapshot.registration;
      if (incoming.accountId == null) {
        await (db.update(db.cachedRegistrations)..where(
              (t) =>
                  t.scopeId.equals(s.id) &
                  t.registrationId.equals(r.registrationId),
            ))
            .write(
              CachedRegistrationsCompanion(
                payload: Value(jsonEncode(incoming.toStorage())),
                localVersion: Value(r.localVersion + 1),
              ),
            );
        _requireToken(read);
        return null;
      }
      _progress(old, incoming);
      final sequence = (old?.snapshotSequence ?? 0) + 1;
      await _putHead(s.id, incoming, old, complete: true, sequence: sequence);
      for (final value in snapshot.characters) {
        final existing =
            await (db.select(db.cachedCharacters)..where(
                  (t) =>
                      t.scopeId.equals(s.id) &
                      t.characterId.equals(value.characterId),
                ))
                .getSingleOrNull();
        if (existing != null) {
          cacheRequire(
            existing.accountId == value.accountId,
            'IDENTITY_CONFLICT',
          );
          final before = CacheCharacterObservation.fromStorage(
            jsonDecode(existing.payload) as Map<String, dynamic>,
          );
          // Under the current contract a renamed character starts with a new ID.
          cacheRequire(
            before.serverName == value.serverName &&
                before.characterName == value.characterName,
            'IDENTITY_CONFLICT',
          );
          if (before.lifecycleRevision != null) {
            cacheRequire(
              value.lifecycleRevision != null &&
                  value.lifecycleRevision! >= before.lifecycleRevision!,
              'REVISION_REGRESSION',
            );
          }
          cacheRequire(
            before.lifecycleState != 'retired' ||
                value.lifecycleState == 'retired',
            'IDENTITY_CONFLICT',
          );
        }
        await db
            .into(db.cachedCharacters)
            .insertOnConflictUpdate(
              CachedCharactersCompanion.insert(
                scopeId: s.id,
                characterId: value.characterId,
                accountId: value.accountId,
                seenSequence: sequence,
                localVersion: Value((existing?.localVersion ?? 0) + 1),
                payload: jsonEncode(value.toStorage()),
              ),
            );
      }
      _requireToken(read);
      return (old?.localVersion ?? 0) + 1;
    });
    _requireToken(read);
    return version == null ? null : CacheValidationReceipt._(read, version);
  });

  Future<List<CacheRegistrationSnapshot>> readRegistrations(
    StorageScope key,
  ) async {
    _requireScope(key);
    final epoch = _epoch;
    final result = await db.transaction(() async {
      final s = await _scopeRow(key);
      if (s == null) return <CacheRegistrationSnapshot>[];
      final rows =
          await (db.select(db.cachedRegistrations)..where(
                (t) =>
                    t.scopeId.equals(s.id) &
                    t.seenSequence.equals(s.snapshotSequence),
              ))
              .get();
      return rows.map((r) => _decode(r.payload)).toList();
    });
    _requireScope(key);
    cacheRequire(epoch == _epoch, 'SCOPE_CHANGED');
    return List.unmodifiable(result);
  }

  Future<CachedRosterView?> readRoster(
    ScopedRegistrationRef ref, {
    CacheValidationReceipt? receipt,
  }) async {
    _requireScope(ref.scope);
    final epoch = _epoch;
    final result = await db.transaction(() async {
      final s = await _scopeRow(ref.scope);
      if (s == null) return null;
      final r = await _registration(s.id, ref.registrationId);
      if (r == null || r.seenSequence != s.snapshotSequence) return null;
      final reg = _decode(r.payload), head = await _head(s.id, r.accountId);
      final coherent =
          head != null &&
          head.complete &&
          _decode(head.payload).sameStructure(reg);
      final rows = coherent
          ? await (db.select(db.cachedCharacters)..where(
                  (t) =>
                      t.scopeId.equals(s.id) &
                      t.accountId.equals(r.accountId!) &
                      t.seenSequence.equals(head.snapshotSequence),
                ))
                .get()
          : <CachedCharacter>[];
      return CachedRosterView(
        coherent ? _decode(head.payload) : reg,
        rows.map(
          (c) => CacheCharacterObservation.fromStorage(
            jsonDecode(c.payload) as Map<String, dynamic>,
          ),
        ),
        complete: coherent,
        validated:
            coherent &&
            receipt != null &&
            _current(receipt._read) &&
            receipt._read.registration.registrationId == ref.registrationId &&
            receipt._headVersion == head.localVersion &&
            receipt._read.scopeVersion == s.localVersion &&
            receipt._read.registrationVersion == r.localVersion,
      );
    });
    _requireScope(ref.scope);
    cacheRequire(epoch == _epoch, 'SCOPE_CHANGED');
    return result;
  }

  /// Retained observation only; it may be absent from the current roster.
  /// Use readRoster and a current receipt to assess cache freshness.
  Future<CacheCharacterObservation?> readCharacter(
    ScopedCharacterRef ref,
  ) async {
    _requireScope(ref.scope);
    final epoch = _epoch, s = await _scopeRow(ref.scope);
    final row = s == null
        ? null
        : await (db.select(db.cachedCharacters)..where(
                (t) =>
                    t.scopeId.equals(s.id) &
                    t.accountId.equals(ref.accountId) &
                    t.characterId.equals(ref.characterId),
              ))
              .getSingleOrNull();
    _requireScope(ref.scope);
    cacheRequire(epoch == _epoch, 'SCOPE_CHANGED');
    return row == null
        ? null
        : CacheCharacterObservation.fromStorage(
            jsonDecode(row.payload) as Map<String, dynamic>,
          );
  }

  void dispose() {
    _disposed = true;
    _invalidate();
    session.removeListener(_onSession);
  }
}
