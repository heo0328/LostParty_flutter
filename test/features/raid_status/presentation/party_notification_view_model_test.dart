import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/raid_status/domain/services/party_event_sync_service.dart';
import 'package:lost_party/features/raid_status/presentation/viewmodels/party_notification_view_model.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';

void main() {
  late AccountDatabase database;

  setUp(() {
    database = AccountDatabase(NativeDatabase.memory());
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
}

class _NoopSyncService implements PartyEventSyncService {
  const _NoopSyncService();

  @override
  Future<PartyEventSyncResult> sync() async =>
      const PartyEventSyncResult.success(0);
}
