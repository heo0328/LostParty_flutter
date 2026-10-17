import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../domain/account_read_session.dart';
import '../../domain/personal_settings.dart';
import '../../domain/role_summary.dart';
import '../../domain/scoped_cache_models.dart';
import '../local/scoped_account_cache_database.dart';
import '../local/scoped_command_key.dart';
import 'scoped_character_cache_repository.dart';

enum SettingKind { preferences, presentation }

class ScopedSettingsPlan {
  ScopedSettingsPlan._(
    this._owner,
    this.epoch,
    this.session,
    this.registration,
    this.character,
    this.kind,
    this.targetId,
    this.accountId,
    this.ownershipRevision,
    this.lifecycleRevision,
    this.lifecycleState,
    this.scopeId,
    this.scopeVersion,
    this.registrationVersion,
    this.rowVersion,
    this.serverJson,
    this.headVersion,
    this.characterVersion,
    this._guard,
  );
  final Object _owner;
  final int epoch,
      scopeId,
      scopeVersion,
      registrationVersion,
      ownershipRevision,
      rowVersion;
  final AccountReadScope session;
  final ScopedRegistrationRef registration;
  final ScopedCharacterRef? character;
  final SettingKind kind;
  final String targetId, accountId, serverJson;
  final int? lifecycleRevision;
  final int? headVersion, characterVersion;
  final String? lifecycleState;
  final void Function()? _guard;
  Map<String, dynamic> get server => roleMap(jsonDecode(serverJson));
}

class ScopedSettingCommand {
  ScopedSettingCommand._(
    this.id,
    this.registrationId,
    this.localRevision,
    this._body,
    this.firstSentAt,
    this.retryAt,
    this.state,
    this.errorCode,
  );
  final String id, registrationId, _body, state;
  final int localRevision;
  final DateTime? firstSentAt, retryAt;
  final String? errorCode;
  Map<String, dynamic> get body => roleMap(jsonDecode(_body));
}

class ScopedSettingsState {
  ScopedSettingsState._(
    this.kind,
    this._payload,
    this.command, {
    this.fromCache = false,
  });

  /// Retained display observation; never a fresh write plan or server ACK.
  final bool fromCache;
  final SettingKind kind;
  final String _payload;
  final ScopedSettingCommand? command;
  Map<String, dynamic> get _data => roleMap(jsonDecode(_payload));
  bool get hasPending =>
      (_data['local_revision'] as int) >
      (_data['acknowledged_revision'] as int);
  Map<String, dynamic> get server => roleMap(_data['server']);
  Map<String, dynamic> get displayValues =>
      hasPending ? roleMap(_data['values']) : settingValues(kind, server);
  PreferenceValues get preferences {
    cacheRequire(kind == SettingKind.preferences);
    return PreferenceValues.fromJson(displayValues);
  }

  int get visibleCount {
    cacheRequire(kind == SettingKind.presentation);
    return presentationCount(displayValues['visible_count']);
  }
}

Map<String, dynamic> settingValues(
  SettingKind kind,
  Map<String, dynamic> server,
) => kind == SettingKind.preferences
    ? PersonalPreferences.fromJson(server).values.toJson()
    : {'visible_count': AccountPresentation.fromJson(server).visibleCount};

/// P2 values and commands share one transaction and the canonical cache DB.
class ScopedSettingsRepository {
  ScopedSettingsRepository(this.cache) {
    _sessionKey = (
      cache.session.userId,
      cache.session.generation,
      cache.session.isAuthenticated,
    );
    cache.session.addListener(_sessionChanged);
  }
  final ScopedCharacterCacheRepository cache;
  ScopedAccountCacheDatabase get db => cache.db;
  final Object _owner = Object();
  late (String?, int, bool) _sessionKey;
  int _epoch = 0;
  bool _disposed = false;
  void _sessionChanged() {
    final next = (
      cache.session.userId,
      cache.session.generation,
      cache.session.isAuthenticated,
    );
    if (next != _sessionKey) {
      _sessionKey = next;
      invalidate();
    }
  }

  void invalidate() => _epoch++;
  void dispose() {
    _disposed = true;
    invalidate();
    cache.session.removeListener(_sessionChanged);
  }

  void _current(ScopedSettingsPlan p, void Function()? guard) {
    cacheRequire(
      !_disposed && identical(p._owner, _owner) && p.epoch == _epoch,
      'STALE_WRITE',
    );
    requireAccountReadScope(cache.session, p.session);
    cacheRequire(cache.scope == p.registration.scope, 'SCOPE_CHANGED');
    p._guard?.call();
    guard?.call();
  }

  Future<void> _verify(ScopedSettingsPlan p, void Function()? guard) async {
    _current(p, guard);
    final s = await (db.select(
      db.cacheScopes,
    )..where((t) => t.id.equals(p.scopeId))).getSingleOrNull();
    final r =
        await (db.select(db.cachedRegistrations)..where(
              (t) =>
                  t.scopeId.equals(p.scopeId) &
                  t.registrationId.equals(p.registration.registrationId),
            ))
            .getSingleOrNull();
    cacheRequire(
      s?.localVersion == p.scopeVersion &&
          r?.localVersion == p.registrationVersion &&
          r?.seenSequence == s?.snapshotSequence &&
          r?.accountId == p.accountId,
      'STALE_WRITE',
    );
    if (p.character != null) {
      final head =
          await (db.select(db.cachedAccountHeads)..where(
                (t) =>
                    t.scopeId.equals(p.scopeId) &
                    t.accountId.equals(p.accountId),
              ))
              .getSingleOrNull();
      final row =
          await (db.select(db.cachedCharacters)..where(
                (t) =>
                    t.scopeId.equals(p.scopeId) &
                    t.characterId.equals(p.targetId),
              ))
              .getSingleOrNull();
      cacheRequire(
        head?.localVersion == p.headVersion &&
            row?.localVersion == p.characterVersion &&
            row?.seenSequence == head?.snapshotSequence,
        'STALE_WRITE',
      );
      final roster = await cache.readRoster(p.registration);
      final c = roster?.characters
          .where((c) => c.characterId == p.targetId)
          .firstOrNull;
      cacheRequire(
        roster?.complete == true &&
            roster?.registration.ownershipRevision == p.ownershipRevision &&
            c?.lifecycleRevision == p.lifecycleRevision &&
            c?.lifecycleState == p.lifecycleState,
        'STALE_WRITE',
      );
    }
    _current(p, guard);
  }

  Future<T> _transaction<T>(
    ScopedSettingsPlan p,
    Future<T> Function() action,
    void Function()? guard,
  ) => db.transaction(() async {
    await _verify(p, guard);
    final value = await action();
    await _verify(p, guard);
    return value;
  });
  Future<ScopedSettingRecord?> _row(ScopedSettingsPlan p) =>
      (db.select(db.scopedSettingRecords)..where(
            (t) =>
                t.scopeId.equals(p.scopeId) &
                t.kind.equals(p.kind.name) &
                t.targetId.equals(p.targetId) &
                t.ownershipRevision.equals(p.ownershipRevision),
          ))
          .getSingleOrNull();
  Future<ScopedSettingCommand?> _command(ScopedSettingsPlan p) async {
    final row =
        await (db.select(db.scopedSettingCommands)..where(
              (t) =>
                  t.scopeId.equals(p.scopeId) &
                  t.kind.equals(p.kind.name) &
                  t.targetId.equals(p.targetId) &
                  t.ownershipRevision.equals(p.ownershipRevision),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final data = roleMap(jsonDecode(row.payload));
    return ScopedSettingCommand._(
      row.commandId,
      row.registrationId,
      data['local_revision'] as int,
      jsonEncode(data['body']),
      row.firstSentAt?.toUtc(),
      row.retryAt?.toUtc(),
      row.state,
      row.errorCode,
    );
  }

  /// Offline display only. Writes still need a fresh server-backed plan.
  Future<ScopedSettingsState?> readCached(
    ScopedRegistrationRef registration, {
    ScopedCharacterRef? character,
    void Function()? guard,
  }) async {
    final session = accountReadScope(cache.session), epoch = _epoch;
    void current() {
      cacheRequire(
        !_disposed && epoch == _epoch && cache.scope == registration.scope,
        'STALE_WRITE',
      );
      requireAccountReadScope(cache.session, session);
      guard?.call();
    }

    current();
    return db.transaction(() async {
      final regs = await cache.readRegistrations(registration.scope);
      final reg = regs
          .where((r) => r.registrationId == registration.registrationId)
          .firstOrNull;
      if (reg?.ownershipStatus != 'owned') {
        current();
        return null;
      }
      if (character != null) {
        cacheRequire(
          character.scope == registration.scope &&
              character.accountId == reg!.accountId,
          'IDENTITY_CONFLICT',
        );
        final c = await cache.readCharacter(character);
        if (c == null || c.lifecycleState == 'retired') {
          current();
          return null;
        }
      }
      final s =
          await (db.select(db.cacheScopes)..where(
                (t) =>
                    t.environment.equals(registration.scope.environment) &
                    t.userId.equals(registration.scope.userId),
              ))
              .getSingle();
      final kind = character == null
          ? SettingKind.presentation
          : SettingKind.preferences;
      final target = character?.characterId ?? reg!.accountId!;
      final row =
          await (db.select(db.scopedSettingRecords)..where(
                (t) =>
                    t.scopeId.equals(s.id) &
                    t.kind.equals(kind.name) &
                    t.targetId.equals(target) &
                    t.ownershipRevision.equals(reg!.ownershipRevision!),
              ))
              .getSingleOrNull();
      current();
      if (row == null) return null;
      final outbox =
          await (db.select(db.scopedSettingCommands)..where(
                (t) =>
                    t.scopeId.equals(s.id) &
                    t.kind.equals(kind.name) &
                    t.targetId.equals(target) &
                    t.ownershipRevision.equals(reg!.ownershipRevision!),
              ))
              .getSingleOrNull();
      ScopedSettingCommand? command;
      if (outbox != null) {
        final data = roleMap(jsonDecode(outbox.payload));
        command = ScopedSettingCommand._(
          outbox.commandId,
          outbox.registrationId,
          data['local_revision'] as int,
          jsonEncode(data['body']),
          outbox.firstSentAt?.toUtc(),
          outbox.retryAt?.toUtc(),
          outbox.state,
          outbox.errorCode,
        );
      }
      current();
      return ScopedSettingsState._(kind, row.payload, command, fromCache: true);
    });
  }

  Future<ScopedSettingsPlan> observe(
    ScopedRegistrationRef registration, {
    PersonalProfile? profile,
    AccountPresentation? presentation,
    ScopedCharacterRef? character,
    void Function()? guard,
  }) async {
    cacheRequire(
      !_disposed && registration.scope == cache.scope,
      'SCOPE_CHANGED',
    );
    cacheRequire(
      (profile != null && character != null && presentation == null) ||
          (presentation != null && profile == null && character == null),
    );
    final epoch = _epoch, session = accountReadScope(cache.session);
    return db.transaction(() async {
      final registrations = await cache.readRegistrations(registration.scope);
      final reg = registrations
          .where((r) => r.registrationId == registration.registrationId)
          .firstOrNull;
      final account = profile?.accountId ?? presentation!.accountId;
      final owner =
          profile?.ownershipRevision ?? presentation!.ownershipRevision;
      cacheRequire(
        reg != null &&
            reg.ownershipStatus == 'owned' &&
            reg.accountId == account &&
            reg.ownershipRevision == owner,
        'REGISTRATION_NOT_CURRENT',
      );
      if (presentation != null) {
        cacheRequire(
          presentation.registrationId == reg!.registrationId &&
              presentation.registrationVersion == reg.version,
          'STALE_WRITE',
        );
      }
      if (profile != null) {
        cacheRequire(
          character!.scope == registration.scope &&
              character.accountId == account &&
              character.characterId == profile.characterId,
          'IDENTITY_CONFLICT',
        );
      }
      final s =
          await (db.select(db.cacheScopes)..where(
                (t) =>
                    t.environment.equals(registration.scope.environment) &
                    t.userId.equals(registration.scope.userId),
              ))
              .getSingle();
      final r =
          await (db.select(db.cachedRegistrations)..where(
                (t) =>
                    t.scopeId.equals(s.id) &
                    t.registrationId.equals(registration.registrationId),
              ))
              .getSingle();
      final kind = profile != null
          ? SettingKind.preferences
          : SettingKind.presentation;
      final fresh = profile?.preferences.toJson() ?? presentation!.toJson();
      final head = character == null
          ? null
          : await (db.select(db.cachedAccountHeads)..where(
                  (t) => t.scopeId.equals(s.id) & t.accountId.equals(account),
                ))
                .getSingleOrNull();
      final charRow = character == null
          ? null
          : await (db.select(db.cachedCharacters)..where(
                  (t) =>
                      t.scopeId.equals(s.id) &
                      t.characterId.equals(character.characterId),
                ))
                .getSingleOrNull();
      final p = ScopedSettingsPlan._(
        _owner,
        epoch,
        session,
        registration,
        character,
        kind,
        profile?.characterId ?? account,
        account,
        owner,
        profile?.lifecycleRevision,
        profile?.lifecycleState,
        s.id,
        s.localVersion,
        r.localVersion,
        0,
        jsonEncode(fresh),
        head?.localVersion,
        charRow?.localVersion,
        guard,
      );
      await _verify(p, guard);
      final old = await _row(p);
      final data = old == null
          ? <String, dynamic>{
              'local_revision': 0,
              'acknowledged_revision': 0,
              'values': null,
              'expected_version': fresh['version'],
              'server': fresh,
            }
          : roleMap(jsonDecode(old.payload));
      if (old != null) {
        final known = roleMap(data['server']);
        cacheRequire(
          (fresh['version'] as int) >= (known['version'] as int),
          'REVISION_REGRESSION',
        );
        // Registration metadata can change while the stored count is unchanged.
        if (fresh['version'] == known['version']) {
          cacheRequire(
            jsonEncode(settingValues(kind, fresh)) ==
                    jsonEncode(settingValues(kind, known)) &&
                fresh['saved_at'] == known['saved_at'],
            'SNAPSHOT_MISMATCH',
          );
        }
      }
      data['server'] = fresh;
      if (old == null || jsonEncode(data) != old.payload) {
        await _put(p, old, data);
      }
      final row = (await _row(p))!;
      await _verify(p, guard);
      return ScopedSettingsPlan._(
        _owner,
        epoch,
        session,
        registration,
        character,
        kind,
        p.targetId,
        account,
        owner,
        p.lifecycleRevision,
        p.lifecycleState,
        s.id,
        s.localVersion,
        r.localVersion,
        row.rowVersion,
        jsonEncode(fresh),
        head?.localVersion,
        charRow?.localVersion,
        guard,
      );
    });
  }

  Future<void> _put(
    ScopedSettingsPlan p,
    ScopedSettingRecord? old,
    Map<String, dynamic> data,
  ) async {
    if (old == null) {
      await db
          .into(db.scopedSettingRecords)
          .insert(
            ScopedSettingRecordsCompanion.insert(
              scopeId: p.scopeId,
              kind: p.kind.name,
              targetId: p.targetId,
              accountId: p.accountId,
              characterId: Value(p.character?.characterId),
              ownershipRevision: p.ownershipRevision,
              rowVersion: 1,
              payload: jsonEncode(data),
            ),
          );
    } else {
      final changed =
          await (db.update(db.scopedSettingRecords)..where(
                (t) =>
                    t.scopeId.equals(p.scopeId) &
                    t.kind.equals(p.kind.name) &
                    t.targetId.equals(p.targetId) &
                    t.ownershipRevision.equals(p.ownershipRevision) &
                    t.rowVersion.equals(old.rowVersion),
              ))
              .write(
                ScopedSettingRecordsCompanion(
                  rowVersion: Value(old.rowVersion + 1),
                  payload: Value(jsonEncode(data)),
                ),
              );
      cacheRequire(changed == 1, 'CACHE_CONFLICT');
    }
  }

  Future<ScopedSettingsState> read(
    ScopedSettingsPlan p, {
    void Function()? guard,
  }) => _transaction(p, () async {
    final row = (await _row(p))!;
    return ScopedSettingsState._(p.kind, row.payload, await _command(p));
  }, guard);

  Future<ScopedSettingsState> save(
    ScopedSettingsPlan p,
    Map<String, dynamic> values, {
    void Function()? guard,
  }) {
    final capturedValues = jsonEncode(values);
    return _transaction(p, () async {
      values = roleMap(jsonDecode(capturedValues));
      if (p.kind == SettingKind.preferences) {
        PreferenceValues.fromJson(values);
        final c = await cache.readCharacter(p.character!);
        cacheRequire(
          p.lifecycleState == 'active' &&
              c?.usable == true &&
              c?.blockedReason == null,
          'CHARACTER_UNUSABLE',
        );
      } else {
        roleShape(values, 'visible_count');
        presentationCount(values['visible_count']);
      }
      final old = (await _row(p))!;
      cacheRequire(old.rowVersion == p.rowVersion, 'CACHE_CONFLICT');
      final data = roleMap(jsonDecode(old.payload));
      data['local_revision'] = (data['local_revision'] as int) + 1;
      data['values'] = values;
      data['expected_version'] = p.server['version'];
      data['expected_lifecycle_revision'] = p.lifecycleRevision;
      data['registration_id'] = p.registration.registrationId;
      data['expected_registration_version'] =
          CacheRegistrationSnapshot.fromStorage(
            roleMap(
              jsonDecode(
                (await (db.select(db.cachedRegistrations)..where(
                          (t) =>
                              t.scopeId.equals(p.scopeId) &
                              t.registrationId.equals(
                                p.registration.registrationId,
                              ),
                        ))
                        .getSingle())
                    .payload,
              ),
            ),
          ).version;
      await _put(p, old, data);
      final active = await _command(p);
      // Never erase an old-registration command as a side effect of editing.
      if (active != null &&
          active.firstSentAt == null &&
          active.registrationId == p.registration.registrationId) {
        await _delete(p, active);
      }
      final command = await materialize(p, guard: guard);
      return ScopedSettingsState._(p.kind, jsonEncode(data), command);
    }, guard);
  }

  Future<void> _delete(ScopedSettingsPlan p, ScopedSettingCommand c) async {
    await (db.delete(
          db.scopedSettingCommands,
        )..where((t) => t.scopeId.equals(p.scopeId) & t.commandId.equals(c.id)))
        .go();
  }

  Future<ScopedSettingCommand?> materialize(
    ScopedSettingsPlan p, {
    void Function()? guard,
  }) => _transaction(p, () async {
    final active = await _command(p);
    if (active != null) return active;
    final data = roleMap(jsonDecode((await _row(p))!.payload));
    if ((data['local_revision'] as int) <=
        (data['acknowledged_revision'] as int)) {
      return null;
    }
    final body = <String, dynamic>{
      'expected_version': data['expected_version'],
      'expected_ownership_revision': p.ownershipRevision,
      if (p.kind == SettingKind.preferences)
        'expected_lifecycle_revision': data['expected_lifecycle_revision']
      else
        'expected_registration_version': data['expected_registration_version'],
      ...roleMap(data['values']),
    };
    final conflict = data['expected_version'] != p.server['version'];
    final blocked =
        data['registration_id'] != p.registration.registrationId ||
        (p.kind == SettingKind.preferences &&
            (p.lifecycleState != 'active' ||
                data['expected_lifecycle_revision'] != p.lifecycleRevision));
    await db
        .into(db.scopedSettingCommands)
        .insert(
          ScopedSettingCommandsCompanion.insert(
            scopeId: p.scopeId,
            commandId: newScopedCommandKey(),
            kind: p.kind.name,
            targetId: p.targetId,
            ownershipRevision: p.ownershipRevision,
            registrationId: data['registration_id'] as String,
            payload: jsonEncode({
              'local_revision': data['local_revision'],
              'body': body,
            }),
            state: blocked
                ? 'blocked'
                : conflict
                ? 'conflict'
                : 'ready',
            errorCode: Value(
              blocked
                  ? 'STALE_WRITE'
                  : conflict
                  ? 'REVISION_CONFLICT'
                  : null,
            ),
          ),
        );
    return _command(p);
  }, guard);

  Future<ScopedSettingCommand> markSent(
    ScopedSettingsPlan p,
    ScopedSettingCommand c,
    DateTime time, {
    void Function()? guard,
  }) => _transaction(p, () async {
    final active = await _command(p);
    cacheRequire(
      active?.id == c.id &&
          active?.registrationId == p.registration.registrationId &&
          (active?.state == 'ready' || active?.state == 'retry'),
      'STALE_COMMAND',
    );
    await (db.update(
          db.scopedSettingCommands,
        )..where((t) => t.scopeId.equals(p.scopeId) & t.commandId.equals(c.id)))
        .write(
          ScopedSettingCommandsCompanion(
            firstSentAt: Value(active!.firstSentAt ?? time),
          ),
        );
    return (await _command(p))!;
  }, guard);

  Future<void> fail(
    ScopedSettingsPlan p,
    ScopedSettingCommand c,
    String state,
    String code, {
    DateTime? retryAt,
    void Function()? guard,
  }) => _transaction(p, () async {
    final active = await _command(p);
    cacheRequire(active?.id == c.id, 'STALE_COMMAND');
    final deadline =
        active!.retryAt != null &&
            (retryAt == null || active.retryAt!.isAfter(retryAt))
        ? active.retryAt
        : retryAt;
    await (db.update(
          db.scopedSettingCommands,
        )..where((t) => t.scopeId.equals(p.scopeId) & t.commandId.equals(c.id)))
        .write(
          ScopedSettingCommandsCompanion(
            state: Value(state),
            errorCode: Value(code),
            retryAt: Value(deadline),
          ),
        );
  }, guard);

  Future<void> acknowledge(
    ScopedSettingsPlan p,
    ScopedSettingCommand c,
    Map<String, dynamic> server, {
    void Function()? guard,
  }) => _transaction(p, () async {
    cacheRequire((await _command(p))?.id == c.id, 'STALE_COMMAND');
    final old = (await _row(p))!,
        data = roleMap(jsonDecode(old.payload)),
        known = roleMap(data['server']);
    data['acknowledged_revision'] = max(
      data['acknowledged_revision'] as int,
      c.localRevision,
    );
    if ((server['version'] as int) > (known['version'] as int)) {
      data['server'] = server;
    }
    if (server['version'] == known['version']) {
      cacheRequire(
        jsonEncode(settingValues(p.kind, server)) ==
                jsonEncode(settingValues(p.kind, known)) &&
            server['saved_at'] == known['saved_at'],
        'SNAPSHOT_MISMATCH',
      );
    }
    await _put(p, old, data);
    await _delete(p, c);
  }, guard);

  Future<ScopedSettingsState> useServer(
    ScopedSettingsPlan p,
    DateTime now, {
    void Function()? guard,
  }) => _transaction(p, () async {
    final c = await _command(p);
    cacheRequire(
      c != null && {'conflict', 'review', 'blocked'}.contains(c.state),
      'REVIEW_REQUIRED',
    );
    cacheRequire(c!.retryAt == null || !now.isBefore(c.retryAt!), 'RETRY_WAIT');
    final old = (await _row(p))!, data = roleMap(jsonDecode(old.payload));
    data['acknowledged_revision'] = data['local_revision'];
    await _put(p, old, data);
    await _delete(p, c);
    return ScopedSettingsState._(p.kind, jsonEncode(data), null);
  }, guard);
}
