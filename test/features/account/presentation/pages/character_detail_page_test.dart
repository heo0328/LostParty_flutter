import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_catalog_detection.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/presentation/pages/character_detail_page.dart';

void main() {
  testWidgets('previews analysis and cancels without committing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeAccountRepository();

    await _pumpPage(tester, repository);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('characterBuildRoleControl')),
        matching: find.text('서포터'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('saveCharacterBuildButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('characterBuildDraftPreview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('characterBuildDraftPreviewScroll')),
      findsOneWidget,
    );
    expect(find.text('계열: 딜바드'), findsOneWidget);
    expect(find.text('감지 역할: 딜러'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('characterBuildRoleMismatchNotice')),
      findsOneWidget,
    );
    expect(find.textContaining('룬 설정을 확인해 주세요.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();

    expect(repository.committedRoles, isEmpty);
    expect(
      find.byKey(const ValueKey('characterBuildDraftPreview')),
      findsNothing,
    );
  });

  testWidgets('commits a mismatched draft to the selected role', (
    tester,
  ) async {
    final repository = _FakeAccountRepository();
    await _pumpPage(tester, repository);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('characterBuildRoleControl')),
        matching: find.text('서포터'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('saveCharacterBuildButton')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('commitCharacterBuildDraftButton')),
    );
    await tester.pumpAndSettle();

    expect(repository.committedRoles, [CharacterBuildRole.support]);
    expect(
      find.byKey(const ValueKey('characterBuildDraftPreview')),
      findsNothing,
    );
    expect(find.text('저장되지 않음'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeAccountRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CharacterDetailPage(
        character: _character,
        accountRepository: repository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _character = LocalAccountCharacter(
  id: 1,
  serverName: '루페온',
  characterName: '테스트바드',
  characterLevel: 70,
  characterClassName: '바드',
  itemLevel: 1700,
  combatPower: 100000,
  isVisible: true,
  displayOrder: 0,
);

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

  final List<CharacterBuildRole> committedRoles = [];
  final List<CharacterBuildSnapshot> _snapshots = [];

  CharacterBuildDraft get _draft => CharacterBuildDraft(
    characterId: 1,
    rawJson: '{}',
    profile: const CharacterProfile(
      serverName: '루페온',
      characterName: '테스트바드',
      characterLevel: 70,
      characterClassName: '바드',
      itemLevel: 1710,
      combatPower: 110000,
    ),
    analysis: const CharacterBuildAnalysis(
      runeCount: 7,
      gemEffects: [],
      arkGridConditions: [],
      arkGridCorePoints: [],
      notices: [
        BuildNotice(
          code: 'rune_count',
          level: BuildNoticeLevel.warning,
          message: '룬 설정을 확인해 주세요.',
        ),
      ],
      catalogDetection: CharacterBuildCatalogDetection(
        catalogVersion: '1',
        status: CharacterBuildDetectionStatus.detected,
        classId: 'bard',
        branchId: 'true_courage',
        branchDisplayName: '딜바드',
        detectedRole: CharacterBuildRole.dealer,
        matchedTier1Node: '진실된 용맹',
        matchedRelatedNodes: [],
      ),
    ),
    fetchedAt: DateTime(2026, 8, 20, 12),
  );

  @override
  Future<CharacterBuildDraft> createCharacterBuildDraft({
    required int characterId,
    required String characterName,
  }) async => _draft;

  @override
  Future<CharacterBuildSnapshot> commitCharacterBuildDraft({
    required CharacterBuildDraft draft,
    required CharacterBuildRole role,
  }) async {
    committedRoles.add(role);
    final snapshot = CharacterBuildSnapshot(
      id: 1,
      characterId: draft.characterId,
      role: role,
      rawJson: draft.rawJson,
      itemLevel: draft.profile.itemLevel,
      combatPower: draft.profile.combatPower,
      capturedAt: draft.fetchedAt,
      dataVersion: 1,
      analysis: draft.analysis,
    );
    _snapshots.add(snapshot);
    return snapshot;
  }

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => List.unmodifiable(_snapshots);

  @override
  Future<CharacterBuildSnapshot> refreshCharacterBuildSnapshot({
    required int characterId,
    required String characterName,
    required CharacterBuildRole role,
  }) => throw UnimplementedError();

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
