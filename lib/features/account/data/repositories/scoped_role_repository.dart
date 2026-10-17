import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../domain/account_read_session.dart';
import '../../domain/entities/character_build_role.dart';
import '../../domain/role_summary.dart';
import '../../domain/scoped_cache_models.dart';
import '../local/scoped_account_cache_database.dart';
import '../local/scoped_command_key.dart';
import '../mappers/scoped_role_build_mapper.dart';
import 'scoped_character_cache_repository.dart';

class ScopedRolePlan {
  ScopedRolePlan._(
    this._owner,
    this.epoch,
    this.session,
    this.registration,
    this.ref,
    this.profile,
    this.scopeId,
    this.scopeVersion,
    this.registrationVersion,
    this.headVersion,
    this.characterVersion,
    this._rowVersions,
    this._guard,
  );
  final Object _owner;
  final int epoch,
      scopeId,
      scopeVersion,
      registrationVersion,
      headVersion,
      characterVersion;
  final AccountReadScope session;
  final ScopedRegistrationRef registration;
  final ScopedCharacterRef ref;
  final PersonalProfile profile;
  final Map<CharacterBuildRole, int> _rowVersions;
  Map<CharacterBuildRole, int> get rowVersions =>
      Map.unmodifiable(_rowVersions);
  final void Function()? _guard;
}

class ScopedRoleState {
  ScopedRoleState._(this._data, this.command, {this.fromCache = false});
  final bool fromCache;
  final Map<String, dynamic> _data;
  final ScopedRoleCommand? command;
  int get localRevision => _data['local_revision'] as int;
  bool get hasPending =>
      localRevision > (_data['acknowledged_revision'] as int);
  RoleSummary? get localSummary => _data['summary'] == null
      ? null
      : RoleSummary.fromJson(roleMap(_data['summary']));
  StoredRoleSummary get server =>
      StoredRoleSummary.fromJson(roleMap(_data['server']));
  RoleSummary? get displaySummary => hasPending ? localSummary : server.summary;
  String? get rawJson => _data['raw'] as String?;
  bool get rawMatchesDisplay =>
      rawJson != null && localSummary?.same(displaySummary) == true;
}

class ScopedRoleCommand {
  ScopedRoleCommand._(
    this.scopeId,
    this.id,
    this.ref,
    this.ownershipRevision,
    this.role,
    this.localRevision,
    this._bodyJson,
    this.firstSentAt,
    this.retryAt,
    this.state,
    this.errorCode,
  );
  final int scopeId, ownershipRevision, localRevision;
  final String id, _bodyJson, state;
  final String? errorCode;
  final ScopedCharacterRef ref;
  final CharacterBuildRole role;
  final DateTime? firstSentAt, retryAt;
  Map<String, dynamic> get body =>
      jsonDecode(_bodyJson) as Map<String, dynamic>;
}

/// Same DB as the canonical read cache; never touches legacy int-ID data.
class ScopedRoleRepository {
  ScopedRoleRepository(this.cache) {
    _sessionKey = (
      cache.session.userId,
      cache.session.generation,
      cache.session.isAuthenticated,
    );
    cache.session.addListener(_onSession);
  }
  final ScopedCharacterCacheRepository cache;
  ScopedAccountCacheDatabase get db => cache.db;
  final Object _owner = Object();
  int _epoch = 0;
  bool _disposed = false;
  late (String?, int, bool) _sessionKey;
  void _onSession() {
    final key = (
      cache.session.userId,
      cache.session.generation,
      cache.session.isAuthenticated,
    );
    if (key == _sessionKey) return;
    _sessionKey = key;
    invalidate();
  }

  void invalidate() => _epoch++;
  void dispose() {
    _disposed = true;
    invalidate();
    cache.session.removeListener(_onSession);
  }

  void _current(ScopedRolePlan plan, void Function()? guard) {
    cacheRequire(
      !_disposed && identical(plan._owner, _owner) && _epoch == plan.epoch,
      'STALE_WRITE',
    );
    requireAccountReadScope(cache.session, plan.session);
    cacheRequire(cache.scope == plan.ref.scope, 'SCOPE_CHANGED');
    plan._guard?.call();
    guard?.call();
  }

  Future<ScopedRoleRecord?> _row(ScopedRolePlan p, CharacterBuildRole role) =>
      (db.select(db.scopedRoleRecords)..where(
            (t) =>
                t.scopeId.equals(p.scopeId) &
                t.characterId.equals(p.ref.characterId) &
                t.ownershipRevision.equals(p.profile.ownershipRevision) &
                t.role.equals(role.name),
          ))
          .getSingleOrNull();
  Future<ScopedRoleCommand?> _command(
    ScopedRolePlan p,
    CharacterBuildRole role,
  ) async {
    final row =
        await (db.select(db.scopedRoleCommands)..where(
              (t) =>
                  t.scopeId.equals(p.scopeId) &
                  t.characterId.equals(p.ref.characterId) &
                  t.ownershipRevision.equals(p.profile.ownershipRevision) &
                  t.role.equals(role.name),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final payload = jsonDecode(row.payload) as Map<String, dynamic>;
    return ScopedRoleCommand._(
      p.scopeId,
      row.commandId,
      p.ref,
      row.ownershipRevision,
      role,
      payload['local_revision'] as int,
      jsonEncode(payload['body']),
      row.firstSentAt?.toUtc(),
      row.retryAt?.toUtc(),
      row.state,
      row.errorCode,
    );
  }

  Map<String, dynamic> _decode(ScopedRoleRecord row) =>
      jsonDecode(row.payload) as Map<String, dynamic>;
  Map<String, dynamic> _empty(StoredRoleSummary server) => {
    'local_revision': 0,
    'acknowledged_revision': 0,
    'summary': null,
    'raw': null,
    'expected_version': server.version,
    'server': server.toJson(),
  };

  Future<void> _verify(ScopedRolePlan p, void Function()? guard) async {
    _current(p, guard);
    final scope = await (db.select(
      db.cacheScopes,
    )..where((t) => t.id.equals(p.scopeId))).getSingleOrNull();
    final head =
        await (db.select(db.cachedAccountHeads)..where(
              (t) =>
                  t.scopeId.equals(p.scopeId) &
                  t.accountId.equals(p.ref.accountId),
            ))
            .getSingleOrNull();
    final registration =
        await (db.select(db.cachedRegistrations)..where(
              (t) =>
                  t.scopeId.equals(p.scopeId) &
                  t.registrationId.equals(p.registration.registrationId),
            ))
            .getSingleOrNull();
    final character =
        await (db.select(db.cachedCharacters)..where(
              (t) =>
                  t.scopeId.equals(p.scopeId) &
                  t.characterId.equals(p.ref.characterId),
            ))
            .getSingleOrNull();
    cacheRequire(
      scope?.localVersion == p.scopeVersion &&
          head?.localVersion == p.headVersion &&
          registration?.localVersion == p.registrationVersion &&
          character?.localVersion == p.characterVersion &&
          registration?.seenSequence == scope?.snapshotSequence &&
          character?.seenSequence == head?.snapshotSequence &&
          character?.accountId == p.ref.accountId &&
          registration?.accountId == p.ref.accountId,
      'STALE_WRITE',
    );
    _current(p, guard);
  }

  Future<T> _transaction<T>(
    ScopedRolePlan p,
    Future<T> Function() action,
    void Function()? guard,
  ) => db.transaction(() async {
    await _verify(p, guard);
    final result = await action();
    await _verify(p, guard);
    return result;
  });

  /// Same-member cached display only; never grants a fresh write plan.
  Future<ScopedRoleState?> readCached(
    ScopedRegistrationRef registration,
    ScopedCharacterRef ref,
    CharacterBuildRole role, {
    void Function()? guard,
  }) async {
    final captured = accountReadScope(cache.session), epoch = _epoch;
    void current() {
      cacheRequire(
        !_disposed &&
            epoch == _epoch &&
            cache.scope == ref.scope &&
            registration.scope == ref.scope,
        'STALE_WRITE',
      );
      requireAccountReadScope(cache.session, captured);
      guard?.call();
    }

    current();
    return db.transaction(() async {
      final regs = await cache.readRegistrations(registration.scope);
      final reg = regs
          .where((r) => r.registrationId == registration.registrationId)
          .firstOrNull;
      if (reg?.ownershipStatus != 'owned' || reg?.accountId != ref.accountId) {
        current();
        return null;
      }
      final c = await cache.readCharacter(ref);
      if (c == null || c.lifecycleState == 'retired') {
        current();
        return null;
      }
      final s =
          await (db.select(db.cacheScopes)..where(
                (t) =>
                    t.environment.equals(ref.scope.environment) &
                    t.userId.equals(ref.scope.userId),
              ))
              .getSingle();
      final row =
          await (db.select(db.scopedRoleRecords)..where(
                (t) =>
                    t.scopeId.equals(s.id) &
                    t.characterId.equals(ref.characterId) &
                    t.ownershipRevision.equals(reg!.ownershipRevision!) &
                    t.role.equals(role.name),
              ))
              .getSingleOrNull();
      current();
      if (row == null) return null;
      final out =
          await (db.select(db.scopedRoleCommands)..where(
                (t) =>
                    t.scopeId.equals(s.id) &
                    t.characterId.equals(ref.characterId) &
                    t.ownershipRevision.equals(reg!.ownershipRevision!) &
                    t.role.equals(role.name),
              ))
              .getSingleOrNull();
      ScopedRoleCommand? command;
      if (out != null) {
        final data = roleMap(jsonDecode(out.payload));
        command = ScopedRoleCommand._(
          s.id,
          out.commandId,
          ref,
          out.ownershipRevision,
          role,
          data['local_revision'] as int,
          jsonEncode(data['body']),
          out.firstSentAt?.toUtc(),
          out.retryAt?.toUtc(),
          out.state,
          out.errorCode,
        );
      }
      current();
      return ScopedRoleState._(_decode(row), command, fromCache: true);
    });
  }

  Future<ScopedRolePlan> observe(
    ScopedRegistrationRef registration,
    ScopedCharacterRef ref,
    PersonalProfile profile, {
    void Function()? guard,
  }) async {
    cacheRequire(
      !_disposed && cache.scope == ref.scope && registration.scope == ref.scope,
      'SCOPE_CHANGED',
    );
    final epoch = _epoch, session = accountReadScope(cache.session);
    return db.transaction(() async {
      final view = await cache.readRoster(registration);
      cacheRequire(
        view != null &&
            view.complete &&
            view.registration.accountId == ref.accountId &&
            view.registration.ownershipStatus == 'owned' &&
            view.registration.ownershipRevision == profile.ownershipRevision,
        'REGISTRATION_NOT_CURRENT',
      );
      final observation = view!.characters
          .where((c) => c.characterId == ref.characterId)
          .firstOrNull;
      cacheRequire(
        profile.characterId == ref.characterId &&
            profile.accountId == ref.accountId &&
            observation != null &&
            observation.lifecycleRevision == profile.lifecycleRevision &&
            observation.lifecycleState == profile.lifecycleState,
        'STALE_WRITE',
      );
      final s =
          await (db.select(db.cacheScopes)..where(
                (t) =>
                    t.environment.equals(ref.scope.environment) &
                    t.userId.equals(ref.scope.userId),
              ))
              .getSingle();
      final r =
          await (db.select(db.cachedRegistrations)..where(
                (t) =>
                    t.scopeId.equals(s.id) &
                    t.registrationId.equals(registration.registrationId),
              ))
              .getSingle();
      final h =
          await (db.select(db.cachedAccountHeads)..where(
                (t) =>
                    t.scopeId.equals(s.id) & t.accountId.equals(ref.accountId),
              ))
              .getSingle();
      final c =
          await (db.select(db.cachedCharacters)..where(
                (t) =>
                    t.scopeId.equals(s.id) &
                    t.characterId.equals(ref.characterId),
              ))
              .getSingle();
      final versions = <CharacterBuildRole, int>{};
      final p = ScopedRolePlan._(
        _owner,
        epoch,
        session,
        registration,
        ref,
        profile,
        s.id,
        s.localVersion,
        r.localVersion,
        h.localVersion,
        c.localVersion,
        versions,
        guard,
      );
      await _verify(p, guard);
      for (final role in CharacterBuildRole.values) {
        final old = await _row(p, role);
        final data = old == null ? _empty(profile.role(role)) : _decode(old);
        final known = StoredRoleSummary.fromJson(roleMap(data['server']));
        final fresh = profile.role(role);
        cacheRequire(fresh.version >= known.version, 'REVISION_REGRESSION');
        if (fresh.version == known.version) {
          cacheRequire(
            jsonEncode(fresh.toJson()) == jsonEncode(known.toJson()),
            'SNAPSHOT_MISMATCH',
          );
        }
        data['server'] = fresh.toJson();
        if (old == null || jsonEncode(data) != old.payload) {
          await _put(p, role, old, data);
        }
        versions[role] = (await _row(p, role))!.rowVersion;
      }
      await _verify(p, guard);
      return p;
    });
  }

  Future<void> _put(
    ScopedRolePlan p,
    CharacterBuildRole role,
    ScopedRoleRecord? old,
    Map<String, dynamic> data,
  ) async {
    if (old == null) {
      await db
          .into(db.scopedRoleRecords)
          .insert(
            ScopedRoleRecordsCompanion.insert(
              scopeId: p.scopeId,
              characterId: p.ref.characterId,
              accountId: p.ref.accountId,
              ownershipRevision: p.profile.ownershipRevision,
              role: role.name,
              rowVersion: 1,
              payload: jsonEncode(data),
            ),
          );
    } else {
      final updated =
          await (db.update(db.scopedRoleRecords)..where(
                (t) =>
                    t.scopeId.equals(p.scopeId) &
                    t.characterId.equals(p.ref.characterId) &
                    t.ownershipRevision.equals(p.profile.ownershipRevision) &
                    t.role.equals(role.name) &
                    t.rowVersion.equals(old.rowVersion),
              ))
              .write(
                ScopedRoleRecordsCompanion(
                  rowVersion: Value(old.rowVersion + 1),
                  payload: Value(jsonEncode(data)),
                ),
              );
      cacheRequire(updated == 1, 'CACHE_CONFLICT');
    }
  }

  Future<ScopedRoleState> read(
    ScopedRolePlan p,
    CharacterBuildRole role, {
    void Function()? guard,
  }) => _transaction(p, () async {
    final row = await _row(p, role);
    cacheRequire(row != null, 'ROLE_NOT_FOUND');
    return ScopedRoleState._(_decode(row!), await _command(p, role));
  }, guard);

  Future<ScopedRoleState> save(
    ScopedRolePlan p,
    ScopedRoleBuildDraft draft, {
    void Function()? guard,
  }) => _transaction(p, () async {
    cacheRequire(
      p.profile.lifecycleState == 'active' &&
          draft.summary.lifecycleRevision == p.profile.lifecycleRevision,
      'CHARACTER_UNUSABLE',
    );
    final character = await cache.readCharacter(p.ref);
    cacheRequire(
      character?.usable == true && character?.blockedReason == null,
      'CHARACTER_UNUSABLE',
    );
    cacheRequire(
      character?.serverName == draft.serverName &&
          character?.characterName == draft.characterName &&
          jsonDecode(character!.profileJson)['class_name'] == draft.className,
      'IDENTITY_CONFLICT',
    );
    final old = await _row(p, draft.role);
    cacheRequire(
      old != null && old.rowVersion == p.rowVersions[draft.role],
      'CACHE_CONFLICT',
    );
    final data = _decode(old!);
    data['local_revision'] = (data['local_revision'] as int) + 1;
    data['summary'] = draft.summary.toJson();
    data['raw'] = draft.rawJson;
    data['expected_version'] = p.profile.role(draft.role).version;
    await _put(p, draft.role, old, data);
    final active = await _command(p, draft.role);
    if (active != null && active.firstSentAt == null) {
      await (db.delete(db.scopedRoleCommands)..where(
            (t) => t.scopeId.equals(p.scopeId) & t.commandId.equals(active.id),
          ))
          .go();
    }
    // Snapshot and unsent command are committed together. A sent command stays
    // immutable while the newer local draft waits separately in this role row.
    final command = await materialize(p, draft.role, guard: guard);
    return ScopedRoleState._(data, command);
  }, guard);

  Future<ScopedRoleCommand?> materialize(
    ScopedRolePlan p,
    CharacterBuildRole role, {
    void Function()? guard,
  }) => _transaction(p, () async {
    final active = await _command(p, role);
    if (active != null) return active;
    final row = (await _row(p, role))!, data = _decode(row);
    if ((data['local_revision'] as int) <=
        (data['acknowledged_revision'] as int)) {
      return null;
    }
    final summary = RoleSummary.fromJson(roleMap(data['summary']));
    final current = p.profile.role(role);
    final conflict = current.version != data['expected_version'];
    final stale =
        p.profile.lifecycleState != 'active' ||
        summary.lifecycleRevision != p.profile.lifecycleRevision;
    final body = {
      'expected_version': data['expected_version'],
      'expected_ownership_revision': p.profile.ownershipRevision,
      'expected_lifecycle_revision': summary.lifecycleRevision,
      'summary': summary.toJson(),
    };
    await db
        .into(db.scopedRoleCommands)
        .insert(
          ScopedRoleCommandsCompanion.insert(
            scopeId: p.scopeId,
            commandId: newScopedCommandKey(),
            characterId: p.ref.characterId,
            ownershipRevision: p.profile.ownershipRevision,
            role: role.name,
            payload: jsonEncode({
              'local_revision': data['local_revision'],
              'body': body,
            }),
            state: stale
                ? 'blocked'
                : conflict
                ? 'conflict'
                : 'ready',
            errorCode: Value(
              stale
                  ? 'STALE_WRITE'
                  : conflict
                  ? 'REVISION_CONFLICT'
                  : null,
            ),
          ),
        );
    return _command(p, role);
  }, guard);

  Future<ScopedRoleCommand> markSent(
    ScopedRolePlan p,
    ScopedRoleCommand command,
    DateTime now, {
    void Function()? guard,
  }) => _transaction(p, () async {
    final active = await _command(p, command.role);
    cacheRequire(
      active?.id == command.id &&
          (active!.state == 'ready' || active.state == 'retry'),
      'STALE_COMMAND',
    );
    cacheRequire(
      command.body['expected_lifecycle_revision'] ==
              p.profile.lifecycleRevision &&
          p.profile.lifecycleState == 'active',
      'STALE_WRITE',
    );
    await (db.update(db.scopedRoleCommands)..where(
          (t) => t.scopeId.equals(p.scopeId) & t.commandId.equals(command.id),
        ))
        .write(
          ScopedRoleCommandsCompanion(
            firstSentAt: Value(active!.firstSentAt ?? now),
          ),
        );
    return (await _command(p, command.role))!;
  }, guard);

  Future<void> fail(
    ScopedRolePlan p,
    ScopedRoleCommand command,
    String state,
    String code, {
    DateTime? retryAt,
    void Function()? guard,
  }) => _transaction(p, () async {
    final active = await _command(p, command.role);
    cacheRequire(active?.id == command.id, 'STALE_COMMAND');
    final deadline =
        active!.retryAt != null &&
            (retryAt == null || active.retryAt!.isAfter(retryAt))
        ? active.retryAt
        : retryAt;
    await (db.update(db.scopedRoleCommands)..where(
          (t) => t.scopeId.equals(p.scopeId) & t.commandId.equals(command.id),
        ))
        .write(
          ScopedRoleCommandsCompanion(
            state: Value(state),
            errorCode: Value(code),
            retryAt: Value(deadline),
          ),
        );
  }, guard);

  Future<void> acknowledge(
    ScopedRolePlan p,
    ScopedRoleCommand command,
    RoleSummaryAck ack, {
    void Function()? guard,
  }) => _transaction(p, () async {
    final active = await _command(p, command.role);
    cacheRequire(active?.id == command.id, 'STALE_COMMAND');
    final old = (await _row(p, command.role))!, data = _decode(old);
    data['acknowledged_revision'] = max(
      data['acknowledged_revision'] as int,
      command.localRevision,
    );
    final known = StoredRoleSummary.fromJson(roleMap(data['server']));
    if (ack.stored.version > known.version) {
      data['server'] = ack.stored.toJson();
    }
    if (ack.stored.version == known.version) {
      cacheRequire(
        jsonEncode(ack.stored.toJson()) == jsonEncode(known.toJson()),
        'SNAPSHOT_MISMATCH',
      );
    }
    await _put(p, command.role, old, data);
    await (db.delete(db.scopedRoleCommands)..where(
          (t) => t.scopeId.equals(p.scopeId) & t.commandId.equals(command.id),
        ))
        .go();
  }, guard);

  /// Explicit user reconciliation after a fresh P1 GET. Never an auto rebase.
  Future<ScopedRoleState> useServer(
    ScopedRolePlan p,
    CharacterBuildRole role,
    DateTime now, {
    void Function()? guard,
  }) => _transaction(p, () async {
    final active = await _command(p, role);
    cacheRequire(
      active != null &&
          {'conflict', 'review', 'blocked'}.contains(active.state),
      'REVIEW_REQUIRED',
    );
    cacheRequire(
      active!.retryAt == null || !now.isBefore(active.retryAt!),
      'RETRY_WAIT',
    );
    final old = (await _row(p, role))!, data = _decode(old);
    data['acknowledged_revision'] = data['local_revision'];
    await _put(p, role, old, data);
    await (db.delete(db.scopedRoleCommands)..where(
          (t) => t.scopeId.equals(p.scopeId) & t.commandId.equals(active.id),
        ))
        .go();
    return ScopedRoleState._(data, null);
  }, guard);
}
