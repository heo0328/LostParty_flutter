import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';

void main() {
  late AccountDatabase database;

  setUp(() {
    database = AccountDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('알림 receipt는 멱등 sync되며 readAt을 보존한다', () async {
    final occurredAt = DateTime.utc(2026, 8, 26, 12);
    final expiresAt = DateTime.utc(2026, 9, 23, 12);
    await database.syncPartyNotificationReceipt(
      eventId: 'party_applicant_1_applicationSubmitted',
      playerId: 'leader',
      type: PartyEventType.applicationSubmitted.wireName,
      recruitmentId: 'party',
      characterNameSnapshot: '곰곰',
      occurredAt: occurredAt,
      expiresAt: expiresAt,
      syncedAt: DateTime.utc(2026, 8, 26, 12, 1),
    );
    await database.markPartyNotificationRead(
      'party_applicant_1_applicationSubmitted',
      readAt: DateTime.utc(2026, 8, 26, 12, 5),
    );
    await database.syncPartyNotificationReceipt(
      eventId: 'party_applicant_1_applicationSubmitted',
      playerId: 'leader',
      type: PartyEventType.applicationSubmitted.wireName,
      recruitmentId: 'party',
      characterNameSnapshot: '곰곰',
      occurredAt: occurredAt,
      expiresAt: expiresAt,
      syncedAt: DateTime.utc(2026, 8, 26, 12, 10),
    );

    final rows = await database.loadRecentPartyNotifications(
      'leader',
      now: DateTime.utc(2026, 8, 27),
    );
    expect(rows, hasLength(1));
    expect(rows.single.readAt!.toUtc(), DateTime.utc(2026, 8, 26, 12, 5));
    expect(rows.single.lastSyncedAt.toUtc(), DateTime.utc(2026, 8, 26, 12, 10));
    expect(rows.single.characterNameSnapshot, '곰곰');
  });

  test('unread는 만료되지 않은 미읽음 receipt만 센다', () async {
    final now = DateTime.utc(2026, 8, 27);
    await database.syncPartyNotificationReceipt(
      eventId: 'unread',
      playerId: 'player',
      type: PartyEventType.memberLeft.wireName,
      recruitmentId: 'party',
      occurredAt: DateTime.utc(2026, 8, 26, 14),
      expiresAt: DateTime.utc(2026, 9, 23),
    );
    await database.syncPartyNotificationReceipt(
      eventId: 'read',
      playerId: 'player',
      type: PartyEventType.memberJoined.wireName,
      recruitmentId: 'party',
      occurredAt: DateTime.utc(2026, 8, 26, 12),
      expiresAt: DateTime.utc(2026, 9, 23),
    );
    await database.markPartyNotificationRead('read');
    await database.syncPartyNotificationReceipt(
      eventId: 'expired',
      playerId: 'player',
      type: PartyEventType.partyDisbanded.wireName,
      recruitmentId: 'party',
      occurredAt: DateTime.utc(2026, 7, 1),
      expiresAt: DateTime.utc(2026, 7, 29),
    );

    expect(await database.countUnreadPartyNotifications('player', now: now), 1);
    final recent = await database.loadRecentPartyNotifications(
      'player',
      now: now,
    );
    expect(recent.map((row) => row.eventId), ['unread', 'read']);
  });

  test('완료 히스토리와 알림 receipt는 같은 eventId여도 분리된다', () async {
    const eventId = 'party_2026-08-26_1_partyCompleted';
    await database.syncPartyHistoryEvent(
      eventId: eventId,
      playerId: 'player',
      characterId: 'character',
      recruitmentId: 'party',
      raidId: 'serca',
      difficultyId: 'hard',
      cycleKey: '2026-08-26',
      serverStatus: 'completed',
      occurredAt: DateTime.utc(2026, 8, 26),
    );
    await database.syncPartyNotificationReceipt(
      eventId: eventId,
      playerId: 'player',
      type: PartyEventType.partyCompleted.wireName,
      recruitmentId: 'party',
      cycleKey: '2026-08-26',
      raidId: 'serca',
      difficultyId: 'hard',
      occurredAt: DateTime.utc(2026, 8, 26),
      expiresAt: DateTime.utc(2026, 9, 23),
    );

    final history = await database.loadRaidHistory('player');
    final notifications = await database.loadRecentPartyNotifications(
      'player',
      now: DateTime.utc(2026, 8, 27),
    );
    expect(history, hasLength(1));
    expect(notifications, hasLength(1));
    expect(history.single.eventId, eventId);
    expect(notifications.single.eventId, eventId);
  });
}
