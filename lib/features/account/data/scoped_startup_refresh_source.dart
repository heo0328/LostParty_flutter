import 'package:flutter/foundation.dart';
import '../../../shared/lost_ark_api/client/api_cooldown.dart';
import '../domain/account_read_session.dart';
import '../domain/scoped_cache_models.dart';
import '../domain/scoped_startup_refresh.dart';
import 'scoped_account_runtime.dart';
import 'startup_roster_refresh.dart';
import 'character_analysis_client.dart';
import 'repositories/scoped_role_repository.dart';

class ScopedRefreshAccess {
  const ScopedRefreshAccess({
    this.niceGroupEnabled,
    this.settingsVersion,
    this.accountChangesPending = false,
  });
  final bool? niceGroupEnabled;
  final int? settingsVersion;
  final bool accountChangesPending;
}

class RuntimeStartupRefreshSource
    implements
        ScopedStartupRefreshSource,
        RosterRefreshingSource,
        ScopedCharacterRefreshSource,
        ScopedRosterRefreshSource,
        ScopedBatchRefreshSource,
        ScopedCandidateRefreshSource {
  RuntimeStartupRefreshSource({
    required this.runtime,
    required this.readAccess,
    required this.changes,
    required this.cooldown,
    CharacterAnalysisClient? client,
  }) : client = client ?? CharacterAnalysisClient(runtime.api),
       _rosterRefresh = StartupRosterRefresh(runtime, cooldown);
  final ScopedAccountRuntime runtime;
  final ScopedRefreshAccess Function() readAccess;
  final CharacterAnalysisClient client;
  final StartupRosterRefresh _rosterRefresh;
  @override
  final Listenable changes;
  @override
  final ApiCooldown cooldown;
  @override
  AccountReadSession get session => runtime.session;
  @override
  StorageScope? get scope => runtime.canRead ? runtime.scope : null;
  @override
  int? get settingsVersion => readAccess().settingsVersion;
  @override
  Listenable get rosterChanges => _rosterRefresh;
  @override
  List<RosterRefreshProgress> get rosterProgress => _rosterRefresh.progress;
  void dispose() => _rosterRefresh.dispose();
  @override
  void requireCurrent(ScopedRefreshBatch batch) {
    runtime.requireCurrent(batch.session, batch.scope);
    if (runtime.readGeneration != batch.observationGeneration ||
        readAccess().accountChangesPending) {
      throw const AccountReadException('ACCOUNT_OBSERVATION_CHANGED');
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
    void guard() {
      runtime.requireCurrent(member, storage);
      final current = readAccess();
      if (runtime.readGeneration != observationGeneration ||
          current.accountChangesPending) {
        throw const AccountReadException('ACCOUNT_OBSERVATION_CHANGED');
      }
      if (current.settingsVersion != access.settingsVersion ||
          current.niceGroupEnabled != access.niceGroupEnabled) {
        throw const AccountReadException('SETTINGS_CHANGED');
      }
    }

    guard();
    await _rosterRefresh.prepare(
      guard: guard,
      onApplied: () {
        runtime.invalidateReads();
        observationGeneration = runtime.readGeneration;
      },
    );
    guard();
    if (runtime.analysisCandidatesEnabled) {
      await runtime.restoreBootstrap(guard: guard);
      guard();
    }
    final snapshot = await runtime.loadMemberRoster(guard: guard);
    guard();
    return ScopedRefreshBatch(
      scope: storage,
      session: member,
      settingsVersion: access.settingsVersion!,
      niceGroupEnabled: access.niceGroupEnabled!,
      observationGeneration: observationGeneration,
      targets: _targets(storage, snapshot.rosters, access.niceGroupEnabled!),
    );
  }

  List<ScopedRefreshTarget> _targets(
    StorageScope storage,
    List<CacheRosterSnapshot> rosters,
    bool nice,
  ) {
    final selected = projectScopedRefreshTargets(
      storage,
      rosters,
      niceGroupEnabled: nice,
    );
    if (!runtime.analysisCandidatesEnabled) return selected;
    final bootstrap = runtime.bootstrap;
    if (bootstrap == null) {
      throw const AccountReadException('CANDIDATES_NOT_READY');
    }
    final projections = bootstrap.data.registrations
        .where((r) => r.snapshot.ownershipStatus == 'owned')
        .map((r) {
          if (r.candidates == null) {
            throw const AccountReadException('CANDIDATES_NOT_READY');
          }
          return r.candidates!;
        });
    return mergeAnalysisCandidateTargets(
      storage,
      rosters,
      selected,
      projections,
    );
  }

  Future<List<ScopedRefreshItem>> _execute(
    List<ScopedRefreshTarget> targets,
    String trigger,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  ) async {
    guard();
    final prepared = await runtime.prepareRoleBuildBatch(
      targets.map((t) => (t.registrationRef, t.ref)).toList(),
      guard: guard,
    );
    final results = <ScopedRefreshItem>[];
    final ready = <ScopedRefreshTarget>[], plans = <ScopedRolePlan>[];
    for (final target in targets) {
      if (target.candidate?.state == 'succeeded') {
        results.add(
          ScopedRefreshItem(
            target,
            ScopedRefreshStatus.excluded,
            code: 'ANALYSIS_CANDIDATE_COMPLETED',
          ),
        );
        continue;
      }
      final entry = prepared[target.ref.characterId]!;
      final plan = entry.plan;
      if (target.candidate?.state == 'blocked' &&
          !target.explicitRetry &&
          trigger == 'automatic') {
        results.add(
          ScopedRefreshItem(
            target,
            ScopedRefreshStatus.failed,
            code:
                target.candidate!.error ?? 'ANALYSIS_CANDIDATE_RETRY_REQUIRED',
          ),
        );
        continue;
      }
      if (plan == null ||
          plan.profile.ownershipRevision !=
              target.registration.ownershipRevision ||
          plan.profile.lifecycleRevision !=
              target.character.lifecycleRevision ||
          plan.profile.lifecycleState != 'active') {
        results.add(
          ScopedRefreshItem(
            target,
            ScopedRefreshStatus.failed,
            code: entry.failure?.code ?? 'CHARACTER_UNUSABLE',
            failure: entry.failure,
          ),
        );
      } else {
        ready.add(target);
        plans.add(plan);
      }
    }
    for (var start = 0; start < plans.length; start += 50) {
      final part = plans.skip(start).take(50).toList();
      final selected = ready.skip(start).take(50).toList();
      var indices = List.generate(part.length, (i) => i);
      while (indices.isNotEmpty) {
        guard();
        final response = await client.execute(
          indices.map((i) => part[i]).toList(),
          trigger,
          guard,
          candidateContexts: {
            for (final i in indices)
              if (selected[i].candidate != null &&
                  selected[i].candidate!.original == null &&
                  (selected[i].candidate!.state == 'pending' ||
                      selected[i].explicitRetry))
                selected[i].ref.characterId: selected[i].candidate!.context(
                  manualRetry:
                      selected[i].explicitRetry &&
                      selected[i].candidate!.state == 'blocked',
                ),
          },
          originalCommands: {
            for (final i in indices)
              if (selected[i].candidate?.original != null)
                selected[i].ref.characterId: selected[i].candidate!.original!,
          },
        );
        guard();
        final unstarted = <int>[];
        var progressed = false, blocked = false;
        for (var j = 0; j < indices.length; j++) {
          final i = indices[j], r = response[j], target = selected[indices[j]];
          ScopedRefreshItem item;
          if (r.state == 'saved') {
            AccountReadException? localFailure = r.failure;
            try {
              await runtime.applyAnalysis(
                part[i],
                r.role!,
                r.head!.toJson(),
                guard: guard,
              );
            } on ScopedCacheException {
              guard();
              localFailure = const AccountReadException(
                'SERVER_RESULT_REFRESH_REQUIRED',
              );
            } on AccountReadException catch (e) {
              guard();
              localFailure = AccountReadException(
                'SERVER_RESULT_REFRESH_REQUIRED',
                requestId: e.requestId,
              );
            }
            guard();
            item = ScopedRefreshItem(
              target,
              ScopedRefreshStatus.saved,
              role: r.role,
              warning: r.head!.summary!.integrity.name != 'clean',
              code: localFailure == null
                  ? null
                  : 'SERVER_RESULT_REFRESH_REQUIRED',
              failure: localFailure,
            );
            onSaved(item);
            progressed = true;
          } else if (r.failure?.code == 'ANALYSIS_CANDIDATE_RETRY_REQUIRED') {
            item = ScopedRefreshItem(
              target,
              ScopedRefreshStatus.failed,
              code: r.failure!.code,
              failure: r.failure,
            );
          } else if (r.failure?.code == 'ANALYSIS_CANDIDATE_IN_PROGRESS') {
            item = ScopedRefreshItem(
              target,
              ScopedRefreshStatus.interrupted,
              serverPending: true,
              code: r.failure!.code,
              failure: r.failure,
            );
          } else if (r.state == 'skipped') {
            item = ScopedRefreshItem(
              target,
              ScopedRefreshStatus.excluded,
              code: r.failure?.code,
            );
            progressed = true;
          } else {
            final unresolved = {
              'not_processed',
              'in_progress',
              'unknown',
            }.contains(r.state);
            item = ScopedRefreshItem(
              target,
              unresolved
                  ? ScopedRefreshStatus.interrupted
                  : ScopedRefreshStatus.failed,
              serverPending: unresolved,
              code: r.failure?.code,
              failure: r.failure,
            );
            if (r.state == 'not_processed') {
              unstarted.add(i);
            } else {
              blocked = true;
            }
          }
          results.removeWhere((old) => old.target.ref == target.ref);
          results.add(item);
        }
        if (!progressed || blocked || cooldown.active) break;
        indices = unstarted;
      }
    }
    return results;
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

    try {
      final results = await _execute(targets, 'automatic', current, onSaved);
      for (final r in results) {
        if (r.status == ScopedRefreshStatus.saved ||
            r.status == ScopedRefreshStatus.excluded ||
            r.serverPending) {
          onSaved(r);
        } else {
          onFailure(
            r.target,
            r.failure ?? AccountReadException(r.code ?? 'UPSTREAM_UNAVAILABLE'),
          );
        }
      }
    } on AccountReadException catch (e) {
      current();
      for (final t in targets) {
        onFailure(t, e);
      }
    }
  }

  @override
  Future<List<ScopedRefreshItem>> refreshVerifiedRoster(
    ScopedRegistrationRef registration,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  ) async {
    if (!runtime.analysisCandidatesEnabled) {
      return refreshRoster(registration, guard, onSaved);
    }
    await runtime.refreshRoster(registration, guard: guard);
    guard();
    await runtime.restoreBootstrap(guard: guard);
    final roster = await runtime.loadMemberRoster(guard: guard);
    guard();
    final targets =
        _targets(
              registration.scope,
              roster.rosters,
              readAccess().niceGroupEnabled ?? false,
            )
            .where(
              (t) =>
                  t.registration.registrationId ==
                      registration.registrationId &&
                  t.exclusion == null,
            )
            .toList();
    if (targets.isEmpty) return [];
    return _execute(targets, 'automatic', guard, onSaved);
  }

  @override
  Future<List<ScopedRefreshItem>> retryItems(
    List<ScopedRefreshItem> items,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  ) async {
    if (items.isEmpty) return [];
    if (runtime.analysisCandidatesEnabled) {
      await runtime.restoreBootstrap(guard: guard);
    }
    final targets = <ScopedRefreshTarget>[];
    for (final item in items) {
      guard();
      final old = item.target;
      final roster = await runtime.readRoster(
        old.registrationRef,
        guard: guard,
      );
      final c = roster?.characters
          .where((c) => c.characterId == old.ref.characterId)
          .firstOrNull;
      if (roster == null ||
          c?.usable != true ||
          c!.lifecycleState != 'active') {
        throw const AccountReadException('CHARACTER_UNUSABLE');
      }
      final candidate = runtime.bootstrap?.data.registrations
          .where(
            (r) => r.snapshot.registrationId == old.registration.registrationId,
          )
          .firstOrNull
          ?.candidates
          ?.items
          .where((p) => p.characterId == c.characterId)
          .firstOrNull;
      targets.add(
        ScopedRefreshTarget(
          roster.registration,
          old.ref,
          c,
          candidate: candidate,
          explicitRetry: !item.serverPending,
        ),
      );
    }
    return _execute(targets, 'manual', guard, onSaved);
  }

  @override
  Future<List<ScopedRefreshItem>> refreshRoster(
    ScopedRegistrationRef registration,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  ) async {
    final roster = await runtime.refreshRoster(registration, guard: guard);
    guard();
    cacheRequire(
      roster.registration.ownershipStatus == 'owned',
      'OWNERSHIP_REQUIRED',
    );
    final targets = [
      for (final c in roster.characters)
        if (c.lifecycleState == 'active' &&
            c.usable == true &&
            c.blockedReason == null &&
            roster.registration.settings.activityIds.contains(c.characterId))
          ScopedRefreshTarget(
            roster.registration,
            ScopedCharacterRef(
              registration.scope,
              accountId: c.accountId,
              characterId: c.characterId,
            ),
            c,
          ),
    ];
    if (targets.isEmpty) return [];
    return _execute(targets, 'manual', guard, onSaved);
  }

  @override
  Future<ScopedRefreshItem> refreshCharacter(
    ScopedRegistrationRef registration,
    ScopedCharacterRef character,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  ) async {
    final roster = await runtime.readRoster(registration, guard: guard);
    guard();
    final c = roster?.characters
        .where((c) => c.characterId == character.characterId)
        .firstOrNull;
    cacheRequire(
      c?.usable == true &&
          c?.lifecycleState == 'active' &&
          roster!.registration.ownershipStatus == 'owned',
      'CHARACTER_UNUSABLE',
    );
    final results = await _execute(
      [ScopedRefreshTarget(roster!.registration, character, c!)],
      'manual',
      guard,
      onSaved,
    );
    return results.single;
  }

  @override
  Future<ScopedRefreshItem> refresh(
    ScopedRefreshBatch batch,
    ScopedRefreshTarget target,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  ) async {
    void current() {
      requireCurrent(batch);
      guard();
    }

    return (await _execute([target], 'automatic', current, onSaved)).single;
  }

  @override
  Future<ScopedRefreshItem> recoverResult(
    ScopedRefreshItem item,
    void Function() guard,
  ) async => (await _execute([item.target], 'manual', guard, (_) {})).single;
  @override
  Future<void> recoverResultsBatch(
    List<ScopedRefreshItem> items,
    void Function() guard,
    void Function(ScopedRefreshItem) onResult,
  ) async {
    final results = await retryItems(items, guard, onResult);
    for (final r in results) {
      onResult(r);
    }
  }
}
