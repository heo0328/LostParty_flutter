import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/my_account_view_model.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_exception.dart';

void main() {
  late _InMemoryApiTokenStore tokenStore;

  setUp(() {
    tokenStore = _InMemoryApiTokenStore();
  });

  test('basic mode never invokes the optional profile lookup', () async {
    final model = MyAccountViewModel(
      apiTokenStore: tokenStore,
      accountRepository: _BasicProfileTrap(),
      basicOnly: true,
    );
    await model.fetchCharacters('이슈아이');
    expect(model.hasFetchedCharacters, isTrue);
    expect(model.lookupProfile, isNull);
    model.dispose();
  });

  test('loads the token registration status', () async {
    await tokenStore.write(ApiToken('jwt-value'));
    final viewModel = MyAccountViewModel(
      apiTokenStore: tokenStore,
      accountRepository: _FakeAccountRepository(),
    );

    await viewModel.loadTokenStatus();

    expect(viewModel.hasApiToken, isTrue);
    expect(viewModel.isLoadingTokenStatus, isFalse);
  });

  test('stores characters returned by the repository', () async {
    final characters = [_createCharacterSummary()];
    final viewModel = MyAccountViewModel(
      apiTokenStore: tokenStore,
      accountRepository: _FakeAccountRepository(characters: characters),
    );

    await viewModel.fetchCharacters('이슈아이');

    expect(viewModel.characters, characters);
    expect(viewModel.lookupProfile?.combatPower, 338229.42);
    expect(viewModel.mainAccount?.visibleCharacters, hasLength(1));
    expect(viewModel.hasFetchedCharacters, isTrue);
    expect(viewModel.errorType, isNull);
    expect(viewModel.isFetchingCharacters, isFalse);
  });

  test('stores a typed API error without exposing the exception', () async {
    final viewModel = MyAccountViewModel(
      apiTokenStore: tokenStore,
      accountRepository: _FakeAccountRepository(
        error: const LostArkApiException(
          type: LostArkApiErrorType.unauthorized,
          statusCode: 401,
        ),
      ),
    );

    await viewModel.fetchCharacters('이슈아이');

    expect(viewModel.errorType, LostArkApiErrorType.unauthorized);
    expect(viewModel.hasFetchedCharacters, isFalse);
    expect(viewModel.isFetchingCharacters, isFalse);
  });

  test('uses the preferred-role snapshot for account gem validation', () async {
    final repository = _FakeAccountRepository(
      preferredRole: CharacterBuildRole.support,
      snapshots: [
        _snapshot(
          role: CharacterBuildRole.dealer,
          status: GemValidationStatus.verified,
          capturedAt: DateTime.utc(2026, 9, 8, 1),
        ),
        _snapshot(
          role: CharacterBuildRole.support,
          status: GemValidationStatus.foreignClass,
          capturedAt: DateTime.utc(2026, 9, 8, 2),
        ),
      ],
    );
    final viewModel = MyAccountViewModel(
      apiTokenStore: tokenStore,
      accountRepository: repository,
    );

    await viewModel.loadStoredAccount();
    final character = viewModel.mainAccount!.characters.single;

    expect(
      viewModel.gemValidationSummaryFor(character)?.status,
      GemValidationSummaryStatus.foreignClass,
    );
  });
}

CharacterBuildSnapshot _snapshot({
  required CharacterBuildRole role,
  required GemValidationStatus status,
  required DateTime capturedAt,
}) => CharacterBuildSnapshot(
  id: role.index + 1,
  characterId: 1,
  role: role,
  rawJson: '{}',
  itemLevel: 1760,
  combatPower: 1,
  capturedAt: capturedAt,
  dataVersion: 1,
  analysis: CharacterBuildAnalysis(
    runeCount: 8,
    gemEffects: [
      GemSkillEffect(
        gemSlot: 0,
        gemLevel: 10,
        skillName: '테스트',
        descriptions: const [],
        category: GemSkillCategory.normal,
        validationStatus: status,
      ),
    ],
    arkGridConditions: const [],
    arkGridCorePoints: const [],
    notices: const [],
  ),
);

CharacterSummary _createCharacterSummary() {
  return const CharacterSummary(
    serverName: '루페온',
    characterName: '이슈아이',
    characterLevel: 70,
    characterClassName: '바드',
    itemLevel: 1766.66,
  );
}

class _FakeAccountRepository implements AccountRepository {
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

  _FakeAccountRepository({
    this.characters = const [],
    this.error,
    this.preferredRole,
    this.snapshots = const [],
  });

  final List<CharacterSummary> characters;
  final LostArkApiException? error;
  final CharacterBuildRole? preferredRole;
  final List<CharacterBuildSnapshot> snapshots;

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
  ) async => snapshots;

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

  @override
  Future<List<CharacterSummary>> fetchCharacters(String characterName) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return characters;
  }

  @override
  Future<CharacterProfile> fetchCharacterProfile(String characterName) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return CharacterProfile(
      serverName: '루페온',
      characterName: characterName,
      characterLevel: 70,
      characterClassName: '바드',
      itemLevel: 1766.66,
      combatPower: 338229.42,
    );
  }

  @override
  Future<LocalGameAccount?> loadMainAccount() async {
    final character = characters.isEmpty
        ? _createCharacterSummary()
        : characters.first;
    return LocalGameAccount(
      id: 1,
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: character.characterName,
      representativeCharacterId: 1,
      displayLimit: 6,
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverName: character.serverName,
          characterName: character.characterName,
          characterLevel: character.characterLevel,
          characterClassName: character.characterClassName,
          itemLevel: character.itemLevel,
          combatPower: 338229.42,
          isVisible: true,
          displayOrder: 0,
          preferredRole: preferredRole,
        ),
      ],
    );
  }
}

class _InMemoryApiTokenStore implements ApiTokenStore {
  ApiToken? _token;

  @override
  Future<ApiToken?> read() async => _token;

  @override
  Future<void> write(ApiToken token) async {
    _token = token;
  }

  @override
  Future<void> delete() async {
    _token = null;
  }
}

class _BasicProfileTrap extends _FakeAccountRepository {
  _BasicProfileTrap() : super(characters: [_createCharacterSummary()]);
  @override
  Future<CharacterProfile> fetchCharacterProfile(String name) async =>
      throw StateError('Basic mode must never request detail');
}
