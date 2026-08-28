import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/character_summary_sync_result.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/character_summary_sync_gateway.dart';
import 'package:lost_party/features/account/domain/services/character_summary_sync_service.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_exception.dart';

void main() {
  late _FakeAccountRepository repository;
  late _FakeSyncGateway gateway;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 8, 25, 12, 0, 0);
    repository = _FakeAccountRepository(
      accounts: [_activeAccount(now.subtract(const Duration(minutes: 2)))],
    );
    gateway = _FakeSyncGateway();
  });

  CharacterSummarySyncService buildService({
    List<CharacterSummary>? summaries,
    LostArkApiException? error,
  }) {
    return CharacterSummarySyncService(
      accountRepository: repository,
      fetchSummaries: (name) async {
        if (error != null) throw error;
        return summaries ??
            const [
              CharacterSummary(
                serverName: '루페온',
                characterName: '이슈아이',
                characterLevel: 70,
                characterClassName: '바드',
                itemLevel: 1766.66,
              ),
            ];
      },
      syncGateway: gateway,
      clock: () => now,
      autoSyncInterval: const Duration(minutes: 1),
    );
  }

  test('skips auto sync within one minute', () async {
    repository = _FakeAccountRepository(
      accounts: [
        _activeAccount(now.subtract(const Duration(seconds: 30))),
      ],
    );
    final service = buildService();

    final report = await service.syncAccounts(force: false);

    expect(
      report.results.single.status,
      CharacterSummarySyncStatus.skippedThrottle,
    );
    expect(repository.applyCalls, 0);
    expect(gateway.calls, 0);
  });

  test('updates local and server when summary changes', () async {
    final service = buildService();

    final report = await service.syncAccounts(force: false);

    expect(
      report.results.single.status,
      CharacterSummarySyncStatus.localAndServerUpdated,
    );
    expect(repository.applyCalls, 1);
    expect(gateway.calls, 1);
    expect(gateway.lastPatches.single.serverCharacterId, 'char-1');
  });

  test('force refresh ignores throttle', () async {
    repository = _FakeAccountRepository(
      accounts: [
        _activeAccount(now.subtract(const Duration(seconds: 10))),
      ],
    );
    final service = buildService();

    final report = await service.syncAccounts(force: true);

    expect(
      report.results.single.status,
      isNot(CharacterSummarySyncStatus.skippedThrottle),
    );
    expect(repository.applyCalls, 1);
  });

  test('reports server sync failure without hiding local success', () async {
    gateway.fail = true;
    final service = buildService();

    final report = await service.syncAccounts(force: true);

    expect(report.hasServerSyncFailure, isTrue);
    expect(report.results.single.updatedLocalCount, 1);
  });

  test('keeps existing data when API fails', () async {
    final service = buildService(
      error: const LostArkApiException(type: LostArkApiErrorType.network),
    );

    final report = await service.syncAccounts(force: true);

    expect(report.results.single.status, CharacterSummarySyncStatus.apiFailed);
    expect(repository.applyCalls, 0);
  });
}

LocalGameAccount _activeAccount(DateTime fetchedAt) {
  return LocalGameAccount(
    id: 1,
    label: '메인 계정',
    isMain: true,
    lookupCharacterName: '이슈아이',
    representativeCharacterId: 10,
    displayLimit: 6,
    serverGameAccountId: 'ga-1',
    serverOwnershipStatus: 'active',
    characters: [
      LocalAccountCharacter(
        id: 10,
        serverName: '루페온',
        characterName: '이슈아이',
        characterLevel: 70,
        characterClassName: '바드',
        itemLevel: 1700,
        combatPower: 1,
        isVisible: true,
        displayOrder: 0,
        serverCharacterId: 'char-1',
        lastSummaryFetchedAt: fetchedAt,
      ),
    ],
  );
}

class _FakeSyncGateway implements CharacterSummarySyncGateway {
  bool fail = false;
  int calls = 0;
  List<CharacterSummaryServerPatch> lastPatches = const [];

  @override
  Future<void> updateSummaries(List<CharacterSummaryServerPatch> patches) async {
    calls += 1;
    lastPatches = patches;
    if (fail) {
      throw StateError('server failed');
    }
  }
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({required this.accounts});

  List<LocalGameAccount> accounts;
  int applyCalls = 0;

  @override
  Future<List<LocalGameAccount>> loadAccounts() async => accounts;

  @override
  Future<RosterSummaryApplyResult> applyRosterSummarySync({
    required int accountId,
    required String lookupCharacterName,
    required List<CharacterSummary> summaries,
    required DateTime fetchedAt,
  }) async {
    applyCalls += 1;
    final account = accounts.firstWhere((item) => item.id == accountId);
    final patches = <CharacterSummaryServerPatch>[];
    for (final summary in summaries) {
      for (final character in account.characters) {
        if (character.characterName != summary.characterName) continue;
        if (character.serverCharacterId == null) continue;
        if (character.itemLevel == summary.itemLevel &&
            character.characterLevel == summary.characterLevel) {
          continue;
        }
        patches.add(
          CharacterSummaryServerPatch(
            serverCharacterId: character.serverCharacterId!,
            characterName: summary.characterName,
            characterLevel: summary.characterLevel,
            itemAvgLevel: summary.itemLevel?.toString() ?? '',
            fetchedAt: fetchedAt,
          ),
        );
      }
    }
    return RosterSummaryApplyResult(
      updatedLocalCount: patches.isEmpty ? 0 : 1,
      serverPatches: account.hasActiveOwnership ? patches : const [],
    );
  }

  @override
  Future<List<CharacterSummary>> fetchCharacters(String characterName) =>
      throw UnimplementedError();

  @override
  Future<CharacterProfile> fetchCharacterProfile(String characterName) =>
      throw UnimplementedError();

  @override
  Future<LocalGameAccount?> loadMainAccount() async =>
      accounts.where((account) => account.isMain).firstOrNull;

  @override
  Future<void> saveCharacterBuildSnapshot({
    required int characterId,
    required CharacterBuildRole role,
    required String rawJson,
    required double? itemLevel,
    required double? combatPower,
    required DateTime capturedAt,
  }) => throw UnimplementedError();

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) => throw UnimplementedError();

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
  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  }) => throw UnimplementedError();

  @override
  Future<void> markRepresentativeReconciled({
    required int accountId,
    required String serverCharacterId,
  }) => throw UnimplementedError();

  @override
  Future<void> updateDisplayLimit({
    required int accountId,
    required int displayLimit,
  }) => throw UnimplementedError();

  @override
  Future<void> updateCharacterVisibility({
    required int accountId,
    required int characterId,
    required bool isVisible,
  }) => throw UnimplementedError();

  @override
  Future<void> updateCharacterDisplayOrder({
    required int accountId,
    required List<int> characterIds,
  }) => throw UnimplementedError();

  @override
  Future<void> setPreferredCharacterRole({
    required int characterId,
    required CharacterBuildRole role,
  }) => throw UnimplementedError();
}
