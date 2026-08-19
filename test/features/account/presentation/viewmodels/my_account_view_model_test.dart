import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
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
  Future<List<CharacterSummary>> fetchCharacters(String characterName) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return characters;
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
