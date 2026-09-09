import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/services/lazy_cycle_reconciler.dart';

void main() {
  test('같은 방과 목표 회차의 동시 접근은 gateway를 한 번만 호출한다', () async {
    final gateway = _ControlledGateway();
    final reconciler = LazyCycleReconciler(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 9, 8, 21),
    );

    final first = reconciler.reconcile('room-1');
    final second = reconciler.reconcile('room-1');

    expect(gateway.calls, [('room-1', '2026-09-09')]);
    gateway.complete(const LazyCycleReconciliationResult.changed());
    expect((await first).status, LazyCycleReconciliationStatus.changed);
    expect((await second).status, LazyCycleReconciliationStatus.changed);
  });

  test('서로 다른 방은 한 방의 보정에 묶이지 않는다', () async {
    final gateway = _ImmediateGateway();
    final reconciler = LazyCycleReconciler(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 9, 8, 21),
    );

    await Future.wait([
      reconciler.reconcile('room-1'),
      reconciler.reconcile('room-2'),
    ]);

    expect(gateway.calls, {
      ('room-1', '2026-09-09'),
      ('room-2', '2026-09-09'),
    });
  });

  test('gateway 예외는 다른 화면을 막지 않는 방 단위 실패로 변환한다', () async {
    final reconciler = LazyCycleReconciler(
      gateway: _ThrowingGateway(),
      clock: () => DateTime.utc(2026, 9, 8, 21),
    );

    final result = await reconciler.reconcile('room-1');

    expect(result.status, LazyCycleReconciliationStatus.failed);
    expect(result.failure, LazyCycleReconciliationFailure.unknown);
  });

  test('빈 방 ID는 gateway를 호출하지 않고 거절한다', () async {
    final gateway = _ImmediateGateway();
    final result = await LazyCycleReconciler(
      gateway: gateway,
    ).reconcile('  ');

    expect(result.failure, LazyCycleReconciliationFailure.invalidData);
    expect(gateway.calls, isEmpty);
  });
}

class _ControlledGateway implements LazyCycleReconciliationGateway {
  final calls = <(String, String)>[];
  final _completer = Completer<LazyCycleReconciliationResult>();

  @override
  Future<LazyCycleReconciliationResult> reconcile({
    required String recruitmentId,
    required String targetCycleKey,
  }) {
    calls.add((recruitmentId, targetCycleKey));
    return _completer.future;
  }

  void complete(LazyCycleReconciliationResult result) {
    _completer.complete(result);
  }
}

class _ImmediateGateway implements LazyCycleReconciliationGateway {
  final calls = <(String, String)>{};

  @override
  Future<LazyCycleReconciliationResult> reconcile({
    required String recruitmentId,
    required String targetCycleKey,
  }) async {
    calls.add((recruitmentId, targetCycleKey));
    return const LazyCycleReconciliationResult.noChange();
  }
}

class _ThrowingGateway implements LazyCycleReconciliationGateway {
  @override
  Future<LazyCycleReconciliationResult> reconcile({
    required String recruitmentId,
    required String targetCycleKey,
  }) => throw StateError('failed');
}
