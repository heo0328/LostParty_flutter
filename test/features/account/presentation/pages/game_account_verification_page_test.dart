import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/game_account_verification.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/entities/server_account_identity_binding.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/account_identity_gateway.dart';
import 'package:lost_party/features/account/domain/repositories/game_account_verification_gateway.dart';
import 'package:lost_party/features/account/presentation/pages/game_account_verification_page.dart';

void main() {
  testWidgets('supports provisional selection and direct character input', (
    tester,
  ) async {
    final gateway = _FakeVerificationGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: GameAccountVerificationPage(
          accountRepository: _FakeAccountRepository(),
          accountManagementRepository: _FakeAccountManagementRepository(),
          mappingRepository: _FakeMappingRepository(),
          gateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('가등록 캐릭터 선택'), findsOneWidget);
    expect(find.text('또는 캐릭터명 직접 입력'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '선택한 캐릭터로 인증'));
    await tester.pumpAndSettle();
    expect(gateway.lastSource, 'provisional');
    expect(gateway.lastLocalAccountId, 1);
    expect(find.textContaining('머리, 무기'), findsOneWidget);
    expect(find.textContaining('접속을 한 번 종료'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('verificationDirectCharacterField')),
      '직접입력캐릭터',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '직접 입력으로 인증'));
    await tester.pumpAndSettle();
    expect(gateway.lastCharacterName, '직접입력캐릭터');
    expect(gateway.lastSource, 'directInput');
    expect(gateway.lastLocalAccountId, isNull);
  });

  testWidgets('creates and binds a local account after direct verification', (
    tester,
  ) async {
    final gateway = _FakeVerificationGateway();
    final management = _FakeAccountManagementRepository();
    final mapping = _FakeMappingRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: GameAccountVerificationPage(
          accountRepository: _EmptyAccountRepository(),
          accountManagementRepository: management,
          mappingRepository: mapping,
          gateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('verificationDirectCharacterField')),
      '직접입력캐릭터',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '직접 입력으로 인증'));
    await tester.pumpAndSettle();
    final confirmButton = find.widgetWithText(FilledButton, '장비 변경 확인');
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(management.lookupCharacterName, '직접입력캐릭터');
    expect(mapping.saved?.serverGameAccountId, 'game-account-1');
    expect(mapping.saved?.serverCharacterIdsByLocalId, {21: 'character-1'});
    expect(find.text('게임 계정 인증과 로컬 연결이 완료되었습니다.'), findsOneWidget);
  });
}

class _FakeMappingRepository extends Fake
    implements AccountIdentityMappingRepository {
  ServerAccountIdentityBinding? saved;

  @override
  Future<void> bindServerIdentity(ServerAccountIdentityBinding binding) async {
    saved = binding;
  }
}

class _EmptyAccountRepository extends Fake implements AccountRepository {

  @override
  Future<RosterSummaryApplyResult> applyRosterSummarySync({
    required int accountId,
    required String lookupCharacterName,
    required List<CharacterSummary> summaries,
    required DateTime fetchedAt,
  }) async =>
      const RosterSummaryApplyResult(updatedLocalCount: 0, serverPatches: []);

  @override
  Future<List<LocalGameAccount>> loadAccounts() async => const [];
}

class _FakeAccountManagementRepository extends Fake
    implements AccountManagementRepository {
  String? lookupCharacterName;

  @override
  Future<LocalGameAccount> addAccount({
    required String label,
    required String lookupCharacterName,
  }) async {
    this.lookupCharacterName = lookupCharacterName;
    return LocalGameAccount(
      id: 2,
      label: label,
      isMain: false,
      lookupCharacterName: lookupCharacterName,
      representativeCharacterId: 21,
      displayLimit: 1,
      characters: [
        LocalAccountCharacter(
          id: 21,
          serverName: '루페온',
          characterName: lookupCharacterName,
          characterLevel: 70,
          characterClassName: '도화가',
          itemLevel: 1700,
          combatPower: null,
          isVisible: true,
          displayOrder: 0,
        ),
      ],
    );
  }

  @override
  Future<void> deleteMissingCharacter({
    required int accountId,
    required int characterId,
  }) async {}
}

class _FakeAccountRepository extends Fake implements AccountRepository {

  @override
  Future<RosterSummaryApplyResult> applyRosterSummarySync({
    required int accountId,
    required String lookupCharacterName,
    required List<CharacterSummary> summaries,
    required DateTime fetchedAt,
  }) async =>
      const RosterSummaryApplyResult(updatedLocalCount: 0, serverPatches: []);

  @override
  Future<List<LocalGameAccount>> loadAccounts() async => const [
    LocalGameAccount(
      id: 1,
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: '이슈아이',
      representativeCharacterId: 11,
      displayLimit: 1,
      characters: [
        LocalAccountCharacter(
          id: 11,
          serverName: '루페온',
          characterName: '이슈아이',
          characterLevel: 70,
          characterClassName: '도화가',
          itemLevel: 1700,
          combatPower: null,
          isVisible: true,
          displayOrder: 0,
        ),
      ],
    ),
  ];
}

class _FakeVerificationGateway implements GameAccountVerificationGateway {
  String? lastCharacterName;
  String? lastSource;
  int? lastLocalAccountId;

  @override
  Future<GameAccountVerificationChallenge> start({
    required String characterName,
    required String source,
    int? localAccountId,
  }) async {
    lastCharacterName = characterName;
    lastSource = source;
    lastLocalAccountId = localAccountId;
    return GameAccountVerificationChallenge(
      challengeId: 'challenge-1',
      characterName: characterName,
      requiredUnequippedSlots: const ['head', 'weapon'],
      expiresAt: DateTime(2026, 8, 25, 10, 10),
    );
  }

  @override
  Future<GameAccountVerificationResult> confirm(String challengeId) async =>
      const GameAccountVerificationResult(
        status: 'verified',
        serverGameAccountId: 'game-account-1',
        serverCharacters: [
          VerifiedServerCharacter(
            serverName: '루페온',
            characterName: '직접입력캐릭터',
            serverCharacterId: 'character-1',
          ),
        ],
      );
}
