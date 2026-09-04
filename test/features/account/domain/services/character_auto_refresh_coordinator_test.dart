import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_auto_refresh_result.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_catalog_detection.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/services/character_auto_refresh_coordinator.dart';

void main() {
  test(
    'shares one in-flight request and preserves each caller generation',
    () async {
      final repository = _FakeAccountRepository()..manualCompletion = true;
      final coordinator = CharacterAutoRefreshCoordinator(
        accountRepository: repository,
      );

      final first = coordinator.prefetch(_request(1, generation: 10));
      final second = coordinator.ensureFresh(_request(1, generation: 11));
      await Future<void>.delayed(Duration.zero);

      expect(repository.startedIds, [1]);
      repository.complete(1, _draft(1));

      expect((await first).generation, 10);
      final secondResult = await second;
      expect(secondResult.generation, 11);
      expect(
        secondResult.matchesSelection(
          selectedCharacterId: 1,
          currentGeneration: 11,
        ),
        isTrue,
      );
      expect(
        secondResult.matchesSelection(
          selectedCharacterId: 2,
          currentGeneration: 11,
        ),
        isFalse,
      );
      expect(repository.createCount, 1);
      expect(repository.commitCount, 1);
    },
  );

  test(
    'reuses success before five minutes and refreshes at the boundary',
    () async {
      var now = DateTime.utc(2026, 9, 4, 12);
      final repository = _FakeAccountRepository();
      final coordinator = CharacterAutoRefreshCoordinator(
        accountRepository: repository,
        clock: () => now,
      );

      expect(
        (await coordinator.ensureFresh(_request(1))).status,
        CharacterAutoRefreshStatus.refreshed,
      );
      now = now.add(const Duration(minutes: 4, seconds: 59));
      expect(
        (await coordinator.ensureFresh(_request(1))).status,
        CharacterAutoRefreshStatus.cached,
      );
      now = now.add(const Duration(seconds: 1));
      expect(
        (await coordinator.ensureFresh(_request(1))).status,
        CharacterAutoRefreshStatus.refreshed,
      );
      expect(repository.createCount, 2);
    },
  );

  test(
    'limits requests to three and starts a command before queued prefetch',
    () async {
      final repository = _FakeAccountRepository()..manualCompletion = true;
      final coordinator = CharacterAutoRefreshCoordinator(
        accountRepository: repository,
      );

      final futures = [
        for (var id = 1; id <= 4; id++) coordinator.prefetch(_request(id)),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(repository.startedIds, [1, 2, 3]);

      final command = coordinator.ensureFresh(_request(5));
      repository.complete(1, _draft(1));
      await Future<void>.delayed(Duration.zero);
      expect(repository.startedIds, [1, 2, 3, 5]);

      repository.complete(2, _draft(2));
      repository.complete(3, _draft(3));
      await Future<void>.delayed(Duration.zero);
      repository.complete(5, _draft(5));
      repository.complete(4, _draft(4));
      await Future.wait([...futures, command]);
    },
  );

  test(
    'excluded nice-group characters use only a saved manual snapshot',
    () async {
      final repository = _FakeAccountRepository()
        ..snapshots[1] = [_snapshot(1, CharacterBuildRole.support)];
      final coordinator = CharacterAutoRefreshCoordinator(
        accountRepository: repository,
      );

      final result = await coordinator.ensureFresh(
        _request(1, excluded: true, role: CharacterBuildRole.support),
      );

      expect(result.status, CharacterAutoRefreshStatus.excluded);
      expect(result.canProceed, isTrue);
      expect(repository.createCount, 0);
    },
  );

  test(
    'failure requires confirmation with a snapshot and blocks without one',
    () async {
      final repository = _FakeAccountRepository()
        ..createError = StateError('network')
        ..snapshots[1] = [_snapshot(1, CharacterBuildRole.dealer)];
      final coordinator = CharacterAutoRefreshCoordinator(
        accountRepository: repository,
      );

      final fallback = await coordinator.ensureFresh(
        _request(1, role: CharacterBuildRole.dealer),
      );
      final blocked = await coordinator.ensureFresh(_request(2));

      expect(fallback.status, CharacterAutoRefreshStatus.needsConfirmation);
      expect(fallback.lastSuccessfulAt, DateTime.utc(2026, 9, 4, 10));
      expect(blocked.status, CharacterAutoRefreshStatus.blocked);
    },
  );

  test(
    'does not save an invalid role, gem target, or tier-four match',
    () async {
      final repository = _FakeAccountRepository()
        ..draftFactory = (id) => _draft(
          id,
          analysis: _analysis(
            detectionStatus: CharacterBuildDetectionStatus.ambiguous,
          ),
        );
      final coordinator = CharacterAutoRefreshCoordinator(
        accountRepository: repository,
      );
      expect(
        (await coordinator.ensureFresh(_request(1))).status,
        CharacterAutoRefreshStatus.blocked,
      );

      repository.draftFactory = (id) =>
          _draft(id, analysis: _analysis(unknownGem: true));
      expect(
        (await coordinator.ensureFresh(_request(2))).status,
        CharacterAutoRefreshStatus.blocked,
      );

      repository.draftFactory = (id) =>
          _draft(id, analysis: _analysis(includeTierFour: false));
      expect(
        (await coordinator.ensureFresh(_request(3))).status,
        CharacterAutoRefreshStatus.blocked,
      );
      expect(repository.commitCount, 0);
    },
  );

  test(
    'saves only the detected role and reports an expected-role change',
    () async {
      final repository = _FakeAccountRepository();
      final coordinator = CharacterAutoRefreshCoordinator(
        accountRepository: repository,
      );

      final result = await coordinator.ensureFresh(
        _request(1, role: CharacterBuildRole.dealer),
      );

      expect(result.status, CharacterAutoRefreshStatus.refreshed);
      expect(result.detectedRole, CharacterBuildRole.support);
      expect(result.expectedRoleChanged, isTrue);
      expect(repository.committedRoles, [CharacterBuildRole.support]);
    },
  );
}

CharacterAutoRefreshRequest _request(
  int id, {
  int generation = 1,
  CharacterBuildRole? role = CharacterBuildRole.support,
  bool excluded = false,
}) {
  return CharacterAutoRefreshRequest(
    characterId: id,
    characterName: '캐릭터$id',
    generation: generation,
    expectedRole: role,
    excludedFromAutoRefresh: excluded,
  );
}

CharacterBuildDraft _draft(int id, {CharacterBuildAnalysis? analysis}) {
  return CharacterBuildDraft(
    characterId: id,
    rawJson: '{}',
    profile: CharacterProfile(
      serverName: '루페온',
      characterName: '캐릭터$id',
      characterLevel: 70,
      characterClassName: '바드',
      itemLevel: 1700,
      combatPower: 100000,
    ),
    analysis: analysis ?? _analysis(),
    fetchedAt: DateTime.utc(2026, 9, 4, 12),
  );
}

CharacterBuildAnalysis _analysis({
  CharacterBuildDetectionStatus detectionStatus =
      CharacterBuildDetectionStatus.detected,
  bool unknownGem = false,
  bool includeTierFour = true,
}) {
  return CharacterBuildAnalysis(
    runeCount: 8,
    gemEffects: [
      GemSkillEffect(
        gemSlot: 0,
        gemLevel: 10,
        skillName: '음양',
        descriptions: const [],
        category: unknownGem
            ? GemSkillCategory.unknown
            : GemSkillCategory.passiveOrIdentity,
      ),
    ],
    arkGridConditions: const [],
    arkGridCorePoints: const [],
    notices: const [],
    catalogDetection: CharacterBuildCatalogDetection(
      catalogVersion: 'test',
      status: detectionStatus,
      classId: 'bard',
      branchId: detectionStatus == CharacterBuildDetectionStatus.detected
          ? 'perfect_harmony'
          : null,
      branchDisplayName: '바드',
      detectedRole: detectionStatus == CharacterBuildDetectionStatus.detected
          ? CharacterBuildRole.support
          : null,
      matchedTier1Node: '완벽한 화음',
      matchedRelatedNodes: includeTierFour ? const ['세레나데 코드'] : const [],
    ),
  );
}

CharacterBuildSnapshot _snapshot(int id, CharacterBuildRole role) {
  return CharacterBuildSnapshot(
    id: id,
    characterId: id,
    role: role,
    rawJson: '{}',
    itemLevel: 1700,
    combatPower: 100000,
    capturedAt: DateTime.utc(2026, 9, 4, 10),
    dataVersion: 1,
    analysis: _analysis(),
  );
}

class _FakeAccountRepository implements AccountRepository {
  bool manualCompletion = false;
  Object? createError;
  CharacterBuildDraft Function(int id) draftFactory = _draft;
  final Map<int, Completer<CharacterBuildDraft>> _completers = {};
  final Map<int, List<CharacterBuildSnapshot>> snapshots = {};
  final List<int> startedIds = [];
  final List<CharacterBuildRole> committedRoles = [];
  int createCount = 0;
  int commitCount = 0;

  @override
  Future<CharacterBuildDraft> createCharacterBuildDraft({
    required int characterId,
    required String characterName,
  }) async {
    createCount++;
    startedIds.add(characterId);
    if (createError != null) throw createError!;
    if (!manualCompletion) return draftFactory(characterId);
    final completer = Completer<CharacterBuildDraft>();
    _completers[characterId] = completer;
    return completer.future;
  }

  void complete(int characterId, CharacterBuildDraft draft) {
    _completers[characterId]!.complete(draft);
  }

  @override
  Future<CharacterBuildSnapshot> commitCharacterBuildDraft({
    required CharacterBuildDraft draft,
    required CharacterBuildRole role,
  }) async {
    commitCount++;
    committedRoles.add(role);
    final snapshot = _snapshot(draft.characterId, role);
    snapshots[draft.characterId] = [snapshot];
    return snapshot;
  }

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => snapshots[characterId] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
