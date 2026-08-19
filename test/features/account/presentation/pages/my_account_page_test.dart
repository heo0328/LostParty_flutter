import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
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

    expect(find.text('캐릭터 1개'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('이슈아이'),
      ),
      findsOneWidget,
    );
    expect(find.text('루페온 · 바드'), findsOneWidget);
    expect(find.text('1766.66'), findsOneWidget);
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

    expect(find.text('대표 캐릭터명을 입력해 주세요.'), findsOneWidget);
  });
}

class _FakeAccountRepository implements AccountRepository {
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
