import '../policies/party_cycle_policy.dart';

typedef LazyCycleClock = DateTime Function();

enum LazyCycleReconciliationStatus { changed, noChange, failed }

enum LazyCycleReconciliationFailure {
  permissionDenied,
  temporarilyUnavailable,
  invalidData,
  unknown,
}

class LazyCycleReconciliationResult {
  const LazyCycleReconciliationResult.changed()
    : status = LazyCycleReconciliationStatus.changed,
      failure = null;

  const LazyCycleReconciliationResult.noChange()
    : status = LazyCycleReconciliationStatus.noChange,
      failure = null;

  const LazyCycleReconciliationResult.failed(this.failure)
    : status = LazyCycleReconciliationStatus.failed;

  final LazyCycleReconciliationStatus status;
  final LazyCycleReconciliationFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class LazyCycleReconciliationGateway {
  /// 구현체는 recruitmentId + 기존 currentCycleKey를 멱등 기준으로 삼고,
  /// 이미 targetCycleKey로 전환된 방은 noChange로 반환한다.
  Future<LazyCycleReconciliationResult> reconcile({
    required String recruitmentId,
    required String targetCycleKey,
  });
}

/// 화면·명령 진입점의 지연 회차 보정을 한 경로로 모은다.
/// 같은 방과 목표 회차에 대한 동시 요청은 하나의 Future를 공유한다.
class LazyCycleReconciler {
  LazyCycleReconciler({
    required LazyCycleReconciliationGateway gateway,
    PartyCyclePolicy cyclePolicy = const PartyCyclePolicy(),
    LazyCycleClock clock = DateTime.now,
  }) : _gateway = gateway,
       _cyclePolicy = cyclePolicy,
       _clock = clock;

  final LazyCycleReconciliationGateway _gateway;
  final PartyCyclePolicy _cyclePolicy;
  final LazyCycleClock _clock;
  final Map<String, Future<LazyCycleReconciliationResult>> _inFlight = {};

  Future<LazyCycleReconciliationResult> reconcile(String recruitmentId) {
    final normalizedId = recruitmentId.trim();
    if (normalizedId.isEmpty) {
      return Future.value(
        const LazyCycleReconciliationResult.failed(
          LazyCycleReconciliationFailure.invalidData,
        ),
      );
    }
    final targetCycleKey = _cyclePolicy.keyFor(_clock());
    final requestKey = '$normalizedId::$targetCycleKey';
    final running = _inFlight[requestKey];
    if (running != null) return running;

    final future = _run(normalizedId, targetCycleKey);
    _inFlight[requestKey] = future;
    future.whenComplete(() {
      if (identical(_inFlight[requestKey], future)) {
        _inFlight.remove(requestKey);
      }
    });
    return future;
  }

  Future<LazyCycleReconciliationResult> _run(
    String recruitmentId,
    String targetCycleKey,
  ) async {
    try {
      return await _gateway.reconcile(
        recruitmentId: recruitmentId,
        targetCycleKey: targetCycleKey,
      );
    } catch (_) {
      return const LazyCycleReconciliationResult.failed(
        LazyCycleReconciliationFailure.unknown,
      );
    }
  }
}
