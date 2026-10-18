import 'package:flutter/foundation.dart';
import '../../../shared/diagnostics/ui_timing.dart';

import '../../../shared/character_build/build_integrity_snapshot.dart';
import '../../../shared/game_catalog/domain/repositories/game_catalog_repository.dart';
import '../../../shared/lost_ark_api/client/api_cooldown.dart';
import '../domain/account_read_session.dart';
import '../domain/scoped_cache_models.dart';
import '../domain/scoped_startup_refresh.dart';
import 'datasources/lost_ark_character_remote_data_source.dart';
import 'mappers/scoped_role_build_mapper.dart';
import 'scoped_account_runtime.dart';
import 'startup_roster_refresh.dart';

/// Readiness comes from current member settings/key VMs; null is never OFF.
class ScopedRefreshAccess {
  const ScopedRefreshAccess({
    this.niceGroupEnabled,
    this.settingsVersion,
    this.keyVersion,
    this.accountChangesPending = false,
  });
  final bool? niceGroupEnabled;
  final int? settingsVersion, keyVersion;
  final bool accountChangesPending;
}

class RuntimeStartupRefreshSource
    implements ScopedStartupRefreshSource, RosterRefreshingSource {
  RuntimeStartupRefreshSource({
    required this.runtime,
    required this.remote,
    required this.catalog,
    required this.readAccess,
    required this.changes,
    required this.cooldown,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       _rosterRefresh = StartupRosterRefresh(runtime, cooldown);
  final StartupRosterRefresh _rosterRefresh;
  @override
  Listenable get rosterChanges => _rosterRefresh;
  @override
  List<RosterRefreshProgress> get rosterProgress => _rosterRefresh.progress;
  void dispose() => _rosterRefresh.dispose();
  final ScopedAccountRuntime runtime;
  final LostArkCharacterRemoteDataSource remote;
  final GameCatalogRepository catalog;
  final ScopedRefreshAccess Function() readAccess;
  @override
  final Listenable changes;
  @override
  final ApiCooldown cooldown;
  final DateTime Function() now;
  @override
  AccountReadSession get session => runtime.session;
  @override
  StorageScope? get scope => runtime.canRead ? runtime.scope : null;
  @override
  int? get keyVersion => readAccess().keyVersion;
  @override
  int? get settingsVersion => readAccess().settingsVersion;

  @override
  void requireCurrent(ScopedRefreshBatch batch) {
    runtime.requireCurrent(batch.session, batch.scope);
    if (runtime.readGeneration != batch.observationGeneration ||
        readAccess().accountChangesPending) {
      throw const AccountReadException('ACCOUNT_OBSERVATION_CHANGED');
    }
    if (keyVersion != batch.keyVersion) {
      throw const AccountReadException('KEY_CHANGED');
    }
  }

  @override
  Future<ScopedRefreshBatch> prepare() async {
    if (!runtime.canRead) {
      throw const AccountReadException('REFRESH_NOT_AVAILABLE');
    }
    final access = readAccess(),
        member = accountReadScope(session),
        storage = runtime.scope;
    var observationGeneration = runtime.readGeneration;
    if (access.accountChangesPending) {
      throw const AccountReadException('ACCOUNT_CHANGE_PENDING');
    }
    if (access.settingsVersion == null || access.niceGroupEnabled == null) {
      throw const AccountReadException('SETTINGS_NOT_READY');
    }
    if (access.keyVersion == null) {
      throw const AccountReadException('KEY_NOT_READY');
    }
    void guard() {
      runtime.requireCurrent(member, storage);
      final current = readAccess();
      if (runtime.readGeneration != observationGeneration ||
          current.accountChangesPending) {
        throw const AccountReadException('ACCOUNT_OBSERVATION_CHANGED');
      }
      if (current.keyVersion != access.keyVersion) {
        throw const AccountReadException('KEY_CHANGED');
      }
      if (current.settingsVersion != access.settingsVersion ||
          current.niceGroupEnabled != access.niceGroupEnabled) {
        throw const AccountReadException('SETTINGS_CHANGED');
      }
    }

    guard();
    final gameCatalog = await catalog.loadCatalog();
    guard();
    await _rosterRefresh.prepare(
      guard: guard,
      onApplied: () {
        runtime.invalidateReads();
        observationGeneration = runtime.readGeneration;
      },
    );
    guard();
    final snapshot = await runtime.loadMemberRoster(guard: guard);
    guard();
    return ScopedRefreshBatch(
      scope: storage,
      session: member,
      keyVersion: access.keyVersion!,
      settingsVersion: access.settingsVersion!,
      niceGroupEnabled: access.niceGroupEnabled!,
      catalog: gameCatalog,
      observationGeneration: observationGeneration,
      targets: projectScopedRefreshTargets(
        storage,
        snapshot.rosters,
        niceGroupEnabled: access.niceGroupEnabled!,
      ),
    );
  }

  @override
  Future<ScopedRefreshItem> refresh(
    ScopedRefreshBatch batch,
    ScopedRefreshTarget target,
    void Function() guard,
    void Function(ScopedRefreshItem) onLocalSaved,
  ) async {
    void current() {
      requireCurrent(batch);
      guard();
    }

    cacheRequire(
      batch.targets.contains(target) &&
          target.exclusion == null &&
          target.ref.scope == batch.scope,
      'POLICY_EXCLUDED',
    );
    current();
    final roster = await runtime.readRoster(
      target.registrationRef,
      guard: current,
    );
    cacheRequire(
      roster?.complete == true &&
          roster!.registration.sameStructure(target.registration),
      'STALE_WRITE',
    );
    final c = roster!.characters
        .where((c) => c.characterId == target.ref.characterId)
        .firstOrNull;
    cacheRequire(
      c?.usable == true &&
          c?.lifecycleRevision == target.character.lifecycleRevision &&
          c?.lifecycleState == 'active' &&
          roster.registration.settings.activityIds.contains(
            target.ref.characterId,
          ),
      'STALE_WRITE',
    );
    final plan = await runtime.prepareRoleBuild(
      target.registrationRef,
      target.ref,
      guard: current,
    );
    current();
    cacheRequire(
      plan.profile.ownershipRevision == target.registration.ownershipRevision &&
          plan.profile.lifecycleRevision == target.character.lifecycleRevision,
      'STALE_WRITE',
    );
    final raw = await remote.fetchCharacterArmory(
      target.character.characterName,
    );
    current();
    final draft = UiTiming.measure(
      UiWork.buildAnalysis,
      () => analyzeScopedRoleBuild(
        armory: raw,
        catalog: batch.catalog,
        lifecycleRevision: plan.profile.lifecycleRevision,
        fetchedAt: now().toUtc(),
      ),
    );
    final local = await runtime.saveRoleBuild(plan, draft, guard: current);
    final saved = ScopedRefreshItem(
      target,
      ScopedRefreshStatus.saved,
      role: draft.role,
      warning: draft.summary.integrity != BuildIntegrityStatus.clean,
      serverPending: local.hasPending,
    );
    // Save already crossed the guarded commit boundary. Keep that fact even if
    // cancellation happens before the upload/next UI notification.
    onLocalSaved(saved);
    current();
    try {
      return await retryUpload(saved, current);
    } on AccountReadException catch (error) {
      current();
      return ScopedRefreshItem(
        target,
        ScopedRefreshStatus.saved,
        role: saved.role,
        warning: saved.warning,
        serverPending: true,
        code: error.code,
      );
    } on ScopedCacheException catch (error) {
      current();
      return ScopedRefreshItem(
        target,
        ScopedRefreshStatus.saved,
        role: saved.role,
        warning: saved.warning,
        serverPending: true,
        code: error.code,
      );
    }
  }

  @override
  Future<ScopedRefreshItem> retryUpload(
    ScopedRefreshItem saved,
    void Function() guard,
  ) async {
    guard();
    final result = await runtime.syncRoleBuild(
      saved.target.registrationRef,
      saved.target.ref,
      saved.role!,
      guard: guard,
    );
    guard();
    return ScopedRefreshItem(
      saved.target,
      ScopedRefreshStatus.saved,
      role: saved.role,
      warning: saved.warning,
      serverPending: result.state?.hasPending ?? true,
      code: result.failure?.code ?? result.state?.command?.errorCode,
    );
  }
}
