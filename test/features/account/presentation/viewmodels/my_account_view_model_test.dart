import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
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
}

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
  _FakeAccountRepository({this.characters = const [], this.error});

  final List<CharacterSummary> characters;
  final LostArkApiException? error;

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
