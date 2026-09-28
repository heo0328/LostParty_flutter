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
  final Map<String, Future<LazyCycleReconciliationResult>> _gatewayInFlight =
      {};
  final Set<String> _completed = {};
  final Map<String, LazyCycleReconciliationResult> _observedResults = {};
  Future<void> _observedQueue = Future.value();

  /// 명시적인 새로고침에서는 실패만 다시 허용한다. 진행 중 요청은 합친다.
  void retryObservedFailures() {
    _observedResults.removeWhere((_, result) => !result.isSuccess);
  }

  Future<LazyCycleReconciliationResult> reconcile(
    String recruitmentId, {
    int? observedRevision,
    void Function(String targetCycleKey, LazyCycleReconciliationResult result)?
    onAttemptCompleted,
  }) {
    final normalizedId = recruitmentId.trim();
    if (normalizedId.isEmpty) {
      return Future.value(
        const LazyCycleReconciliationResult.failed(
          LazyCycleReconciliationFailure.invalidData,
        ),
      );
    }
    final targetCycleKey = _cyclePolicy.keyFor(_clock());
    final cycleRequestKey = '$normalizedId::$targetCycleKey';
    final requestKey = observedRevision == null
        ? cycleRequestKey
        : '$cycleRequestKey::$observedRevision';
    final observed = _observedResults[requestKey];
    if (observed != null) return Future.value(observed);
    if (_completed.contains(requestKey)) {
      return Future.value(const LazyCycleReconciliationResult.noChange());
    }
    final running = _inFlight[requestKey];
    if (running != null) return running;

    final attempt = observedRevision == null
        ? _run(normalizedId, targetCycleKey)
        : _observedQueue.then((_) => _run(normalizedId, targetCycleKey));
    if (observedRevision != null) {
      _observedQueue = attempt.then<void>((_) {});
    }
    final future = attempt.then((result) {
      if (observedRevision != null) {
        _observedResults[requestKey] = result;
      } else if (result.isSuccess) {
        _completed.add(requestKey);
      }
      onAttemptCompleted?.call(targetCycleKey, result);
      return result;
    });
    _inFlight[requestKey] = future;
    future.whenComplete(() {
      if (identical(_inFlight[requestKey], future)) {
        _inFlight.remove(requestKey);
      }
    });
    return future;
  }

  /// 여러 화면 항목을 서로 독립적으로 보정한다. 한 방의 실패가 다른 방의
  /// 전환을 막지 않으며, 실패한 방은 다음 화면 신호에서 다시 시도된다.
  Future<List<LazyCycleReconciliationResult>> reconcileAll(
    Iterable<String> recruitmentIds,
  ) async {
    return [for (final id in recruitmentIds.toSet()) await reconcile(id)];
  }

  Future<LazyCycleReconciliationResult> _run(
    String recruitmentId,
    String targetCycleKey,
  ) {
    // 상세 진입(관찰 revision 없음)과 목록 진입도 같은 실제 요청을 공유한다.
    final key = '$recruitmentId::$targetCycleKey';
    final running = _gatewayInFlight[key];
    if (running != null) return running;
    final future = _invokeGateway(recruitmentId, targetCycleKey);
    _gatewayInFlight[key] = future;
    future.whenComplete(() {
      if (identical(_gatewayInFlight[key], future)) {
        _gatewayInFlight.remove(key);
      }
    });
    return future;
  }

  Future<LazyCycleReconciliationResult> _invokeGateway(
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
