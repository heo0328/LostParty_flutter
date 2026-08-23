import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/character_management_view_model.dart';

void main() {
  test('selecting a hidden representative makes it visible', () async {
    final repository = _FakeAccountRepository();
    final viewModel = CharacterManagementViewModel(
      accountRepository: repository,
    );
    await viewModel.initialize();

    await viewModel.setRepresentative(viewModel.characters.last);

    expect(repository.visibilityUpdates, [(2, true)]);
    expect(repository.representativeCharacterId, 2);
    expect(viewModel.account?.representativeCharacterId, 2);
    expect(viewModel.characters.first.id, 2);
    expect(viewModel.characters.first.isVisible, isTrue);
  });

  test('updates the display limit and character order', () async {
    final repository = _FakeAccountRepository();
    final viewModel = CharacterManagementViewModel(
      accountRepository: repository,
    );
    await viewModel.initialize();

    await viewModel.changeDisplayLimit(-1);
    await viewModel.reorder(0, 2);

    expect(repository.displayLimit, 1);
    expect(repository.savedOrder, [2, 1]);
    expect(viewModel.characters.map((character) => character.id), [1, 2]);
  });

  test('hiding the representative selects the highest item level', () async {
    final repository = _FakeAccountRepository();
    final viewModel = CharacterManagementViewModel(
      accountRepository: repository,
    );
    await viewModel.initialize();

    await viewModel.setCharacterVisibility(viewModel.characters.first, false);

    expect(repository.visibilityUpdates, [(1, false), (2, true)]);
    expect(repository.representativeCharacterId, 2);
    expect(viewModel.characters.first.id, 2);
    expect(viewModel.characters.first.isVisible, isTrue);
  });
}

class _FakeAccountRepository implements AccountRepository {
  @override
  Future<void> setPreferredCharacterRole({
    required int characterId,
    required CharacterBuildRole role,
  }) async {}
  @override
  Future<List<LocalGameAccount>> loadAccounts() async {
    final account = await loadMainAccount();
    return account == null ? const [] : [account];
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

  int representativeCharacterId = 1;
  int displayLimit = 2;
  List<int> savedOrder = [1, 2];
  final List<(int, bool)> visibilityUpdates = [];
  final Map<int, bool> _visibility = {1: true, 2: false};

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
      1: _character(1, '첫번째', _visibility[1]!, savedOrder.indexOf(1)),
      2: _character(2, '두번째', _visibility[2]!, savedOrder.indexOf(2)),
    };
    return LocalGameAccount(
      id: 10,
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
  int displayOrder,
) {
  return LocalAccountCharacter(
    id: id,
    serverName: '루페온',
    characterName: name,
    characterLevel: 70,
    characterClassName: '바드',
    itemLevel: 1700 - id.toDouble(),
    combatPower: null,
    isVisible: isVisible,
    displayOrder: displayOrder,
  );
}
