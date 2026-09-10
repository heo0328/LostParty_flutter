import 'party_event_sync_service.dart';

typedef PartyEventSyncClock = DateTime Function();

/// 여러 화면 갱신 진입점을 하나로 합치고 짧은 시간의 중복 서버 조회를 막는다.
class ThrottledPartyEventSyncService implements PartyEventSyncService {
  ThrottledPartyEventSyncService({
    required PartyEventSyncService delegate,
    this.cooldown = const Duration(seconds: 10),
    PartyEventSyncClock? clock,
  }) : _delegate = delegate,
       _clock = clock ?? DateTime.now;

  final PartyEventSyncService _delegate;
  final Duration cooldown;
  final PartyEventSyncClock _clock;

  Future<PartyEventSyncResult>? _inFlight;
  DateTime? _lastSuccessfulAt;

  @override
  Future<PartyEventSyncResult> sync() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final lastSuccessfulAt = _lastSuccessfulAt;
    if (lastSuccessfulAt != null &&
        _clock().difference(lastSuccessfulAt) < cooldown) {
      return Future.value(const PartyEventSyncResult.success(0));
    }

    final future = _syncOnce();
    _inFlight = future;
    return future;
  }

  Future<PartyEventSyncResult> _syncOnce() async {
    try {
      final result = await _delegate.sync();
      if (result.isSuccess) _lastSuccessfulAt = _clock();
      return result;
    } finally {
      _inFlight = null;
    }
  }
}
