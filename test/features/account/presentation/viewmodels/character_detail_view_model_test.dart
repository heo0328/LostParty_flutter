import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/character_detail_view_model.dart';

void main() {
  test('support class requires a role selection before refreshing', () async {
    final repository = _FakeAccountRepository();
    final viewModel = CharacterDetailViewModel(
      character: _character(className: '바드'),
      accountRepository: repository,
    );

    await viewModel.initialize();
    await viewModel.refreshSelectedRole();

    expect(viewModel.supportsMultipleRoles, isTrue);
    expect(viewModel.selectedRole, isNull);
    expect(repository.refreshedRoles, isEmpty);

    viewModel.selectRole(CharacterBuildRole.support);
    await viewModel.refreshSelectedRole();

    expect(repository.refreshedRoles, [CharacterBuildRole.support]);
    expect(viewModel.selectedSnapshot?.role, CharacterBuildRole.support);
  });

  test('dealer class defaults to the dealer role', () {
    final viewModel = CharacterDetailViewModel(
      character: _character(className: '슬레이어'),
      accountRepository: _FakeAccountRepository(),
    );

    expect(viewModel.supportsMultipleRoles, isFalse);
    expect(viewModel.selectedRole, CharacterBuildRole.dealer);
  });
}

class _FakeAccountRepository implements AccountRepository {
  final List<CharacterBuildRole> refreshedRoles = [];
  final List<CharacterBuildSnapshot> _snapshots = [];

  @override
  Future<CharacterBuildSnapshot> refreshCharacterBuildSnapshot({
    required int characterId,
    required String characterName,
    required CharacterBuildRole role,
  }) async {
    refreshedRoles.add(role);
    final snapshot = CharacterBuildSnapshot(
      id: refreshedRoles.length,
      characterId: characterId,
      role: role,
      rawJson: '{}',
      itemLevel: 1700,
      combatPower: 100000,
      capturedAt: DateTime(2026),
      dataVersion: 1,
      analysis: const CharacterBuildAnalysis(
        runeCount: 8,
        gemEffects: [],
        arkGridConditions: [],
        arkGridCorePoints: [],
        notices: [],
      ),
    );
    _snapshots.removeWhere((item) => item.role == role);
    _snapshots.add(snapshot);
    return snapshot;
  }

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => List.unmodifiable(_snapshots);

  @override
  Future<List<CharacterSummary>> fetchCharacters(String characterName) =>
      throw UnimplementedError();

  @override
  Future<CharacterProfile> fetchCharacterProfile(String characterName) =>
      throw UnimplementedError();

  @override
  Future<LocalGameAccount?> loadMainAccount() => throw UnimplementedError();

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
  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  }) async {}

  @override
  Future<void> updateCharacterDisplayOrder({
    required int accountId,
    required List<int> characterIds,
  }) async {}

  @override
  Future<void> updateCharacterVisibility({
    required int accountId,
    required int characterId,
    required bool isVisible,
  }) async {}

  @override
  Future<void> updateDisplayLimit({
    required int accountId,
    required int displayLimit,
  }) async {}
}

LocalAccountCharacter _character({required String className}) {
  return LocalAccountCharacter(
    id: 1,
    serverName: '루페온',
    characterName: '테스트캐릭터',
    characterLevel: 70,
    characterClassName: className,
    itemLevel: 1700,
    combatPower: 100000,
    isVisible: true,
    displayOrder: 0,
  );
}
