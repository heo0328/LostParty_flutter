import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/theme/app_theme.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/activity_characters_repository.dart';
import 'package:lost_party/features/account/presentation/pages/character_management_page.dart';

void main() {
  testWidgets('shows selection cards, count, and saves once', (tester) async {
    final accountRepository = _FakeAccountRepository();
    final activity = _FakeActivityCharactersRepository();
    await tester.pumpWidget(
      _wrap(
        CharacterManagementPage(
          accountRepository: accountRepository,
          activityCharactersRepository: activity,
          playerId: 'player-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('앱에서 사용할 캐릭터'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('첫번째'), findsWidgets);
    expect(find.text('메인 화면 표시 개수'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.byKey(const ValueKey('activityCard-2')));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('characterManagementSaveButton')),
    );
    await tester.pumpAndSettle();

    expect(activity.saveCount, 1);
    expect(activity.lastCommand?.activityCharacterIds, {'server-character-1'});
  });

  testWidgets('does not deselect the representative card', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CharacterManagementPage(
          accountRepository: _FakeAccountRepository(),
          activityCharactersRepository: _FakeActivityCharactersRepository(),
          playerId: 'player-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('activityCard-1')));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('cancel restores the previous selection', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CharacterManagementPage(
          accountRepository: _FakeAccountRepository(),
          activityCharactersRepository: _FakeActivityCharactersRepository(),
          playerId: 'player-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('activityCard-2')));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '취소'));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: child);
}

class _FakeAccountRepository implements AccountRepository {
  int representativeCharacterId = 1;
  int displayLimit = 2;
  List<int> savedOrder = [1, 2];
  final Map<int, bool> _visibility = {1: true, 2: true};

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
    serverCharacterId: 'server-character-$id',
  );
}

class _FakeActivityCharactersRepository
    implements ActivityCharactersRepository {
  Set<String> characterIds = {};
  SaveActivityCharactersCommand? lastCommand;
  int saveCount = 0;

  @override
  Future<ActivityCharacters> load({required String playerId}) async {
    return ActivityCharacters(playerId: playerId, characterIds: characterIds);
  }

  @override
  Future<ActivityCharacters> save(SaveActivityCharactersCommand command) async {
    saveCount += 1;
    lastCommand = command;
    characterIds = Set.of(command.activityCharacterIds);
    return ActivityCharacters(playerId: 'player-1', characterIds: characterIds);
  }
}
