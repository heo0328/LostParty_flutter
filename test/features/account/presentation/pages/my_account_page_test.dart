import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/entities/character_auto_refresh_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/presentation/pages/my_account_page.dart';
import 'package:lost_party/features/account/domain/services/startup_character_refresh_orchestrator.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';

void main() {
  testWidgets('모바일 폭에서 인증과 조회 액션을 두 개의 compact 행으로 배치한다', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MyAccountPage(
          apiTokenStore: _InMemoryApiTokenStore(),
          accountRepository: _FakeAccountRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final setupActions = find.byKey(const ValueKey('accountSetupActions'));
    expect(
      find.descendant(
        of: setupActions,
        matching: find.byKey(const ValueKey('apiTokenSettingsButton')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: setupActions,
        matching: find.byKey(const ValueKey('gameAccountVerificationButton')),
      ),
      findsOneWidget,
    );

    final lookupActions = find.byKey(const ValueKey('accountLookupActions'));
    expect(
      find.descendant(
        of: lookupActions,
        matching: find.byKey(
          const ValueKey('representativeCharacterNameField'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: lookupActions,
        matching: find.byKey(const ValueKey('loadAccountDataButton')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: lookupActions,
        matching: find.byKey(const ValueKey('addSubAccountButton')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a verification badge for a server-bound account', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyAccountPage(
          apiTokenStore: _InMemoryApiTokenStore(),
          accountRepository: _FakeAccountRepository(serverBound: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('계정 인증 완료'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('verifiedGameAccountChip')),
      findsOneWidget,
    );
  });

  testWidgets('shows an ownership lost badge for a taken-over account', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyAccountPage(
          apiTokenStore: _InMemoryApiTokenStore(),
          accountRepository: _FakeAccountRepository(lostOwnership: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('인증 상실'), findsOneWidget);
    expect(find.text('계정 인증 완료'), findsNothing);
  });

  testWidgets('warns about and manually deletes a missing roster character', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAccountRepository(missingRoster: true);
    await tester.pumpWidget(
      MaterialApp(
        home: MyAccountPage(
          apiTokenStore: _InMemoryApiTokenStore(),
          accountRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('최근 원정대에서 확인되지 않는 캐릭터가 있습니다.'), findsOneWidget);
    expect(find.text('사라진캐릭터'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('deleteMissingCharacter-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();

    expect(repository.deletedMissingCharacterId, 2);
  });

  testWidgets('prefills the main representative character name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyAccountPage(
          apiTokenStore: _InMemoryApiTokenStore(),
          accountRepository: _FakeAccountRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(
                const ValueKey('representativeCharacterNameField'),
              ),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      '이슈아이',
    );
  });

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
    expect(find.text('아이템 Lv. 1,766.66'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lookupCharacterProfileCard')),
      findsOneWidget,
    );
    expect(find.text('전투력 338,229.42'), findsNWidgets(2));
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

    await tester.enterText(
      find.byKey(const ValueKey('representativeCharacterNameField')),
      '',
    );
    await tester.tap(find.byKey(const ValueKey('loadAccountDataButton')));
    await tester.pumpAndSettle();

    expect(find.text('조회할 캐릭터명을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('adds a sub account and closes its dialog cleanly', (
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
    await tester.tap(find.byKey(const ValueKey('addSubAccountButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('subAccountCharacterNameField')),
      '부계정캐릭터',
    );
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('부계정1'), findsOneWidget);
    expect(find.text('부계정'), findsOneWidget);

    final deleteButton = find.byKey(const ValueKey('deleteAccountButton-2'));
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('부계정1'), findsNothing);
  });

  testWidgets('메인 계정 새로고침은 확인 후 실행하고 완료 뒤 10초 제한을 표시한다', (
    WidgetTester tester,
  ) async {
    final runner = _ManualRefreshRunner();
    await tester.pumpWidget(
      MaterialApp(
        home: MyAccountPage(
          apiTokenStore: _InMemoryApiTokenStore(),
          accountRepository: _FakeAccountRepository(),
          manualCharacterRefreshRunner: runner,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('manualCharacterRefreshButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('캐릭터 정보 전체 갱신'), findsOneWidget);
    expect(runner.runCount, 0);

    await tester.tap(
      find.byKey(const ValueKey('confirmManualCharacterRefreshButton')),
    );
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey('manualCharacterRefreshButton'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(runner.runCount, 1);

    await tester.tap(
      find.byKey(const ValueKey('manualCharacterRefreshButton')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('manualCharacterRefreshCooldown')),
      findsOneWidget,
    );
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirmManualCharacterRefreshButton')).last,
    );
    expect(confirm.onPressed, isNull);
    await tester.tap(find.widgetWithText(TextButton, '취소').last);
    await tester.pumpAndSettle();
  });
}

class _ManualRefreshRunner implements ManualCharacterRefreshRunner {
  final _states = StreamController<StartupCharacterRefreshState>.broadcast(
    sync: true,
  );
  var _state = const StartupCharacterRefreshState.idle();
  int runCount = 0;

  @override
  StartupCharacterRefreshState get state => _state;

  @override
  Stream<StartupCharacterRefreshState> get states => _states.stream;

  @override
  Future<StartupCharacterRefreshReport> runManualExcludingNiceGroup() async {
    runCount++;
    _state = const StartupCharacterRefreshState(
      phase: StartupCharacterRefreshPhase.running,
      totalCount: 1,
      completedCount: 0,
      failedCount: 0,
    );
    _states.add(_state);
    _state = const StartupCharacterRefreshState(
      phase: StartupCharacterRefreshPhase.completed,
      totalCount: 1,
      completedCount: 1,
      failedCount: 0,
    );
    _states.add(_state);
    return const StartupCharacterRefreshReport(
      items: [
        StartupCharacterRefreshItemResult(
          character: LocalAccountCharacter(
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
          result: CharacterAutoRefreshResult(
            status: CharacterAutoRefreshStatus.refreshed,
            characterId: 1,
            generation: 0,
            snapshot: null,
            detectedRole: null,
            expectedRoleChanged: false,
            message: null,
          ),
        ),
      ],
    );
  }
}

class _FakeAccountRepository
    implements AccountRepository, AccountManagementRepository {
  _FakeAccountRepository({
    this.serverBound = false,
    this.missingRoster = false,
    this.lostOwnership = false,
  });

  final bool serverBound;
  final bool missingRoster;
  final bool lostOwnership;
  int? deletedMissingCharacterId;
  LocalGameAccount? _subAccount;

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
    return [?account, ?_subAccount];
  }

  @override
  Future<LocalGameAccount> addAccount({
    required String label,
    required String lookupCharacterName,
  }) async {
    return _subAccount = LocalGameAccount(
      id: 2,
      label: label.trim().isEmpty ? '부계정1' : label,
      isMain: false,
      lookupCharacterName: lookupCharacterName,
      representativeCharacterId: 2,
      displayLimit: 6,
      characters: [
        LocalAccountCharacter(
          id: 2,
          serverName: '카단',
          characterName: lookupCharacterName,
          characterLevel: 70,
          characterClassName: '슬레이어',
          itemLevel: 1700,
          combatPower: 300000,
          isVisible: true,
          displayOrder: 0,
        ),
      ],
    );
  }

  @override
  Future<void> updateAccount({
    required int accountId,
    required String label,
    required bool isMain,
  }) async {}

  @override
  Future<void> deleteAccount(int accountId) async {
    if (_subAccount?.id == accountId) _subAccount = null;
  }

  @override
  Future<void> deleteMissingCharacter({
    required int accountId,
    required int characterId,
  }) async {
    deletedMissingCharacterId = characterId;
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
    return LocalGameAccount(
      id: 1,
      serverGameAccountId: serverBound || lostOwnership
          ? 'game-account-1'
          : null,
      serverOwnershipStatus: lostOwnership
          ? 'ownershipLost'
          : serverBound
          ? 'active'
          : null,
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
        if (missingRoster)
          const LocalAccountCharacter(
            id: 2,
            serverName: '루페온',
            characterName: '사라진캐릭터',
            characterLevel: 70,
            characterClassName: '바드',
            itemLevel: 1600,
            combatPower: null,
            isVisible: true,
            isRosterMissing: true,
            displayOrder: 1,
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
