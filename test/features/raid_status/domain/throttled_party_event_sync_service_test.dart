import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/domain/services/party_event_sync_service.dart';
import 'package:lost_party/features/raid_status/domain/services/throttled_party_event_sync_service.dart';

void main() {
  test('동시에 들어온 갱신 요청은 서버 동기화를 한 번만 실행한다', () async {
    final delegate = _ControlledSyncService();
    final service = ThrottledPartyEventSyncService(delegate: delegate);

    final first = service.sync();
    final second = service.sync();

    expect(delegate.syncCount, 1);
    delegate.complete(const PartyEventSyncResult.success(3));
    expect((await first).syncedCount, 3);
    expect((await second).syncedCount, 3);
  });

  test('성공 후 10초 안의 요청은 서버 동기화를 생략한다', () async {
    var now = DateTime.utc(2026, 9, 8, 6);
    final delegate = _ImmediateSyncService();
    final service = ThrottledPartyEventSyncService(
      delegate: delegate,
      clock: () => now,
    );

    await service.sync();
    now = now.add(const Duration(seconds: 9));
    await service.sync();
    expect(delegate.syncCount, 1);

    now = now.add(const Duration(seconds: 1));
    await service.sync();
    expect(delegate.syncCount, 2);
  });

  test('실패한 동기화에는 제한 시간을 적용하지 않는다', () async {
    final delegate = _ImmediateSyncService(
      result: const PartyEventSyncResult.failure(
        PartyEventSyncFailure.temporarilyUnavailable,
      ),
    );
    final service = ThrottledPartyEventSyncService(delegate: delegate);

    await service.sync();
    await service.sync();

    expect(delegate.syncCount, 2);
  });
}

class _ControlledSyncService implements PartyEventSyncService {
  final _completer = Completer<PartyEventSyncResult>();
  var syncCount = 0;

  @override
  Future<PartyEventSyncResult> sync() {
    syncCount++;
    return _completer.future;
  }

  void complete(PartyEventSyncResult result) => _completer.complete(result);
}

class _ImmediateSyncService implements PartyEventSyncService {
  _ImmediateSyncService({
    this.result = const PartyEventSyncResult.success(1),
  });

  final PartyEventSyncResult result;
  var syncCount = 0;

  @override
  Future<PartyEventSyncResult> sync() async {
    syncCount++;
    return result;
  }
}
