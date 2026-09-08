import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/activity_characters_repository.dart';
import 'package:lost_party/features/account/domain/repositories/nice_group_auto_refresh_settings_repository.dart';
import 'package:lost_party/features/account/domain/repositories/representative_character_sync_gateway.dart';
import 'package:lost_party/features/account/presentation/viewmodels/character_management_view_model.dart';

void main() {
  test(
    'keeps activity, order, and display limit in a local draft until save',
    () async {
      final repository = _FakeAccountRepository();
      final activity = _FakeActivityCharactersRepository();
      final viewModel = CharacterManagementViewModel(
        accountRepository: repository,
        activityCharactersRepository: activity,
        playerId: 'player-1',
      );
      addTearDown(viewModel.dispose);
      await viewModel.initialize();

      viewModel.toggleActivity(viewModel.rosterCharacters.last);
      viewModel.reorder(0, 1);

      expect(activity.saveCount, 0);
      expect(repository.displayLimit, 2);
      expect(repository.savedOrder, [1, 2]);
      expect(viewModel.hasUnsavedChanges, isTrue);
      expect(viewModel.draftDisplayLimit, 1);

      await viewModel.save();

      expect(activity.saveCount, 1);
      expect(activity.lastCommand?.activityCharacterIds, {
        'server-character-1',
      });
      expect(activity.lastCommand?.orderedActivityCharacterIds, [
        'server-character-1',
      ]);
      expect(activity.lastCommand?.ownedCharacterIds, {
        'server-character-1',
        'server-character-2',
      });
      expect(repository.visibilityUpdates, [(2, false)]);
      expect(repository.displayLimit, 1);
      expect(repository.savedOrder, [1, 2]);
      expect(viewModel.hasUnsavedChanges, isFalse);
    },
  );

  test(
    'does not deselect the representative or the last activity character',
    () async {
      final viewModel = CharacterManagementViewModel(
        accountRepository: _FakeAccountRepository(),
        activityCharactersRepository: _FakeActivityCharactersRepository(),
        playerId: 'player-1',
      );
      addTearDown(viewModel.dispose);
      await viewModel.initialize();

      viewModel.toggleActivity(viewModel.rosterCharacters.first);
      expect(viewModel.selectedCount, 2);

      viewModel.toggleActivity(viewModel.rosterCharacters.last);
      expect(viewModel.selectedCount, 1);
      viewModel.toggleActivity(viewModel.rosterCharacters.first);
      expect(viewModel.selectedCount, 1);
    },
  );

  test(
    'rejects an empty save without calling the activity repository',
    () async {
      final activity = _FakeActivityCharactersRepository();
      final viewModel = CharacterManagementViewModel(
        accountRepository: _FakeAccountRepository(),
        activityCharactersRepository: activity,
        playerId: 'player-1',
      );
      addTearDown(viewModel.dispose);
      await viewModel.initialize();
      viewModel.debugClearActivitySelection();

      await viewModel.save();

      expect(activity.saveCount, 0);
      expect(viewModel.message, '앱에서 사용할 캐릭터를 최소 1명 선택해 주세요.');
    },
  );

  test('cancel restores the last saved draft', () async {
    final viewModel = CharacterManagementViewModel(
      accountRepository: _FakeAccountRepository(),
      activityCharactersRepository: _FakeActivityCharactersRepository(),
      playerId: 'player-1',
    );
    addTearDown(viewModel.dispose);
    await viewModel.initialize();

    viewModel.toggleActivity(viewModel.rosterCharacters.last);
    expect(viewModel.selectedCount, 1);
    viewModel.discardChanges();
    expect(viewModel.selectedCount, 2);
    expect(viewModel.hasUnsavedChanges, isFalse);
  });

  test(
    'restores a remembered order when a character is selected again',
    () async {
      final viewModel = CharacterManagementViewModel(
        accountRepository: _FakeAccountRepository(),
        activityCharactersRepository: _FakeActivityCharactersRepository(),
        playerId: 'player-1',
      );
      addTearDown(viewModel.dispose);
      await viewModel.initialize();

      final second = viewModel.rosterCharacters.last;
      viewModel.toggleActivity(second);
      viewModel.toggleActivity(second);
      expect(viewModel.selectedCharacters.map((character) => character.id), [
        1,
        2,
      ]);
    },
  );

  test('changes representative only after a successful save', () async {
    final now = DateTime.utc(2026, 8, 28, 9);
    final repository = _FakeAccountRepository(serverBacked: true);
    final gateway = _FakeRepresentativeSyncGateway(
      state: RepresentativeCharacterSyncState(
        representativeCharacterId: 'server-character-1',
        updatedAt: now.subtract(const Duration(minutes: 6)),
      ),
      clock: () => now,
    );
    final activity = _FakeActivityCharactersRepository();
    final viewModel = CharacterManagementViewModel(
      accountRepository: repository,
      representativeSyncGateway: gateway,
      activityCharactersRepository: activity,
      playerId: 'player-1',
      clock: () => now,
    );
    addTearDown(viewModel.dispose);
    await viewModel.initialize();

    viewModel.setRepresentative(viewModel.rosterCharacters.last);
    expect(repository.representativeCharacterId, 1);
    expect(gateway.savedCharacterIds, isEmpty);

    await viewModel.save();

    expect(gateway.savedCharacterIds, ['server-character-2']);
    expect(repository.representativeCharacterId, 2);
    expect(activity.saveCount, 1);
  });

  test('does not save local state when activity save fails', () async {
    final repository = _FakeAccountRepository();
    final activity = _FakeActivityCharactersRepository()
      ..saveError = const ActivityCharactersSaveException(
        ActivityCharactersSaveFailure.notOwned,
        '현재 Player가 active 소유한 캐릭터만 선택할 수 있습니다.',
      );
    final viewModel = CharacterManagementViewModel(
      accountRepository: repository,
      activityCharactersRepository: activity,
      playerId: 'player-1',
    );
    addTearDown(viewModel.dispose);
    await viewModel.initialize();
    viewModel.toggleActivity(viewModel.rosterCharacters.last);

    await viewModel.save();

    expect(repository.visibilityUpdates, isEmpty);
    expect(repository.displayLimit, 2);
    expect(viewModel.message, contains('active 소유한 캐릭터'));
    expect(viewModel.hasUnsavedChanges, isTrue);
  });

  test('permission-denied 저장 실패는 Rules 배포 안내를 보여 준다', () async {
    final repository = _FakeAccountRepository();
    final activity = _FakeActivityCharactersRepository()
      ..saveError = const ActivityCharactersSaveException(
        ActivityCharactersSaveFailure.permissionDenied,
        '캐릭터 활동 설정을 저장할 권한이 없습니다. 최신 Firestore Rules가 배포됐는지 확인해 주세요.',
      );
    final viewModel = CharacterManagementViewModel(
      accountRepository: repository,
      activityCharactersRepository: activity,
      playerId: 'player-1',
    );
    addTearDown(viewModel.dispose);
    await viewModel.initialize();
    viewModel.toggleActivity(viewModel.rosterCharacters.last);

    await viewModel.save();

    expect(repository.visibilityUpdates, isEmpty);
    expect(viewModel.message, contains('Firestore Rules'));
    expect(viewModel.hasUnsavedChanges, isTrue);
  });

  test('blocks a second save while the first request is in flight', () async {
    final activity = _FakeActivityCharactersRepository()
      ..saveDelay = const Duration(milliseconds: 20);
    final viewModel = CharacterManagementViewModel(
      accountRepository: _FakeAccountRepository(),
      activityCharactersRepository: activity,
      playerId: 'player-1',
    );
    addTearDown(viewModel.dispose);
    await viewModel.initialize();
    viewModel.toggleActivity(viewModel.rosterCharacters.last);

    final first = viewModel.save();
    final second = viewModel.save();
    await Future.wait([first, second]);

    expect(activity.saveCount, 1);
  });

  test(
    'includes every owned account character id in the save command',
    () async {
      final repository = _FakeAccountRepository(includeSecondaryAccount: true);
      final activity = _FakeActivityCharactersRepository();
      final viewModel = CharacterManagementViewModel(
        accountRepository: repository,
        activityCharactersRepository: activity,
        playerId: 'player-1',
      );
      addTearDown(viewModel.dispose);
      await viewModel.initialize();

      await viewModel.save();

      expect(activity.lastCommand?.ownedCharacterIds, {
        'server-character-1',
        'server-character-2',
        'server-character-3',
      });
      expect(
        activity.lastCommand?.activityCharacterIds,
        containsAll(['server-character-1', 'server-character-3']),
      );
    },
  );

  test('active 인증 계정은 기존 로컬 대표를 서버에 한 번 보강한다', () async {
    final now = DateTime.utc(2026, 8, 28, 9);
    final repository = _FakeAccountRepository(serverBacked: true);
    final gateway = _FakeRepresentativeSyncGateway(
      state: const RepresentativeCharacterSyncState(
        representativeCharacterId: null,
        updatedAt: null,
      ),
      clock: () => now,
    );
    final viewModel = CharacterManagementViewModel(
      accountRepository: repository,
      representativeSyncGateway: gateway,
      activityCharactersRepository: _FakeActivityCharactersRepository(),
      playerId: 'player-1',
      clock: () => now,
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();

    expect(gateway.seededCharacterIds, ['server-character-1']);
    expect(gateway.savedCharacterIds, isEmpty);
    expect(viewModel.representativeCooldownRemaining, Duration.zero);
  });

  test('서버 대표가 있으면 로컬 선택을 서버 값으로 맞춘다', () async {
    final now = DateTime.utc(2026, 8, 28, 9);
    final repository = _FakeAccountRepository(serverBacked: true);
    final gateway = _FakeRepresentativeSyncGateway(
      state: RepresentativeCharacterSyncState(
        representativeCharacterId: 'server-character-2',
        updatedAt: now.subtract(const Duration(minutes: 6)),
      ),
      clock: () => now,
    );
    final viewModel = CharacterManagementViewModel(
      accountRepository: repository,
      representativeSyncGateway: gateway,
      activityCharactersRepository: _FakeActivityCharactersRepository(),
      playerId: 'player-1',
      clock: () => now,
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();

    expect(repository.representativeCharacterId, 2);
    expect(gateway.savedCharacterIds, isEmpty);
    expect(viewModel.draftRepresentativeId, 2);
  });

  test('서버 기준 5분 안에는 대표 변경을 막는다', () async {
    final now = DateTime.utc(2026, 8, 28, 9);
    final repository = _FakeAccountRepository(serverBacked: true);
    final gateway = _FakeRepresentativeSyncGateway(
      state: RepresentativeCharacterSyncState(
        representativeCharacterId: 'server-character-1',
        updatedAt: now.subtract(const Duration(minutes: 1)),
      ),
      clock: () => now,
    );
    final viewModel = CharacterManagementViewModel(
      accountRepository: repository,
      representativeSyncGateway: gateway,
      activityCharactersRepository: _FakeActivityCharactersRepository(),
      playerId: 'player-1',
      clock: () => now,
    );
    addTearDown(viewModel.dispose);
    await viewModel.initialize();

    viewModel.setRepresentative(viewModel.rosterCharacters.last);
    await viewModel.save();

    expect(repository.representativeCharacterId, 1);
    expect(gateway.savedCharacterIds, isEmpty);
    expect(viewModel.draftRepresentativeId, 1);
  });
  test(
    'loads and saves one auto-refresh override for all nice groups',
    () async {
      final settings = _FakeNiceGroupSettingsRepository()..enabled = true;
      final viewModel = CharacterManagementViewModel(
        accountRepository: _FakeAccountRepository(niceGroup: true),
        activityCharactersRepository: _FakeActivityCharactersRepository(),
        niceGroupSettingsRepository: settings,
        playerId: 'player-1',
      );
      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      expect(viewModel.niceGroupResult.classNames, {'바드'});
      expect(viewModel.draftNiceGroupAutoRefreshEnabled, isTrue);
      viewModel.setNiceGroupAutoRefreshEnabled(false);
      expect(viewModel.hasUnsavedChanges, isTrue);

      await viewModel.save();

      expect(settings.savedValues, [false]);
      expect(viewModel.hasUnsavedChanges, isFalse);
    },
  );
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({
    this.serverBacked = false,
    this.includeSecondaryAccount = false,
    this.niceGroup = false,
  });

  final bool serverBacked;
  final bool includeSecondaryAccount;
  final bool niceGroup;

  int representativeCharacterId = 1;
  int displayLimit = 2;
  List<int> savedOrder = [1, 2];
  final List<(int, bool)> visibilityUpdates = [];
  final Map<int, bool> _visibility = {1: true, 2: true, 3: true};

  @override
  Future<void> setPreferredCharacterRole({
    required int characterId,
    required CharacterBuildRole role,
  }) async {}

  @override
  Future<RosterSummaryApplyResult> applyRosterSummarySync({
    required int accountId,
    required String lookupCharacterName,
    required List<CharacterSummary> summaries,
    required DateTime fetchedAt,
  }) async =>
      const RosterSummaryApplyResult(updatedLocalCount: 0, serverPatches: []);

  @override
  Future<List<LocalGameAccount>> loadAccounts() async {
    final main = await loadMainAccount();
    if (main == null) return const [];
    if (!includeSecondaryAccount) return [main];
    return [
      main,
      LocalGameAccount(
        id: 20,
        serverGameAccountId: serverBacked
            ? 'server-account-2'
            : 'server-account-2',
        serverOwnershipStatus: 'active',
        label: '부계정',
        isMain: false,
        lookupCharacterName: '세번째',
        representativeCharacterId: 3,
        displayLimit: 1,
        characters: [_character(3, '세번째', true, 0)],
      ),
    ];
  }

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
  Future<LocalGameAccount?> loadMainAccount() async {
    final characters = {
      1: _character(
        1,
        '첫번째',
        _visibility[1]!,
        savedOrder.indexOf(1),
        itemLevel: niceGroup ? 1700 : null,
      ),
      2: _character(
        2,
        '두번째',
        _visibility[2]!,
        savedOrder.indexOf(2),
        itemLevel: niceGroup ? 1701 : null,
      ),
    };
    return LocalGameAccount(
      id: 10,
      serverGameAccountId: serverBacked ? 'server-account-1' : null,
      serverOwnershipStatus: serverBacked ? 'active' : null,
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: '첫번째',
      representativeCharacterId: representativeCharacterId,
      displayLimit: displayLimit,
      characters: savedOrder.map((id) => characters[id]!).toList(),
    );
  }

  @override
  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  }) async {
    representativeCharacterId = characterId;
  }

  @override
  Future<void> markRepresentativeReconciled({
    required int accountId,
    required String serverCharacterId,
  }) async {}

  @override
  Future<void> updateDisplayLimit({
    required int accountId,
    required int displayLimit,
  }) async {
    this.displayLimit = displayLimit;
  }

  @override
  Future<void> updateCharacterVisibility({
    required int accountId,
    required int characterId,
    required bool isVisible,
  }) async {
    visibilityUpdates.add((characterId, isVisible));
    _visibility[characterId] = isVisible;
  }

  @override
  Future<void> updateCharacterDisplayOrder({
    required int accountId,
    required List<int> characterIds,
  }) async {
    final expected = accountId == 20 ? {3} : {1, 2};
    if (characterIds.length != expected.length ||
        !expected.containsAll(characterIds)) {
      throw ArgumentError.value(
        characterIds,
        'characterIds',
        'Display order must contain every character in the account once. '
            'accountId=$accountId expected=$expected actual=$characterIds',
      );
    }
    savedOrder = List.of(characterIds);
  }

  @override
  Future<List<CharacterSummary>> fetchCharacters(String characterName) {
    throw UnimplementedError();
  }

  @override
  Future<CharacterProfile> fetchCharacterProfile(String characterName) {
    throw UnimplementedError();
  }
}

LocalAccountCharacter _character(
  int id,
  String name,
  bool isVisible,
  int displayOrder, {
  double? itemLevel,
}) {
  return LocalAccountCharacter(
    id: id,
    serverName: '루페온',
    characterName: name,
    characterLevel: 70,
    characterClassName: '바드',
    itemLevel: itemLevel ?? 1700 - id.toDouble(),
    combatPower: null,
    isVisible: isVisible,
    displayOrder: displayOrder,
    serverCharacterId: 'server-character-$id',
  );
}

class _FakeNiceGroupSettingsRepository
    implements NiceGroupAutoRefreshSettingsRepository {
  bool enabled = false;
  final List<bool> savedValues = [];

  @override
  Future<bool> loadEnabled({required String playerId}) async => enabled;

  @override
  Future<void> saveEnabled({
    required String playerId,
    required bool enabled,
  }) async {
    this.enabled = enabled;
    savedValues.add(enabled);
  }
}

class _FakeActivityCharactersRepository
    implements ActivityCharactersRepository {
  Set<String> characterIds = {};
  SaveActivityCharactersCommand? lastCommand;
  int saveCount = 0;
  Duration? saveDelay;
  ActivityCharactersSaveException? saveError;

  @override
  Future<ActivityCharacters> load({required String playerId}) async {
    return ActivityCharacters(playerId: playerId, characterIds: characterIds);
  }

  @override
  Future<ActivityCharacters> save(SaveActivityCharactersCommand command) async {
    saveCount += 1;
    lastCommand = command;
    if (saveDelay != null) {
      await Future<void>.delayed(saveDelay!);
    }
    if (saveError != null) {
      throw saveError!;
    }
    characterIds = Set.of(command.activityCharacterIds);
    return ActivityCharacters(playerId: 'player-1', characterIds: characterIds);
  }
}

class _FakeRepresentativeSyncGateway
    implements RepresentativeCharacterSyncGateway {
  _FakeRepresentativeSyncGateway({required this.state, required this.clock});

  RepresentativeCharacterSyncState state;
  final DateTime Function() clock;
  final List<String> savedCharacterIds = [];
  final List<String> seededCharacterIds = [];

  @override
  Future<RepresentativeCharacterSyncState> loadState({
    required String gameAccountId,
  }) async => state;

  @override
  Future<RepresentativeCharacterSyncState> setRepresentative({
    required String gameAccountId,
    required String characterId,
  }) async {
    savedCharacterIds.add(characterId);
    state = RepresentativeCharacterSyncState(
      representativeCharacterId: characterId,
      updatedAt: clock(),
    );
    return state;
  }

  @override
  Future<RepresentativeCharacterSyncState> seedRepresentative({
    required String gameAccountId,
    required String characterId,
  }) async {
    seededCharacterIds.add(characterId);
    state = RepresentativeCharacterSyncState(
      representativeCharacterId: characterId,
      updatedAt: null,
    );
    return state;
  }
}
