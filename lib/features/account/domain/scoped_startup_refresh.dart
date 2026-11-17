import 'dart:convert';
import 'analysis_candidates.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/lost_ark_api/client/api_cooldown.dart';
import 'account_read_session.dart';
import 'entities/character_build_role.dart';
import 'scoped_cache_models.dart';
import 'services/nice_group_policy.dart';

enum ScopedRefreshStatus { queued, saved, failed, excluded, interrupted }

enum ScopedRefreshPhase { idle, preparing, blocked, running, completed }

enum RosterRefreshPhase { queued, refreshing, updated, failed }

class RosterRefreshProgress {
  const RosterRefreshProgress(
    this.registrationId,
    this.label,
    this.phase, {
    this.added = 0,
    this.suspect = 0,
    this.code,
  });
  final String registrationId, label;
  final RosterRefreshPhase phase;
  final int added, suspect;
  final String? code;
}

/// Optional preparation reporting; sources without provider writes remain valid.
abstract interface class RosterRefreshingSource {
  Listenable get rosterChanges;
  List<RosterRefreshProgress> get rosterProgress;
}

class ScopedRefreshTarget {
  const ScopedRefreshTarget(
    this.registration,
    this.ref,
    this.character, {
    this.exclusion,
    this.candidate,
    this.explicitRetry = false,
  });
  final CacheRegistrationSnapshot registration;
  final ScopedCharacterRef ref;
  final CacheCharacterObservation character;
  final String? exclusion;
  final AnalysisCandidate? candidate;
  final bool explicitRetry;
  ScopedRefreshTarget retryTarget() => ScopedRefreshTarget(
    registration,
    ref,
    character,
    exclusion: exclusion,
    candidate: candidate,
    explicitRetry: true,
  );
  ScopedRegistrationRef get registrationRef =>
      ScopedRegistrationRef(ref.scope, registration.registrationId);
}

/// No local integer IDs; all current roster rows participate in classification.
List<ScopedRefreshTarget> projectScopedRefreshTargets(
  StorageScope scope,
  List<CacheRosterSnapshot> rosters, {
  required bool niceGroupEnabled,
}) {
  final ids = <String>{}, accounts = <String>{};
  final candidates = <NiceGroupCandidate>[];
  for (final roster in rosters) {
    cacheRequire(
      roster.registration.ownershipStatus == 'owned' &&
          accounts.add(roster.registration.accountId!),
      'INVALID_PREPARATION',
    );
    for (final c in roster.characters) {
      cacheRequire(ids.add(c.characterId), 'INVALID_PREPARATION');
      final profile = jsonDecode(c.profileJson) as Map<String, dynamic>;
      final className = profile['class_name'];
      cacheRequire(
        className is String && className.trim().isNotEmpty,
        'INVALID_PREPARATION',
      );
      final raw = profile['item_level'];
      final level = raw is String ? double.tryParse(raw) : null;
      candidates.add(
        NiceGroupCandidate(
          className as String,
          level,
          missing: c.lifecycleState != 'active',
        ),
      );
    }
  }
  final nice = const NiceGroupPolicy().evaluateCandidates(candidates);
  final result = <ScopedRefreshTarget>[];
  for (final roster in rosters) {
    final selected = roster.registration.settings.activityIds.toSet();
    cacheRequire(
      roster.characters.map((c) => c.characterId).toSet().containsAll(selected),
      'INVALID_PREPARATION',
    );
    for (final c in roster.characters.where(
      (c) => selected.contains(c.characterId),
    )) {
      final profile = jsonDecode(c.profileJson) as Map<String, dynamic>;
      final exclusion =
          c.lifecycleState != 'active' ||
              c.usable != true ||
              c.blockedReason != null
          ? 'CHARACTER_UNUSABLE'
          : !niceGroupEnabled &&
                nice.containsClass(profile['class_name'] as String)
          ? 'NICE_GROUP_OFF'
          : null;
      result.add(
        ScopedRefreshTarget(
          roster.registration,
          ScopedCharacterRef(
            scope,
            accountId: c.accountId,
            characterId: c.characterId,
          ),
          c,
          exclusion: exclusion,
        ),
      );
    }
  }
  return List.unmodifiable(result);
}

class ScopedRefreshBatch {
  ScopedRefreshBatch({
    required this.scope,
    required this.session,
    required this.settingsVersion,
    required this.niceGroupEnabled,
    this.observationGeneration = 0,
    required List<ScopedRefreshTarget> targets,
  }) : targets = List.unmodifiable(targets);
  final StorageScope scope;
  final AccountReadScope session;
  final int settingsVersion;
  final bool niceGroupEnabled;
  final int observationGeneration;
  final List<ScopedRefreshTarget> targets;
}

class ScopedRefreshItem {
  const ScopedRefreshItem(
    this.target,
    this.status, {
    this.code,
    this.failure,
    this.role,
    this.warning = false,
    this.serverPending = false,
  });
  final ScopedRefreshTarget target;
  final ScopedRefreshStatus status;
  final String? code;
  final AccountReadException? failure;
  final CharacterBuildRole? role;
  final bool warning, serverPending;
  bool get incomplete => {
    ScopedRefreshStatus.failed,
    ScopedRefreshStatus.interrupted,
    ScopedRefreshStatus.queued,
  }.contains(status);
}

abstract interface class ScopedStartupRefreshSource {
  AccountReadSession get session;
  Listenable get changes;
  StorageScope? get scope;
  ApiCooldown get cooldown;
  int? get settingsVersion;
  void requireCurrent(ScopedRefreshBatch batch);
  Future<ScopedRefreshBatch> prepare();
  Future<ScopedRefreshItem> refresh(
    ScopedRefreshBatch batch,
    ScopedRefreshTarget target,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  );
  Future<ScopedRefreshItem> recoverResult(
    ScopedRefreshItem saved,
    void Function() guard,
  );
}

/// Explicit refresh of one owned character, independent of startup/Nice-group policy.
abstract interface class ScopedRosterRefreshSource {
  Future<List<ScopedRefreshItem>> refreshRoster(
    ScopedRegistrationRef registration,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  );
}

abstract interface class ScopedCharacterRefreshSource {
  Future<ScopedRefreshItem> refreshCharacter(
    ScopedRegistrationRef registration,
    ScopedCharacterRef character,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  );
}

/// App runtime capability. Test sources may implement the single-item contract.
/// An unsupported HTTP server is never a reason to fall back to that contract.
abstract interface class ScopedBatchRefreshSource {
  Future<void> refreshBatch(
    ScopedRefreshBatch batch,
    List<ScopedRefreshTarget> targets,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
    bool Function(ScopedRefreshTarget, Object) onFailure,
  );
  Future<void> recoverResultsBatch(
    List<ScopedRefreshItem> items,
    void Function() guard,
    void Function(ScopedRefreshItem) onResult,
  );
}

abstract interface class ScopedCandidateRefreshSource {
  Future<List<ScopedRefreshItem>> refreshVerifiedRoster(
    ScopedRegistrationRef registration,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  );
  Future<List<ScopedRefreshItem>> retryItems(
    List<ScopedRefreshItem> items,
    void Function() guard,
    void Function(ScopedRefreshItem) onSaved,
  );
}

/// Merge server-discovered work without changing the user activity selection.
List<ScopedRefreshTarget> mergeAnalysisCandidateTargets(
  StorageScope storage,
  List<CacheRosterSnapshot> rosters,
  List<ScopedRefreshTarget> selected,
  Iterable<AnalysisCandidates> projections,
) {
  final result = <String, ScopedRefreshTarget>{
    for (final t in selected) t.ref.characterId: t,
  };
  for (final projection in projections) {
    final roster = rosters
        .where(
          (r) => r.registration.registrationId == projection.registrationId,
        )
        .firstOrNull;
    if (roster == null ||
        roster.registration.accountId != projection.accountId ||
        roster.registration.ownershipRevision != projection.ownershipRevision ||
        roster.registration.settings.version != projection.settingsVersion) {
      throw const AccountReadException('STALE_READ');
    }
    for (final candidate in projection.items) {
      if (candidate.state == 'succeeded') continue;
      final old = result[candidate.characterId];
      if (old != null && candidate.state == 'blocked') {
        continue; // Activity retains its normal startup right.
      }
      final c = roster.characters
          .where((c) => c.characterId == candidate.characterId)
          .firstOrNull;
      if (c == null) {
        continue; // Retired candidate history is not an active target.
      }
      final exclusion =
          old?.exclusion ??
          switch (candidate.eligibility) {
            'nice_group_disabled' => 'NICE_GROUP_OFF',
            'explicitly_excluded' => 'AUTOMATIC_TARGET_EXCLUDED',
            'character_unusable' => 'CHARACTER_UNUSABLE',
            _ => null,
          };
      result[c.characterId] = ScopedRefreshTarget(
        roster.registration,
        ScopedCharacterRef(
          storage,
          accountId: c.accountId,
          characterId: c.characterId,
        ),
        c,
        exclusion: exclusion,
        candidate: candidate,
      );
    }
  }
  return result.values.toList();
}
