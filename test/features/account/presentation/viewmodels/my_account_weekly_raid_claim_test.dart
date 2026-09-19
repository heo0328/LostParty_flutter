import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/fakes/in_memory_character_weekly_raid_display_repository.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_claim.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_claim_command.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_status_projection.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/weekly_raid_claim_command_repository.dart';
import 'package:lost_party/features/account/domain/repositories/weekly_raid_claim_repository.dart';
import 'package:lost_party/features/account/domain/repositories/weekly_raid_status_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/my_account_view_model.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';

void main() {
  test(
    'projects one server claim to one raid checkbox regardless of difficulty',
    () async {
      final viewModel = MyAccountViewModel(
        apiTokenStore: _TokenStore(),
        accountRepository: _AccountRepository(),
        weeklyRaidClaimRepository: _ClaimRepository(),
        raidCatalogRepository: _RaidRepository(),
        playerId: 'player-1',
        cycleKey: '2026-08-26',
      );

      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      final character = viewModel.accounts.single.characters.single;
      final statuses = viewModel.weeklyRaidStatusesFor(character);

      expect(statuses, hasLength(1));
      expect(statuses.single.raidId, 'serca');
      expect(statuses.single.isCompleted, isTrue);
      viewModel.dispose();
    },
  );

  test(
    'projects party completed state to checked and active state to guarded',
    () async {
      final viewModel = MyAccountViewModel(
        apiTokenStore: _TokenStore(),
        accountRepository: _AccountRepository(),
        weeklyRaidClaimRepository: _EmptyClaimRepository(),
        weeklyRaidStatusRepository: _StatusRepository(const [
          WeeklyRaidStatusProjection(
            playerId: 'player-1',
            characterId: 'character-1',
            raidId: 'serca',
            cycleKey: '2026-08-26',
            kind: WeeklyRaidStatusKind.completed,
          ),
        ]),
        raidCatalogRepository: _RaidRepository(),
        playerId: 'player-1',
        cycleKey: '2026-08-26',
      );

      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      final character = viewModel.accounts.single.characters.single;
      final completed = viewModel.weeklyRaidStatusesFor(character).single;
      expect(completed.isCompleted, isTrue);
      expect(completed.canToggle, isTrue);
      expect(completed.statusMessage, '완료 처리된 레이드입니다.');
      viewModel.dispose();

      final activeViewModel = MyAccountViewModel(
        apiTokenStore: _TokenStore(),
        accountRepository: _AccountRepository(),
        weeklyRaidStatusRepository: _StatusRepository(const [
          WeeklyRaidStatusProjection(
            playerId: 'player-1',
            characterId: 'character-1',
            raidId: 'serca',
            cycleKey: '2026-08-26',
            kind: WeeklyRaidStatusKind.active,
            recruitmentId: 'recruitment-1',
          ),
        ]),
        raidCatalogRepository: _RaidRepository(),
        playerId: 'player-1',
        cycleKey: '2026-08-26',
      );
      await activeViewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      final activeCharacter = activeViewModel.accounts.single.characters.single;
      final active = activeViewModel
          .weeklyRaidStatusesFor(activeCharacter)
          .single;
      expect(active.isCompleted, isFalse);
      expect(active.canToggle, isTrue);
      expect(active.statusMessage, '현재 참가 중인 레이드입니다.');
      activeViewModel.dispose();
    },
  );

  test('shows top gold raids ordered by entry item level descending', () async {
    final viewModel = MyAccountViewModel(
      apiTokenStore: _TokenStore(),
      accountRepository: _AccountRepository(),
      weeklyRaidClaimRepository: _EmptyClaimRepository(),
      raidCatalogRepository: _MultiRaidRepository(),
      playerId: 'player-1',
      cycleKey: '2026-08-26',
    );

    await viewModel.initialize();
    await Future<void>.delayed(Duration.zero);
    final character = viewModel.accounts.single.characters.single;
    final statuses = viewModel.weeklyRaidStatusesFor(character);

    expect(statuses.map((item) => item.raidId), [
      'high_level',
      'mid_level',
      'low_level',
    ]);
    viewModel.dispose();
  });

  test(
    'creates and deletes a manual claim through the checkbox command',
    () async {
      final commands = _ClaimCommandRepository();
      final viewModel = MyAccountViewModel(
        apiTokenStore: _TokenStore(),
        accountRepository: _AccountRepository(),
        weeklyRaidClaimRepository: _ClaimRepository(),
        weeklyRaidClaimCommandRepository: commands,
        raidCatalogRepository: _RaidRepository(),
        playerId: 'player-1',
        cycleKey: '2026-08-26',
        cycleStartedAt: DateTime.utc(2026, 8, 25, 21),
        cycleEndsAt: DateTime.utc(2026, 9, 1, 21),
      );

      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      final character = viewModel.accounts.single.characters.single;
      final raid = viewModel.weeklyRaidStatusesFor(character).single;

      final impact = await viewModel.inspectWeeklyRaidCompletionImpact(
        character: character,
        raid: raid,
      );
      expect(impact.isSuccess, isTrue);
      expect(commands.inspected?.raidId, 'serca');

      expect(
        await viewModel.setWeeklyRaidCompleted(
          character: character,
          raid: raid,
          completed: true,
          resolveConflicts: true,
        ),
        const WeeklyRaidClaimCommandResult.success(),
      );
      expect(commands.created?.difficultyId, 'hard');
      expect(commands.created?.characterId, 'character-1');
      expect(commands.resolveConflicts, isTrue);

      expect(
        await viewModel.setWeeklyRaidCompleted(
          character: character,
          raid: raid,
          completed: false,
        ),
        const WeeklyRaidClaimCommandResult.success(),
      );
      expect(commands.deleted?.raidId, 'serca');
      viewModel.dispose();
    },
  );

  test('saves display preference and shows all selected raids', () async {
    final displayRepository = InMemoryCharacterWeeklyRaidDisplayRepository();
    final viewModel = MyAccountViewModel(
      apiTokenStore: _TokenStore(),
      accountRepository: _AccountRepository(),
      weeklyRaidClaimRepository: _EmptyClaimRepository(),
      weeklyRaidDisplayRepository: displayRepository,
      raidCatalogRepository: _MultiRaidRepository(),
      playerId: 'player-1',
      cycleKey: '2026-08-26',
    );

    await viewModel.initialize();
    await Future<void>.delayed(Duration.zero);
    final character = viewModel.accounts.single.characters.single;

    expect(
      await viewModel.saveWeeklyRaidDisplayPreference(
        character: character,
        displayCount: 4,
        raidIds: const ['high_level', 'mid_level', 'low_level', 'junk'],
      ),
      isTrue,
    );

    expect(
      viewModel.weeklyRaidStatusesFor(character).map((item) => item.raidId),
      ['high_level', 'mid_level', 'low_level', 'junk'],
    );

    expect(await viewModel.clearWeeklyRaidDisplayPreference(character), isTrue);
    expect(
      viewModel.weeklyRaidStatusesFor(character).map((item) => item.raidId),
      ['high_level', 'mid_level', 'low_level'],
    );
    viewModel.dispose();
  });

  test(
    'applies roster display count clamped per character eligibility',
    () async {
      final displayRepository = InMemoryCharacterWeeklyRaidDisplayRepository();
      final viewModel = MyAccountViewModel(
        apiTokenStore: _TokenStore(),
        accountRepository: _RosterAccountRepository(),
        weeklyRaidClaimRepository: _EmptyClaimRepository(),
        weeklyRaidDisplayRepository: displayRepository,
        raidCatalogRepository: _MultiRaidRepository(),
        playerId: 'player-1',
        cycleKey: '2026-08-26',
      );

      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      final account = viewModel.accounts.single;
      final high = account.characters.firstWhere((c) => c.id == 1);
      final low = account.characters.firstWhere((c) => c.id == 2);

      expect(
        await viewModel.applyRosterWeeklyRaidDisplayCount(
          account: account,
          displayCount: 5,
        ),
        isTrue,
      );

      expect(viewModel.weeklyRaidStatusesFor(high).map((item) => item.raidId), [
        'high_level',
        'mid_level',
        'low_level',
        'junk',
      ]);
      expect(viewModel.weeklyRaidStatusesFor(low).map((item) => item.raidId), [
        'low_level',
        'junk',
      ]);
      viewModel.dispose();
    },
  );
}

class _ClaimCommandRepository implements WeeklyRaidClaimCommandRepository {
  CreateManualWeeklyRaidClaimCommand? inspected;
  CreateManualWeeklyRaidClaimCommand? created;
  DeleteManualWeeklyRaidClaimCommand? deleted;
  bool? resolveConflicts;

  @override
  Future<WeeklyRaidClaimImpactResult> inspectManualClaimImpact(
    CreateManualWeeklyRaidClaimCommand command,
  ) async {
    inspected = command;
    return const WeeklyRaidClaimImpactResult.success(
      ManualWeeklyRaidClaimImpact(),
    );
  }

  @override
  Future<WeeklyRaidClaimCommandResult> createManualClaim(
    CreateManualWeeklyRaidClaimCommand command, {
    bool resolveConflicts = false,
  }) async {
    created = command;
    this.resolveConflicts = resolveConflicts;
    return const WeeklyRaidClaimCommandResult.success();
  }

  @override
  Future<WeeklyRaidClaimCommandResult> deleteManualClaim(
    DeleteManualWeeklyRaidClaimCommand command,
  ) async {
    deleted = command;
    return const WeeklyRaidClaimCommandResult.success();
  }
}

class _ClaimRepository implements WeeklyRaidClaimRepository {
  @override
  Stream<List<WeeklyRaidClaim>> watchCurrentCycleClaims({
    required String playerId,
    required String cycleKey,
  }) => Stream.value([
    WeeklyRaidClaim(
      id: '1',
      playerId: playerId,
      characterId: 'character-1',
      raidId: 'serca',
      cycleKey: cycleKey,
      difficultyId: 'hard',
      source: WeeklyRaidClaimSource.manual,
      completedAt: DateTime.utc(2026, 8, 27),
      updatedAt: DateTime.utc(2026, 8, 27),
      cycleStartedAt: DateTime.utc(2026, 8, 25, 21),
      cycleEndsAt: DateTime.utc(2026, 9, 1, 21),
    ),
  ]);
}

class _EmptyClaimRepository implements WeeklyRaidClaimRepository {
  @override
  Stream<List<WeeklyRaidClaim>> watchCurrentCycleClaims({
    required String playerId,
    required String cycleKey,
  }) => Stream.value(const []);
}

class _StatusRepository implements WeeklyRaidStatusRepository {
  const _StatusRepository(this.statuses);

  final List<WeeklyRaidStatusProjection> statuses;

  @override
  Stream<List<WeeklyRaidStatusProjection>> watchCurrentCycleStatuses({
    required String playerId,
    required String cycleKey,
  }) => Stream.value(statuses);
}

RaidDifficultyDefinition _difficulty({
  required String difficultyId,
  required int minItemLevel,
  required int clearGold,
}) => RaidDifficultyDefinition(
  difficultyId: difficultyId,
  name: difficultyId,
  displayAlias: difficultyId,
  displayOrder: 1,
  minItemLevel: minItemLevel,
  clearGold: clearGold,
  boundGold: 0,
  isActive: true,
);

RaidDefinition _raid({
  required String raidId,
  required String displayName,
  required List<RaidDifficultyDefinition> difficulties,
}) => RaidDefinition(
  raidId: raidId,
  officialName: displayName,
  displayName: displayName,
  aliases: const [],
  partySize: 4,
  partyCount: 1,
  requiredSupportCount: 1,
  maxDealerCountPerClass: 1,
  gateCount: 2,
  isActive: true,
  difficulties: difficulties,
);

class _RaidRepository implements RaidCatalogRepository {
  @override
  Future<RaidCatalog> loadCatalog() async => RaidCatalog(
    schemaVersion: 1,
    catalogVersion: 'test',
    updatedAt: DateTime.utc(2026),
    raids: const [
      RaidDefinition(
        raidId: 'serca',
        officialName: '세르카',
        displayName: '세르카',
        aliases: [],
        partySize: 4,
        partyCount: 1,
        requiredSupportCount: 1,
        maxDealerCountPerClass: 1,
        gateCount: 2,
        isActive: true,
        difficulties: [
          RaidDifficultyDefinition(
            difficultyId: 'normal',
            name: '노말',
            displayAlias: '노르카',
            displayOrder: 1,
            minItemLevel: 1710,
            clearGold: 16000,
            boundGold: 16000,
            isActive: true,
          ),
          RaidDifficultyDefinition(
            difficultyId: 'hard',
            name: '하드',
            displayAlias: '하르카',
            displayOrder: 2,
            minItemLevel: 1730,
            clearGold: 44000,
            boundGold: 0,
            isActive: true,
          ),
        ],
      ),
    ],
  );
}

class _MultiRaidRepository implements RaidCatalogRepository {
  @override
  Future<RaidCatalog> loadCatalog() async => RaidCatalog(
    schemaVersion: 1,
    catalogVersion: 'test',
    updatedAt: DateTime.utc(2026),
    raids: [
      _raid(
        raidId: 'low_level',
        displayName: '낮은레벨',
        difficulties: [
          _difficulty(
            difficultyId: 'normal',
            minItemLevel: 1700,
            clearGold: 90000,
          ),
        ],
      ),
      _raid(
        raidId: 'mid_level',
        displayName: '중간레벨',
        difficulties: [
          _difficulty(
            difficultyId: 'normal',
            minItemLevel: 1720,
            clearGold: 50000,
          ),
        ],
      ),
      _raid(
        raidId: 'high_level',
        displayName: '높은레벨',
        difficulties: [
          _difficulty(
            difficultyId: 'normal',
            minItemLevel: 1740,
            clearGold: 40000,
          ),
        ],
      ),
      _raid(
        raidId: 'junk',
        displayName: '제외',
        difficulties: [
          _difficulty(
            difficultyId: 'normal',
            minItemLevel: 1680,
            clearGold: 1000,
          ),
        ],
      ),
    ],
  );
}

class _TokenStore implements ApiTokenStore {
  @override
  Future<ApiToken?> read() async => null;
  @override
  Future<void> write(ApiToken token) async {}
  @override
  Future<void> delete() async {}
}

class _RosterAccountRepository extends _AccountRepository {
  @override
  Future<LocalGameAccount?> loadMainAccount() async => const LocalGameAccount(
    id: 1,
    label: '본계정',
    isMain: true,
    lookupCharacterName: '캐릭터',
    representativeCharacterId: 1,
    displayLimit: 6,
    characters: [
      LocalAccountCharacter(
        id: 1,
        serverCharacterId: 'character-1',
        serverName: '루페온',
        characterName: '고레벨',
        characterLevel: 70,
        characterClassName: '바드',
        itemLevel: 1760,
        combatPower: 1,
        isVisible: true,
        displayOrder: 0,
      ),
      LocalAccountCharacter(
        id: 2,
        serverCharacterId: 'character-2',
        serverName: '루페온',
        characterName: '저레벨',
        characterLevel: 70,
        characterClassName: '창술사',
        itemLevel: 1700,
        combatPower: 1,
        isVisible: true,
        displayOrder: 1,
      ),
    ],
  );
}

class _AccountRepository implements AccountRepository {
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => [
    (await loadMainAccount())!,
  ];
  @override
  Future<LocalGameAccount?> loadMainAccount() async => const LocalGameAccount(
    id: 1,
    label: '본계정',
    isMain: true,
    lookupCharacterName: '캐릭터',
    representativeCharacterId: 1,
    displayLimit: 6,
    characters: [
      LocalAccountCharacter(
        id: 1,
        serverCharacterId: 'character-1',
        serverName: '루페온',
        characterName: '캐릭터',
        characterLevel: 70,
        characterClassName: '바드',
        itemLevel: 1760,
        combatPower: 1,
        isVisible: true,
        displayOrder: 0,
      ),
    ],
  );
  @override
  Future<List<CharacterSummary>> fetchCharacters(String characterName) =>
      throw UnimplementedError();
  @override
  Future<CharacterProfile> fetchCharacterProfile(String characterName) =>
      throw UnimplementedError();
  @override
  Future<RosterSummaryApplyResult> applyRosterSummarySync({
    required int accountId,
    required String lookupCharacterName,
    required List<CharacterSummary> summaries,
    required DateTime fetchedAt,
  }) => throw UnimplementedError();
  @override
  Future<CharacterBuildDraft> createCharacterBuildDraft({
    required int characterId,
    required String characterName,
  }) => throw UnimplementedError();
  @override
  Future<CharacterBuildSnapshot> commitCharacterBuildDraft({
    required CharacterBuildDraft draft,
    required CharacterBuildRole role,
  }) => throw UnimplementedError();
  @override
  Future<CharacterBuildSnapshot> refreshCharacterBuildSnapshot({
    required int characterId,
    required String characterName,
    required CharacterBuildRole role,
  }) => throw UnimplementedError();
  @override
  Future<void> saveCharacterBuildSnapshot({
    required int characterId,
    required CharacterBuildRole role,
    required String rawJson,
    required double? itemLevel,
    required double? combatPower,
    required DateTime capturedAt,
  }) async {}
  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => const [];
  @override
  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  }) async {}

  @override
  Future<void> markRepresentativeReconciled({
    required int accountId,
    required String serverCharacterId,
  }) async {}

  @override
  Future<void> setPreferredCharacterRole({
    required int characterId,
    required CharacterBuildRole role,
  }) async {}
  @override
  Future<void> updateDisplayLimit({
    required int accountId,
    required int displayLimit,
  }) async {}
  @override
  Future<void> updateCharacterVisibility({
    required int accountId,
    required int characterId,
    required bool isVisible,
  }) async {}
  @override
  Future<void> updateCharacterDisplayOrder({
    required int accountId,
    required List<int> characterIds,
  }) async {}
}
