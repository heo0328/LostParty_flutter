import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../shared/game_catalog/domain/entities/game_catalog.dart';
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
  });
  final CacheRegistrationSnapshot registration;
  final ScopedCharacterRef ref;
  final CacheCharacterObservation character;
  final String? exclusion;
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
    required this.keyVersion,
    required this.settingsVersion,
    required this.niceGroupEnabled,
    required this.catalog,
    this.observationGeneration = 0,
    required List<ScopedRefreshTarget> targets,
  }) : targets = List.unmodifiable(targets);
  final StorageScope scope;
  final AccountReadScope session;
  final int keyVersion, settingsVersion;
  final bool niceGroupEnabled;
  final GameCatalog catalog;
  final int observationGeneration;
  final List<ScopedRefreshTarget> targets;
}

class ScopedRefreshItem {
  const ScopedRefreshItem(
    this.target,
    this.status, {
    this.code,
    this.role,
    this.warning = false,
    this.serverPending = false,
  });
  final ScopedRefreshTarget target;
  final ScopedRefreshStatus status;
  final String? code;
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
  int? get keyVersion;
  int? get settingsVersion;
  void requireCurrent(ScopedRefreshBatch batch);
  Future<ScopedRefreshBatch> prepare();
  Future<ScopedRefreshItem> refresh(
    ScopedRefreshBatch batch,
    ScopedRefreshTarget target,
    void Function() guard,
    void Function(ScopedRefreshItem) onLocalSaved,
  );
  Future<ScopedRefreshItem> retryUpload(
    ScopedRefreshItem saved,
    void Function() guard,
  );
}

/// Explicit refresh of one owned character, independent of startup/Nice-group policy.
abstract interface class ScopedCharacterRefreshSource {
  Future<ScopedRefreshItem> refreshCharacter(
    ScopedRegistrationRef registration,
    ScopedCharacterRef character,
    void Function() guard,
    void Function(ScopedRefreshItem) onLocalSaved,
  );
}
