import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/raid_status/domain/services/party_event_sync_service.dart';
import 'package:lost_party/features/raid_status/presentation/viewmodels/raid_history_view_model.dart';

void main() {
  late AccountDatabase database;

  setUp(() {
    database = AccountDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<void> writeCompletedEvent(String eventId) {
    return database.syncPartyHistoryEvent(
      eventId: eventId,
      playerId: 'player-1',
      characterId: 'character-1',
      recruitmentId: 'recruitment-1',
      raidId: 'act4',
      difficultyId: 'normal',
      cycleKey: '2026-08-19',
      serverStatus: 'completed',
      occurredAt: DateTime.utc(2026, 8, 20),
    );
  }

  test('동기화 결과를 로컬 기록으로 표시한다', () async {
    final viewModel = RaidHistoryViewModel(
      database: database,
      playerId: 'player-1',
      syncService: _RecordingSyncService(() => writeCompletedEvent('event-1')),
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();

    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.items, hasLength(1));
    expect(
      viewModel.state.items.single.serverStatus,
      RaidHistoryServerStatus.completed,
    );
  });

  test('다른 Player의 기록은 읽지 않는다', () async {
    await writeCompletedEvent('event-1');
    final viewModel = RaidHistoryViewModel(
      database: database,
      playerId: 'player-2',
      syncService: _RecordingSyncService(() async {}),
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();

    expect(viewModel.state.items, isEmpty);
    expect(viewModel.state.isEmpty, isTrue);
  });

  test('재동기화는 기록을 중복 생성하지 않고 숨김과 로컬 정정을 유지한다', () async {
    final syncService = _RecordingSyncService(
      () => writeCompletedEvent('event-1'),
    );
    final viewModel = RaidHistoryViewModel(
      database: database,
      playerId: 'player-1',
      syncService: syncService,
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();
    await database.setRaidHistoryLocalOverride('event-1', 'incomplete');
    await viewModel.syncNow();

    expect(syncService.calls, 2);
    expect(viewModel.state.items, hasLength(1));
    expect(
      viewModel.state.items.single.localOverride,
      RaidHistoryLocalOverride.incomplete,
    );
    expect(viewModel.state.items.single.isLocallyCorrected, isTrue);

    await database.setRaidHistoryVisibility('event-1', false);
    await viewModel.syncNow();

    expect(viewModel.state.items, isEmpty);
  });

  test('숨긴 기록은 기본 목록에서 빠지고 토글하면 다시 보인다', () async {
    final viewModel = RaidHistoryViewModel(
      database: database,
      playerId: 'player-1',
      syncService: _RecordingSyncService(() => writeCompletedEvent('event-1')),
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();
    await viewModel.setHidden('event-1', true);

    expect(viewModel.state.items, isEmpty);

    await viewModel.setShowHidden(true);

    expect(viewModel.state.items, hasLength(1));
    expect(viewModel.state.items.single.isHidden, isTrue);

    await viewModel.setHidden('event-1', false);
    await viewModel.setShowHidden(false);

    expect(viewModel.state.items, hasLength(1));
    expect(viewModel.state.items.single.isHidden, isFalse);
  });

  test('로컬 정정은 서버 상태를 유지한 채 표시만 바꾼다', () async {
    final viewModel = RaidHistoryViewModel(
      database: database,
      playerId: 'player-1',
      syncService: _RecordingSyncService(() => writeCompletedEvent('event-1')),
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();
    await viewModel.setLocalOverride(
      'event-1',
      RaidHistoryLocalOverride.incomplete,
    );

    expect(
      viewModel.state.items.single.serverStatus,
      RaidHistoryServerStatus.completed,
    );
    expect(
      viewModel.state.items.single.localOverride,
      RaidHistoryLocalOverride.incomplete,
    );

    await viewModel.setLocalOverride('event-1', null);

    expect(viewModel.state.items.single.isLocallyCorrected, isFalse);
  });

  test('카탈로그가 없으면 레이드 ID를 그대로 표시한다', () async {
    final viewModel = RaidHistoryViewModel(
      database: database,
      playerId: 'player-1',
      syncService: _RecordingSyncService(() => writeCompletedEvent('event-1')),
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();

    expect(viewModel.state.items.single.raidName, 'act4');
    expect(viewModel.state.items.single.difficultyName, 'normal');
  });

  test('로컬 조회가 실패해도 로딩에 갇히지 않고 실패를 표시한다', () async {
    final brokenDatabase = _BrokenDatabase();
    addTearDown(brokenDatabase.close);
    final syncService = _RecordingSyncService(() async {});
    final viewModel = RaidHistoryViewModel(
      database: brokenDatabase,
      playerId: 'player-1',
      syncService: syncService,
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();

    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.hasLoadFailure, isTrue);
    expect(viewModel.state.isSyncing, isFalse);
    expect(syncService.calls, 0);
  });

  test('동기화가 예외를 던져도 재시도가 막히지 않는다', () async {
    final syncService = _ThrowingSyncService();
    final viewModel = RaidHistoryViewModel(
      database: database,
      playerId: 'player-1',
      syncService: syncService,
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();
    expect(viewModel.state.isSyncing, isFalse);
    expect(viewModel.state.syncFailure, PartyEventSyncFailure.unknown);

    await viewModel.syncNow();
    expect(syncService.calls, 2);
  });

  test('동기화 실패를 상태로 전달하고 기존 로컬 기록은 유지한다', () async {
    await writeCompletedEvent('event-1');
    final viewModel = RaidHistoryViewModel(
      database: database,
      playerId: 'player-1',
      syncService: _FailingSyncService(),
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialize();

    expect(viewModel.state.syncFailure, PartyEventSyncFailure.permissionDenied);
    expect(viewModel.state.isSyncing, isFalse);
    expect(viewModel.state.items, hasLength(1));
  });
}

class _RecordingSyncService implements PartyEventSyncService {
  _RecordingSyncService(this._onSync);

  final Future<void> Function() _onSync;
  var calls = 0;

  @override
  Future<PartyEventSyncResult> sync() async {
    calls += 1;
    await _onSync();
    return const PartyEventSyncResult.success(1);
  }
}

class _BrokenDatabase extends AccountDatabase {
  _BrokenDatabase() : super(NativeDatabase.memory());

  @override
  Future<List<RaidHistoryEntry>> loadRaidHistory(
    String playerId, {
    bool includeHidden = false,
  }) async {
    throw StateError('로컬 기록 조회 실패');
  }
}

class _ThrowingSyncService implements PartyEventSyncService {
  var calls = 0;

  @override
  Future<PartyEventSyncResult> sync() async {
    calls += 1;
    throw StateError('sync exploded');
  }
}

class _FailingSyncService implements PartyEventSyncService {
  @override
  Future<PartyEventSyncResult> sync() async =>
      const PartyEventSyncResult.failure(
        PartyEventSyncFailure.permissionDenied,
      );
}
