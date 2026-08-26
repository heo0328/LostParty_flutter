import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_claim.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/weekly_raid_claim_repository.dart';
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
    ),
  ]);
}

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

class _TokenStore implements ApiTokenStore {
  @override
  Future<ApiToken?> read() async => null;
  @override
  Future<void> write(ApiToken token) async {}
  @override
  Future<void> delete() async {}
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
