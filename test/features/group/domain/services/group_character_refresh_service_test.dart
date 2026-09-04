import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_catalog_detection.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/activity_characters_repository.dart';
import 'package:lost_party/features/account/domain/repositories/nice_group_auto_refresh_settings_repository.dart';
import 'package:lost_party/features/account/domain/services/character_auto_refresh_coordinator.dart';
import 'package:lost_party/features/group/domain/services/group_character_refresh_service.dart';
import 'package:lost_party/features/group/presentation/viewmodels/group_character_options.dart';

void main() {
  test('그룹 후보 사전 갱신은 본인의 활동 Character만 조회한다', () async {
    final accounts = _Accounts();
    final refresh = GroupCharacterRefreshService(
      coordinator: CharacterAutoRefreshCoordinator(accountRepository: accounts),
      accountRepository: accounts,
      settingsRepository: _Settings(),
      playerId: 'player-1',
    );

    final options = await GroupCharacterOptionLoader(
      accountRepository: accounts,
      activityCharactersRepository: _Activity({'server-1'}),
      playerId: 'player-1',
      characterRefreshService: refresh,
    ).load();

    expect(accounts.refreshedIds, [1]);
    expect(options.map((option) => option.localCharacterId), [1]);
  });
}

class _Settings implements NiceGroupAutoRefreshSettingsRepository {
  @override
  Future<bool> loadEnabled({required String playerId}) async => false;
  @override
  Future<void> saveEnabled({required String playerId, required bool enabled}) async {}
}

class _Activity implements ActivityCharactersRepository {
  _Activity(this.characterIds);
  final Set<String> characterIds;
  @override
  Future<ActivityCharacters> load({required String playerId}) async =>
      ActivityCharacters(playerId: playerId, characterIds: characterIds);
  @override
  Future<ActivityCharacters> save(SaveActivityCharactersCommand command) =>
      throw UnimplementedError();
}

class _Accounts extends Fake implements AccountRepository {
  final refreshedIds = <int>[];
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => const [
    LocalGameAccount(
      id: 1,
      label: '본인',
      isMain: true,
      lookupCharacterName: '활동',
      representativeCharacterId: 1,
      displayLimit: 2,
      serverOwnershipStatus: 'active',
      characters: [
        LocalAccountCharacter(id: 1, serverCharacterId: 'server-1', serverName: '루페온', characterName: '활동', characterLevel: 70, characterClassName: '바드', itemLevel: 1750, combatPower: 100000, isVisible: true, displayOrder: 0, preferredRole: CharacterBuildRole.support),
        LocalAccountCharacter(id: 2, serverCharacterId: 'server-2', serverName: '루페온', characterName: '비활동', characterLevel: 70, characterClassName: '워로드', itemLevel: 1750, combatPower: 100000, isVisible: true, displayOrder: 1),
      ],
    ),
  ];

  @override
  Future<CharacterBuildDraft> createCharacterBuildDraft({required int characterId, required String characterName}) async {
    refreshedIds.add(characterId);
    return CharacterBuildDraft(
      characterId: characterId,
      rawJson: '{}',
      profile: CharacterProfile(serverName: '루페온', characterName: characterName, characterLevel: 70, characterClassName: '바드', itemLevel: 1750, combatPower: 100000),
      analysis: const CharacterBuildAnalysis(runeCount: 0, gemEffects: [], arkGridConditions: [], arkGridCorePoints: [], notices: [], catalogDetection: CharacterBuildCatalogDetection(catalogVersion: 'test', status: CharacterBuildDetectionStatus.detected, classId: 'bard', branchId: 'support', branchDisplayName: '서포터', detectedRole: CharacterBuildRole.support, matchedTier1Node: '완벽한 화음', matchedRelatedNodes: ['세레나데 코드'])),
      fetchedAt: DateTime.utc(2026, 9, 4),
    );
  }

  @override
  Future<CharacterBuildSnapshot> commitCharacterBuildDraft({required CharacterBuildDraft draft, required CharacterBuildRole role}) async =>
      CharacterBuildSnapshot(id: draft.characterId, characterId: draft.characterId, role: role, rawJson: draft.rawJson, itemLevel: draft.profile.itemLevel, combatPower: draft.profile.combatPower, capturedAt: draft.fetchedAt, dataVersion: 1, analysis: draft.analysis);
  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(int characterId) async => const [];
}
