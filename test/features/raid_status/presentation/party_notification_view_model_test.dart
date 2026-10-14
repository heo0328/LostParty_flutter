import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/raid_status/domain/services/party_event_sync_service.dart';
import 'package:lost_party/features/raid_status/presentation/viewmodels/party_notification_view_model.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';
import '../../../support/fixed_clock_account_database.dart';

void main() {
  late AccountDatabase database;

  setUp(() {
    database = FixedClockAccountDatabase();
  });

  tearDown(() async {
    await database.close();
  });

  test('로컬 receipt를 목록·unread로 읽고 열면 읽음 처리한다', () async {
    await database.syncPartyNotificationReceipt(
      eventId: 'event-1',
      playerId: 'player',
      type: PartyEventType.memberLeft.wireName,
      recruitmentId: 'party',
      characterNameSnapshot: '곰곰',
      occurredAt: DateTime.utc(2026, 8, 26, 12),
      expiresAt: DateTime.utc(2026, 9, 23),
    );
    final viewModel = PartyNotificationViewModel(
      database: database,
      playerId: 'player',
      syncService: const _NoopSyncService(),
    );

    await viewModel.load();
    expect(viewModel.state.items, hasLength(1));
    expect(viewModel.state.unreadCount, 1);
    expect(viewModel.state.items.single.message, '곰곰님이 파티에서 탈퇴했습니다.');
    expect(viewModel.state.items.single.isRead, isFalse);

    await viewModel.openItem(viewModel.state.items.single);
    expect(viewModel.state.unreadCount, 0);
    expect(viewModel.state.items.single.isRead, isTrue);
    viewModel.dispose();
  });

  test('방 단위 네 이벤트는 전체 알림 목록과 unread에서 제외한다', () async {
    for (final type in PartyEventType.values.where(
      (type) => type.isRoomAttentionEvent,
    )) {
      await database.syncPartyNotificationReceipt(
        eventId: 'event-${type.name}',
        playerId: 'player',
        type: type.wireName,
        recruitmentId: 'party',
        characterNameSnapshot: '곰곰',
        occurredAt: DateTime.utc(2026, 8, 26, 12),
        expiresAt: DateTime.utc(2026, 9, 23),
      );
    }
    final viewModel = PartyNotificationViewModel(
      database: database,
      playerId: 'player',
      syncService: const _NoopSyncService(),
    );

    await viewModel.load();

    expect(viewModel.state.items, isEmpty);
    expect(viewModel.state.unreadCount, 0);
    viewModel.dispose();
  });

  test('방 진입 읽음은 해당 방의 네 이벤트만 변경한다', () async {
    for (final entry in [
      ('room-event', 'room-a', PartyEventType.memberJoined),
      ('other-room', 'room-b', PartyEventType.memberJoined),
      ('other-type', 'room-a', PartyEventType.memberLeft),
    ]) {
      await database.syncPartyNotificationReceipt(
        eventId: entry.$1,
        playerId: 'player',
        type: entry.$3.wireName,
        recruitmentId: entry.$2,
        occurredAt: DateTime.utc(2026, 8, 26, 12),
        expiresAt: DateTime.utc(2026, 9, 23),
      );
    }

    final updated = await database.markPartyRoomNotificationsRead(
      playerId: 'player',
      recruitmentId: 'room-a',
      types: PartyEventType.values
          .where((type) => type.isRoomAttentionEvent)
          .map((type) => type.wireName)
          .toList(),
    );
    final rows = await database.loadRecentPartyNotifications('player');

    expect(updated, 1);
    expect(
      rows.singleWhere((row) => row.eventId == 'room-event').readAt,
      isNotNull,
    );
    expect(
      rows.singleWhere((row) => row.eventId == 'other-room').readAt,
      isNull,
    );
    expect(
      rows.singleWhere((row) => row.eventId == 'other-type').readAt,
      isNull,
    );
  });
}

class _NoopSyncService implements PartyEventSyncService {
  const _NoopSyncService();

  @override
  Future<PartyEventSyncResult> sync() async =>
      const PartyEventSyncResult.success(0);
}
