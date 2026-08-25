import 'package:flutter/foundation.dart';

import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../../account/data/local/account_database.dart';
import '../../domain/services/party_event_sync_service.dart';

enum RaidHistoryServerStatus { completed, incompleteEnded, completionCancelled }

enum RaidHistoryLocalOverride { completed, incomplete }

class RaidHistoryItem {
  const RaidHistoryItem({
    required this.eventId,
    required this.raidName,
    required this.difficultyName,
    required this.cycleKey,
    required this.occurredAt,
    required this.serverStatus,
    required this.isHidden,
    this.localOverride,
  });

  final String eventId;
  final String raidName;
  final String difficultyName;
  final String cycleKey;
  final DateTime occurredAt;
  final RaidHistoryServerStatus serverStatus;
  final bool isHidden;
  final RaidHistoryLocalOverride? localOverride;

  bool get isLocallyCorrected => localOverride != null;
}

class RaidHistoryViewState {
  const RaidHistoryViewState({
    this.items = const [],
    this.isLoading = true,
    this.isSyncing = false,
    this.hasLoadFailure = false,
    this.showHidden = false,
    this.syncFailure,
  });

  final List<RaidHistoryItem> items;
  final bool isLoading;
  final bool isSyncing;
  final bool hasLoadFailure;
  final bool showHidden;
  final PartyEventSyncFailure? syncFailure;

  bool get isEmpty => !isLoading && !hasLoadFailure && items.isEmpty;
}

/// 완료 기록은 서버 목록이 아니라 Player 이벤트를 반영한 로컬 기록을 단일 기준으로 읽는다.
class RaidHistoryViewModel extends ChangeNotifier {
  RaidHistoryViewModel({
    required AccountDatabase database,
    required String playerId,
    required PartyEventSyncService syncService,
    RaidCatalogRepository? catalogRepository,
  }) : _database = database,
       _playerId = playerId,
       _syncService = syncService,
       _catalogRepository = catalogRepository;

  final AccountDatabase _database;
  final String _playerId;
  final PartyEventSyncService _syncService;
  final RaidCatalogRepository? _catalogRepository;

  RaidHistoryViewState _state = const RaidHistoryViewState();
  var _disposed = false;
  var _raidNames = const <String, String>{};
  var _difficultyNames = const <String, String>{};

  RaidHistoryViewState get state => _state;

  /// 로컬 기록을 먼저 보여준 뒤 서버 이벤트를 반영한다.
  /// 로컬 DB 자체가 열리지 않으면 동기화도 같은 경로를 쓰므로 생략한다.
  Future<void> initialize() async {
    await _loadCatalogNames();
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
    _emit(_state.copyWith(isSyncing: true));

    final result = await _runSync();
    if (_disposed) return;

    await _readLocalHistory(isSyncing: false, syncFailure: result.failure);
  }

  Future<void> setShowHidden(bool showHidden) async {
    if (_state.showHidden == showHidden) return;
    _emit(_state.copyWith(showHidden: showHidden));
    await load();
  }

  /// 숨김은 서버에 전송하지 않고 이 기기의 표시 여부만 바꾼다.
  Future<void> setHidden(String eventId, bool hidden) async {
    await _write(
      () => _database.setRaidHistoryVisibility(eventId, !hidden),
      '완료 기록 숨김 변경 실패',
    );
  }

  /// 서버 상태를 덮어쓰지 않고 사용자의 정정만 로컬에 남긴다.
  Future<void> setLocalOverride(
    String eventId,
    RaidHistoryLocalOverride? override,
  ) async {
    await _write(
      () => _database.setRaidHistoryLocalOverride(eventId, switch (override) {
        RaidHistoryLocalOverride.completed => 'completed',
        RaidHistoryLocalOverride.incomplete => 'incomplete',
        null => null,
      }),
      '완료 기록 정정 실패',
    );
  }

  Future<void> _write(Future<void> Function() action, String failureLabel) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('$failureLabel: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (_disposed) return;
    await load();
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

  /// 카탈로그를 읽지 못해도 기록 자체는 ID로 표시할 수 있어야 한다.
  Future<void> _loadCatalogNames() async {
    final repository = _catalogRepository;
    if (repository == null) return;
    try {
      final catalog = await repository.loadCatalog();
      final raidNames = <String, String>{};
      final difficultyNames = <String, String>{};
      for (final raid in catalog.raids) {
        raidNames[raid.raidId] = raid.displayName;
        for (final difficulty in raid.difficulties) {
          difficultyNames['${raid.raidId}|${difficulty.difficultyId}'] =
              difficulty.name;
        }
      }
      _raidNames = raidNames;
      _difficultyNames = difficultyNames;
    } catch (error, stackTrace) {
      debugPrint('레이드 카탈로그 조회 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// 로컬 조회가 실패해도 화면이 로딩에 갇히지 않도록 항상 상태를 확정한다.
  Future<void> _readLocalHistory({
    required bool isSyncing,
    PartyEventSyncFailure? syncFailure,
  }) async {
    try {
      final entries = await _database.loadRaidHistory(
        _playerId,
        includeHidden: _state.showHidden,
      );
      _emit(
        RaidHistoryViewState(
          items: entries.map(_toItem).nonNulls.toList(growable: false),
          isLoading: false,
          isSyncing: isSyncing,
          showHidden: _state.showHidden,
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
          showHidden: _state.showHidden,
          syncFailure: syncFailure ?? _state.syncFailure,
        ),
      );
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
      raidName: _raidNames[entry.raidId] ?? entry.raidId,
      difficultyName:
          _difficultyNames['${entry.raidId}|${entry.difficultyId}'] ??
          entry.difficultyId,
      cycleKey: entry.cycleKey,
      occurredAt: entry.occurredAt,
      serverStatus: serverStatus,
      isHidden: entry.visibility == 'hidden',
      localOverride: switch (entry.localStatusOverride) {
        'completed' => RaidHistoryLocalOverride.completed,
        'incomplete' => RaidHistoryLocalOverride.incomplete,
        _ => null,
      },
    );
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

extension on RaidHistoryViewState {
  RaidHistoryViewState copyWith({bool? isSyncing, bool? showHidden}) =>
      RaidHistoryViewState(
        items: items,
        isLoading: isLoading,
        isSyncing: isSyncing ?? this.isSyncing,
        hasLoadFailure: hasLoadFailure,
        showHidden: showHidden ?? this.showHidden,
        syncFailure: syncFailure,
      );
}
