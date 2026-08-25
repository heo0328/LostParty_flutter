import 'package:flutter/foundation.dart';

import '../../../account/data/local/account_database.dart';
import '../../domain/services/party_event_sync_service.dart';

enum RaidHistoryServerStatus { completed, incompleteEnded, completionCancelled }

enum RaidHistoryLocalOverride { completed, incomplete }

class RaidHistoryItem {
  const RaidHistoryItem({
    required this.eventId,
    required this.raidId,
    required this.difficultyId,
    required this.cycleKey,
    required this.occurredAt,
    required this.serverStatus,
    this.localOverride,
  });

  final String eventId;
  final String raidId;
  final String difficultyId;
  final String cycleKey;
  final DateTime occurredAt;
  final RaidHistoryServerStatus serverStatus;
  final RaidHistoryLocalOverride? localOverride;

  bool get isLocallyCorrected => localOverride != null;
}

class RaidHistoryViewState {
  const RaidHistoryViewState({
    this.items = const [],
    this.isLoading = true,
    this.isSyncing = false,
    this.hasLoadFailure = false,
    this.syncFailure,
  });

  final List<RaidHistoryItem> items;
  final bool isLoading;
  final bool isSyncing;
  final bool hasLoadFailure;
  final PartyEventSyncFailure? syncFailure;

  bool get isEmpty => !isLoading && !hasLoadFailure && items.isEmpty;
}

/// 완료 기록은 서버 목록이 아니라 Player 이벤트를 반영한 로컬 기록을 단일 기준으로 읽는다.
class RaidHistoryViewModel extends ChangeNotifier {
  RaidHistoryViewModel({
    required AccountDatabase database,
    required String playerId,
    required PartyEventSyncService syncService,
  }) : _database = database,
       _playerId = playerId,
       _syncService = syncService;

  final AccountDatabase _database;
  final String _playerId;
  final PartyEventSyncService _syncService;

  RaidHistoryViewState _state = const RaidHistoryViewState();
  var _disposed = false;

  RaidHistoryViewState get state => _state;

  /// 로컬 기록을 먼저 보여준 뒤 서버 이벤트를 반영한다.
  /// 로컬 DB 자체가 열리지 않으면 동기화도 같은 경로를 쓰므로 생략한다.
  Future<void> initialize() async {
    await load();
    if (_state.hasLoadFailure) return;
    await syncNow();
  }

  Future<void> load() async {
    await _readLocalHistory(isSyncing: _state.isSyncing);
  }

  /// 앱 진입과 사용자 새로고침에서 같은 이벤트를 다시 읽어도 기록이 중복되지 않는다.
  Future<void> syncNow() async {
    if (_state.isSyncing) return;
    _emit(
      RaidHistoryViewState(
        items: _state.items,
        isLoading: _state.isLoading,
        isSyncing: true,
        hasLoadFailure: _state.hasLoadFailure,
      ),
    );

    final result = await _runSync();
    if (_disposed) return;

    await _readLocalHistory(isSyncing: false, syncFailure: result.failure);
  }

  /// 동기화가 예외로 끝나도 isSyncing이 남아 재시도가 막히지 않게 한다.
  Future<PartyEventSyncResult> _runSync() async {
    try {
      return await _syncService.sync();
    } catch (error, stackTrace) {
      debugPrint('완료 기록 동기화 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const PartyEventSyncResult.failure(PartyEventSyncFailure.unknown);
    }
  }

  /// 로컬 조회가 실패해도 화면이 로딩에 갇히지 않도록 항상 상태를 확정한다.
  Future<void> _readLocalHistory({
    required bool isSyncing,
    PartyEventSyncFailure? syncFailure,
  }) async {
    try {
      final entries = await _database.loadRaidHistory(_playerId);
      _emit(
        RaidHistoryViewState(
          items: entries.map(_toItem).nonNulls.toList(growable: false),
          isLoading: false,
          isSyncing: isSyncing,
          syncFailure: syncFailure ?? _state.syncFailure,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('완료 기록 로컬 조회 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      _emit(
        RaidHistoryViewState(
          items: _state.items,
          isLoading: false,
          isSyncing: isSyncing,
          hasLoadFailure: true,
          syncFailure: syncFailure ?? _state.syncFailure,
        ),
      );
    }
  }

  void _emit(RaidHistoryViewState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

RaidHistoryItem? _toItem(RaidHistoryEntry entry) {
  final serverStatus = switch (entry.serverStatus) {
    'completed' => RaidHistoryServerStatus.completed,
    'incompleteEnded' => RaidHistoryServerStatus.incompleteEnded,
    'completionCancelled' => RaidHistoryServerStatus.completionCancelled,
    _ => null,
  };
  if (serverStatus == null) return null;

  return RaidHistoryItem(
    eventId: entry.eventId,
    raidId: entry.raidId,
    difficultyId: entry.difficultyId,
    cycleKey: entry.cycleKey,
    occurredAt: entry.occurredAt,
    serverStatus: serverStatus,
    localOverride: switch (entry.localStatusOverride) {
      'completed' => RaidHistoryLocalOverride.completed,
      'incomplete' => RaidHistoryLocalOverride.incomplete,
      _ => null,
    },
  );
}
