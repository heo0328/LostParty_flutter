import '../../../shared/diagnostics/startup_timing.dart';
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
import '../domain/bounded_refresh_pipeline.dart';
import 'repositories/scoped_role_repository.dart';
import 'scoped_role_sync.dart';

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
    implements
        ScopedStartupRefreshSource,
        RosterRefreshingSource,
        ScopedCharacterRefreshSource,
        ScopedBatchRefreshSource {
  RuntimeStartupRefreshSource({
    required this.runtime,
    required this.remote,
    required this.catalog,
    required this.readAccess,
    required this.changes,
    required this.cooldown,
    DateTime Function()? now,
    int? concurrentReads,
  }) : now = now ?? DateTime.now,
       concurrentReads =
           concurrentReads ??
           (kDebugMode
               ? switch (const int.fromEnvironment(
                   'STARTUP_ARMORY_CONCURRENCY',
                   defaultValue: 2,
                 )) {
                   5 => 5,
                   15 => 15,
                   _ => 2,
                 }
               : 2),
       _rosterRefresh = StartupRosterRefresh(runtime, cooldown);
  final int concurrentReads;
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
  Future<void> refreshBatch(
    ScopedRefreshBatch batch,
    List<ScopedRefreshTarget> targets,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
    bool Function(ScopedRefreshTarget, Object) onFailure,
  ) async {
    void current() {
      requireCurrent(batch);
      guard();
    }

    current();
    final prepared = await StartupTiming.run(
      StartupWork.profileBatch,
      () => runtime.prepareRoleBuildBatch(
        targets.map((t) => (t.registrationRef, t.ref)).toList(),
        guard: current,
      ),
    );
    current();
    final ready = <ScopedRefreshTarget>[];
    final plans = <String, ScopedRolePlan>{};
    var stopped = false;
    for (final target in targets) {
      final value = prepared[target.ref.characterId]!;
      if (value.failure != null) {
        stopped = onFailure(target, value.failure!) || stopped;
      } else {
        final plan = value.plan!;
        if (plan.profile.ownershipRevision !=
                target.registration.ownershipRevision ||
            plan.profile.lifecycleRevision !=
                target.character.lifecycleRevision ||
            plan.profile.lifecycleState != 'active') {
          stopped =
              onFailure(target, const ScopedCacheException('STALE_WRITE')) ||
              stopped;
        } else {
          plans[target.ref.characterId] = plan;
          ready.add(target);
        }
      }
    }
    final saved = <ScopedRefreshItem>[];
    final stats =
        await BoundedRefreshPipeline<ScopedRefreshTarget, Map<String, dynamic>>(
          concurrentReads: concurrentReads,
          pendingCapacity: concurrentReads > 5 ? concurrentReads : 5,
        ).run(
          inputs: ready,
          requireCurrent: current,
          shouldStopScheduling: () => stopped || cooldown.active,
          fetch: (target) async {
            current();
            final roster = await StartupTiming.run(
              StartupWork.rosterRead,
              () => runtime.readRoster(target.registrationRef, guard: current),
            );
            final character = roster?.characters
                .where((c) => c.characterId == target.ref.characterId)
                .firstOrNull;
            cacheRequire(
              roster?.complete == true &&
                  roster!.registration.sameStructure(target.registration) &&
                  character?.usable == true &&
                  character?.lifecycleState == 'active' &&
                  character?.lifecycleRevision ==
                      target.character.lifecycleRevision &&
                  roster.registration.settings.activityIds.contains(
                    target.ref.characterId,
                  ),
              'STALE_WRITE',
            );
            current();
            return StartupTiming.run(
              StartupWork.armory,
              () => remote.fetchCharacterArmory(target.character.characterName),
              ordinal: targets.indexOf(target) + 1,
            );
          },
          apply: (target, raw) => StartupTiming.run(
            StartupWork.character,
            () async {
              current();
              final plan = plans[target.ref.characterId]!;
              final draft = UiTiming.measure(
                UiWork.buildAnalysis,
                () => analyzeScopedRoleBuild(
                  armory: raw,
                  catalog: batch.catalog,
                  lifecycleRevision: plan.profile.lifecycleRevision,
                  fetchedAt: now().toUtc(),
                ),
              );
              final local = await StartupTiming.run(
                StartupWork.localSave,
                () => runtime.saveRoleBuild(plan, draft, guard: current),
              );
              final item = ScopedRefreshItem(
                target,
                ScopedRefreshStatus.saved,
                role: draft.role,
                warning: draft.summary.integrity != BuildIntegrityStatus.clean,
                serverPending: local.hasPending,
              );
              saved.add(item);
              onSaved(item);
            },
            ordinal: targets.indexOf(target) + 1,
          ),
          onFailure: (target, error, _) {
            stopped = onFailure(target, error) || stopped;
          },
        );
    current();
    StartupTiming.active?.write(
      'event=pipeline read_limit=$concurrentReads max_reads=${stats.maxReads} '
      'max_queued=${stats.maxQueued} fetched=${stats.fetched} applied=${stats.applied}',
    );
    await _uploadBatch(saved, plans, current, onSaved);
  }

  Future<void> _uploadBatch(
    List<ScopedRefreshItem> items,
    Map<String, ScopedRolePlan> plans,
    void Function() current,
    void Function(ScopedRefreshItem) onResult,
  ) async {
    if (items.isEmpty) return;
    current();
    final uploads = <RoleUploadPlan>[
      for (final item in items)
        if (plans.containsKey(item.target.ref.characterId))
          (plan: plans[item.target.ref.characterId]!, role: item.role!),
    ];
    try {
      final results = await StartupTiming.run(
        StartupWork.serverSync,
        () => runtime.syncRoleBuildBatch(uploads, guard: current),
      );
      current();
      for (final item in items) {
        final result = results[(item.target.ref.characterId, item.role!)];
        if (result == null) continue;
        onResult(
          ScopedRefreshItem(
            item.target,
            ScopedRefreshStatus.saved,
            role: item.role,
            warning: item.warning,
            serverPending: result.state?.hasPending ?? true,
            code: result.failure?.code ?? result.state?.command?.errorCode,
          ),
        );
      }
    } catch (error) {
      current();
      final code = error is AccountReadException
          ? error.code
          : error is ScopedCacheException
          ? error.code
          : 'SERVER_SYNC_FAILED';
      for (final item in items) {
        onResult(
          ScopedRefreshItem(
            item.target,
            ScopedRefreshStatus.saved,
            role: item.role,
            warning: item.warning,
            serverPending: true,
            code: code,
          ),
        );
      }
    }
  }

  @override
  Future<void> retryUploads(
    List<ScopedRefreshItem> items,
    void Function() guard,
    void Function(ScopedRefreshItem) onResult,
  ) async {
    if (items.isEmpty) return;
    guard();
    final prepared = await runtime.prepareRoleBuildBatch(
      items.map((i) => (i.target.registrationRef, i.target.ref)).toList(),
      guard: guard,
    );
    guard();
    final plans = <String, ScopedRolePlan>{};
    final ready = <ScopedRefreshItem>[];
    for (final item in items) {
      final value = prepared[item.target.ref.characterId]!;
      if (value.plan != null) {
        plans[item.target.ref.characterId] = value.plan!;
        ready.add(item);
      } else {
        onResult(
          ScopedRefreshItem(
            item.target,
            ScopedRefreshStatus.saved,
            role: item.role,
            warning: item.warning,
            serverPending: true,
            code: value.failure!.code,
          ),
        );
      }
    }
    await _uploadBatch(ready, plans, guard, onResult);
  }

  @override
  Future<ScopedRefreshItem> refreshCharacter(
    ScopedRegistrationRef registration,
    ScopedCharacterRef character,
    void Function() guard,
    void Function(ScopedRefreshItem) onLocalSaved,
  ) async {
    guard();
    final access = readAccess();
    final member = accountReadScope(session), storage = runtime.scope;
    final generation = runtime.readGeneration;
    cacheRequire(
      registration.scope == storage && character.scope == storage,
      'SCOPE_CHANGED',
    );
    cacheRequire(!access.accountChangesPending, 'ACCOUNT_CHANGE_PENDING');
    cacheRequire(access.keyVersion != null, 'KEY_NOT_READY');
    cacheRequire(!cooldown.active, 'RATE_LIMITED');
    void current() {
      guard();
      runtime.requireCurrent(member, storage);
      cacheRequire(
        generation == runtime.readGeneration &&
            !readAccess().accountChangesPending,
        'ACCOUNT_OBSERVATION_CHANGED',
      );
      cacheRequire(keyVersion == access.keyVersion, 'KEY_CHANGED');
    }

    final roster = await StartupTiming.run(
      StartupWork.rosterRead,
      () => runtime.readRoster(registration, guard: current),
    );
    cacheRequire(
      roster?.complete == true &&
          roster!.registration.ownershipStatus == 'owned' &&
          roster.registration.accountId == character.accountId,
      'CHARACTER_UNUSABLE',
    );
    final observation = roster!.characters
        .where((c) => c.characterId == character.characterId)
        .firstOrNull;
    cacheRequire(observation != null, 'CHARACTER_UNUSABLE');
    final gameCatalog = await StartupTiming.run(
      StartupWork.catalog,
      catalog.loadCatalog,
    );
    current();
    final target = ScopedRefreshTarget(
      roster.registration,
      character,
      observation!,
    );
    final batch = ScopedRefreshBatch(
      scope: storage,
      session: member,
      keyVersion: access.keyVersion!,
      settingsVersion: access.settingsVersion ?? 0,
      niceGroupEnabled: access.niceGroupEnabled ?? false,
      catalog: gameCatalog,
      observationGeneration: generation,
      targets: [target],
    );
    // Reuse guarded analysis/save/upload; do not refresh every roster or restart
    // the app-lifetime automatic run. Explicit action includes Nice characters.
    return refresh(batch, target, current, onLocalSaved);
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
    final gameCatalog = await StartupTiming.run(
      StartupWork.catalog,
      catalog.loadCatalog,
    );
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
    final roster = await StartupTiming.run(
      StartupWork.rosterRead,
      () => runtime.readRoster(target.registrationRef, guard: current),
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
    final plan = await StartupTiming.run(
      StartupWork.prepareBuild,
      () => runtime.prepareRoleBuild(
        target.registrationRef,
        target.ref,
        guard: current,
      ),
    );
    current();
    cacheRequire(
      plan.profile.ownershipRevision == target.registration.ownershipRevision &&
          plan.profile.lifecycleRevision == target.character.lifecycleRevision,
      'STALE_WRITE',
    );
    final raw = await StartupTiming.run(
      StartupWork.armory,
      () => remote.fetchCharacterArmory(target.character.characterName),
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
    final local = await StartupTiming.run(
      StartupWork.localSave,
      () => runtime.saveRoleBuild(plan, draft, guard: current),
    );
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
    final result = await StartupTiming.run(
      StartupWork.serverSync,
      () => runtime.syncRoleBuild(
        saved.target.registrationRef,
        saved.target.ref,
        saved.role!,
        guard: guard,
      ),
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
