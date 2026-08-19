import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/presentation/pages/my_account_page.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';

void main() {
  testWidgets('shows characters returned from an account lookup', (
    WidgetTester tester,
  ) async {
    final tokenStore = _InMemoryApiTokenStore();
    await tokenStore.write(ApiToken('jwt-value'));

    await tester.pumpWidget(
      MaterialApp(
        home: MyAccountPage(
          apiTokenStore: tokenStore,
          accountRepository: _FakeAccountRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('representativeCharacterNameField')),
      '이슈아이',
    );
    await tester.tap(find.byKey(const ValueKey('loadAccountDataButton')));
    await tester.pumpAndSettle();

    expect(find.text('메인 계정'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mainAccountCharacterGrid')),
        matching: find.text('이슈아이'),
      ),
      findsOneWidget,
    );
    expect(find.text('아이템 Lv. 1766.66'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lookupCharacterProfileCard')),
      findsOneWidget,
    );
    expect(find.text('전투력 338229.42'), findsNWidgets(2));
  });

  testWidgets('validates a missing character name after token registration', (
    WidgetTester tester,
  ) async {
    final tokenStore = _InMemoryApiTokenStore();
    await tokenStore.write(ApiToken('jwt-value'));

    await tester.pumpWidget(
      MaterialApp(
        home: MyAccountPage(
          apiTokenStore: tokenStore,
          accountRepository: _FakeAccountRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('loadAccountDataButton')));
    await tester.pumpAndSettle();

    expect(find.text('조회할 캐릭터명을 입력해 주세요.'), findsOneWidget);
  });
}

class _FakeAccountRepository implements AccountRepository {
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
    return [
      CharacterSummary(
        serverName: '루페온',
        characterName: characterName,
        characterLevel: 70,
        characterClassName: '바드',
        itemLevel: 1766.66,
      ),
    ];
  }

  @override
  Future<CharacterProfile> fetchCharacterProfile(String characterName) async {
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
    return const LocalGameAccount(
      id: 1,
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: '이슈아이',
      representativeCharacterId: 1,
      displayLimit: 6,
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverName: '루페온',
          characterName: '이슈아이',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1766.66,
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
