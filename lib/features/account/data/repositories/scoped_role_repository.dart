import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/account_read_session.dart';
import '../../domain/entities/character_build_role.dart';
import '../../domain/role_summary.dart';
import '../../domain/scoped_cache_models.dart';
import '../local/scoped_account_cache_database.dart';
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
  ScopedRoleState._(this._data, {this.fromCache = false});
  final bool fromCache;
  final Map<String, dynamic> _data;
  bool get hasPending => false;
  StoredRoleSummary get server => StoredRoleSummary.fromJson(
    roleMap(_data['server']),
    summaryOnly: _data['summary_only'] as bool,
  );
  RoleSummary? get displaySummary => server.summary;
  String? get detailJson =>
      server.detail == null ? null : jsonEncode(server.detail);
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
  Map<String, dynamic> _decode(ScopedRoleRecord row) {
    final data = roleMap(jsonDecode(row.payload));
    roleShape(data, 'server summary_only');
    roleCheck(data['summary_only'] is bool);
    StoredRoleSummary.fromJson(
      roleMap(data['server']),
      summaryOnly: data['summary_only'] as bool,
    );
    return data;
  }

  Map<String, dynamic> _empty(StoredRoleSummary server) => {
    'server': server.toJson(),
    'summary_only': server.summaryOnly,
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
      try {
        return ScopedRoleState._(_decode(row), fromCache: true);
      } on FormatException {
        return null;
      }
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
        var data = _empty(profile.role(role));
        Map<String, dynamic>? previous;
        if (old != null) {
          try {
            previous = _decode(old);
          } on FormatException {
            /* obsolete disposable cache */
          }
        }
        final fresh = profile.role(role);
        if (previous != null) {
          final known = StoredRoleSummary.fromJson(
            roleMap(previous['server']),
            summaryOnly: previous['summary_only'] as bool,
          );
          if (known.summary?.lifecycleRevision ==
              fresh.summary?.lifecycleRevision) {
            cacheRequire(fresh.version >= known.version, 'REVISION_REGRESSION');
            if (fresh.version == known.version) {
              cacheRequire(
                fresh.summary?.same(known.summary) == true ||
                    fresh.summary == null && known.summary == null,
                'SNAPSHOT_MISMATCH',
              );
              if (fresh.summaryOnly && !known.summaryOnly) data = previous;
            }
          }
        }
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
  }) => _transaction(
    p,
    () async => ScopedRoleState._(_decode((await _row(p, role))!)),
    guard,
  );
}
