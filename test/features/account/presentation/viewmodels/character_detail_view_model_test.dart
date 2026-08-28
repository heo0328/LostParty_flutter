import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/character_detail_view_model.dart';

void main() {
  test(
    'support class requires a role selection before creating a draft',
    () async {
      final repository = _FakeAccountRepository();
      final viewModel = CharacterDetailViewModel(
        character: _character(className: '바드'),
        accountRepository: repository,
      );

      await viewModel.initialize();
      await viewModel.requestBuildDraft();

      expect(viewModel.supportsMultipleRoles, isTrue);
      expect(viewModel.selectedRole, isNull);
      expect(repository.createDraftCallCount, 0);

      viewModel.selectRole(CharacterBuildRole.support);
      await viewModel.requestBuildDraft();

      expect(repository.createDraftCallCount, 1);
      expect(viewModel.draft, isNotNull);
      expect(viewModel.draftRole, CharacterBuildRole.support);
      expect(viewModel.snapshots, isEmpty);
    },
  );

  test('dealer class defaults to the dealer role', () {
    final viewModel = CharacterDetailViewModel(
      character: _character(className: '슬레이어'),
      accountRepository: _FakeAccountRepository(),
    );

    expect(viewModel.supportsMultipleRoles, isFalse);
    expect(viewModel.selectedRole, CharacterBuildRole.dealer);
  });

  test('두 역할 세팅이 있으면 선호 역할을 저장한다', () async {
    final repository = _FakeAccountRepository();
    final draft = repository.buildDraft();
    await repository.commitCharacterBuildDraft(
      draft: draft,
      role: CharacterBuildRole.dealer,
    );
    await repository.commitCharacterBuildDraft(
      draft: draft,
      role: CharacterBuildRole.support,
    );
    final viewModel = CharacterDetailViewModel(
      character: _character(className: '바드'),
      accountRepository: repository,
    );

    await viewModel.initialize();
    await viewModel.setPreferredRole(CharacterBuildRole.dealer);

    expect(viewModel.canSelectPreferredRole, isTrue);
    expect(viewModel.preferredRole, CharacterBuildRole.dealer);
    expect(repository.preferredRoles, [CharacterBuildRole.dealer]);
  });

  test('두 번째 역할 저장 직후 선호 역할을 비어 두지 않는다', () async {
    final repository = _FakeAccountRepository();
    await repository.commitCharacterBuildDraft(
      draft: repository.buildDraft(),
      role: CharacterBuildRole.dealer,
    );
    final viewModel = CharacterDetailViewModel(
      character: _character(className: '바드'),
      accountRepository: repository,
    );
    await viewModel.initialize();
    viewModel.selectRole(CharacterBuildRole.support);
    await viewModel.requestBuildDraft();

    final committed = await viewModel.commitDraft();

    expect(committed, isTrue);
    expect(viewModel.preferredRole, CharacterBuildRole.support);
    expect(repository.preferredRoles, [CharacterBuildRole.support]);
  });

  test('cancels a draft without committing it', () async {
    final repository = _FakeAccountRepository();
    final viewModel = CharacterDetailViewModel(
      character: _character(className: '슬레이어'),
      accountRepository: repository,
    );

    await viewModel.requestBuildDraft();
    viewModel.cancelDraft();

    expect(viewModel.draft, isNull);
    expect(repository.committedRoles, isEmpty);
  });

  test(
    'commits a detected dealer draft to the selected support role',
    () async {
      final repository = _FakeAccountRepository();
      final viewModel = CharacterDetailViewModel(
        character: _character(className: '바드'),
        accountRepository: repository,
      );
      viewModel.selectRole(CharacterBuildRole.support);
      await viewModel.requestBuildDraft();

      final committed = await viewModel.commitDraft();

      expect(committed, isTrue);
      expect(repository.committedRoles, [CharacterBuildRole.support]);
      expect(viewModel.draft, isNull);
      expect(viewModel.selectedSnapshot?.role, CharacterBuildRole.support);
    },
  );

  test('keeps the draft when commit fails', () async {
    final repository = _FakeAccountRepository()..failCommit = true;
    final viewModel = CharacterDetailViewModel(
      character: _character(className: '슬레이어'),
      accountRepository: repository,
    );
    await viewModel.requestBuildDraft();

    final committed = await viewModel.commitDraft();

    expect(committed, isFalse);
    expect(viewModel.draft, isNotNull);
    expect(viewModel.errorMessage, '세팅 데이터를 저장하지 못했습니다.');
  });

  test('prevents duplicate draft requests', () async {
    final completer = Completer<CharacterBuildDraft>();
    final repository = _FakeAccountRepository()..draftCompleter = completer;
    final viewModel = CharacterDetailViewModel(
      character: _character(className: '슬레이어'),
      accountRepository: repository,
    );

    final first = viewModel.requestBuildDraft();
    await viewModel.requestBuildDraft();
    expect(repository.createDraftCallCount, 1);
    completer.complete(repository.buildDraft());
    await first;
  });

  test('prevents duplicate draft commits', () async {
    final gate = Completer<void>();
    final repository = _FakeAccountRepository()..commitGate = gate;
    final viewModel = CharacterDetailViewModel(
      character: _character(className: '슬레이어'),
      accountRepository: repository,
    );
    await viewModel.requestBuildDraft();

    final first = viewModel.commitDraft();
    expect(await viewModel.commitDraft(), isFalse);
    expect(repository.commitCallCount, 1);
    gate.complete();
    expect(await first, isTrue);
  });
}

class _FakeAccountRepository implements AccountRepository {
  @override
  Future<void> setPreferredCharacterRole({
    required int characterId,
    required CharacterBuildRole role,
  }) async {
    preferredRoles.add(role);
  }

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

  int createDraftCallCount = 0;
  final List<CharacterBuildRole> committedRoles = [];
  final List<CharacterBuildRole> preferredRoles = [];
  final List<CharacterBuildSnapshot> _snapshots = [];
  bool failCommit = false;
  Completer<CharacterBuildDraft>? draftCompleter;
  Completer<void>? commitGate;
  int commitCallCount = 0;

  CharacterBuildDraft buildDraft() => CharacterBuildDraft(
    characterId: 1,
    rawJson: '{}',
    profile: const CharacterProfile(
      serverName: '루페온',
      characterName: '테스트캐릭터',
      characterLevel: 70,
      characterClassName: '바드',
      itemLevel: 1700,
      combatPower: 100000,
    ),
    analysis: const CharacterBuildAnalysis(
      runeCount: 8,
      gemEffects: [],
      arkGridConditions: [],
      arkGridCorePoints: [],
      notices: [],
    ),
    fetchedAt: DateTime(2026),
  );

  @override
  Future<CharacterBuildDraft> createCharacterBuildDraft({
    required int characterId,
    required String characterName,
  }) {
    createDraftCallCount++;
    return draftCompleter?.future ?? Future.value(buildDraft());
  }

  @override
  Future<CharacterBuildSnapshot> commitCharacterBuildDraft({
    required CharacterBuildDraft draft,
    required CharacterBuildRole role,
  }) async {
    commitCallCount++;
    await commitGate?.future;
    if (failCommit) {
      throw StateError('commit failed');
    }
    committedRoles.add(role);
    final snapshot = CharacterBuildSnapshot(
      id: committedRoles.length,
      characterId: draft.characterId,
      role: role,
      rawJson: draft.rawJson,
      itemLevel: draft.profile.itemLevel,
      combatPower: draft.profile.combatPower,
      capturedAt: draft.fetchedAt,
      dataVersion: 1,
      analysis: draft.analysis,
    );
    _snapshots.removeWhere((item) => item.role == role);
    _snapshots.add(snapshot);
    return snapshot;
  }

  @override
  Future<CharacterBuildSnapshot> refreshCharacterBuildSnapshot({
    required int characterId,
    required String characterName,
    required CharacterBuildRole role,
  }) => throw UnimplementedError();

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
  Future<void> markRepresentativeReconciled({
    required int accountId,
    required String serverCharacterId,
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
