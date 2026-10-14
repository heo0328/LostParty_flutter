import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/repositories/completed_cleanup_journal.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/completed_ownership_cleanup.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_event_mapper.dart';
import 'package:lost_party/features/raid_status/presentation/party_notification_message.dart';

class _FailingJournal extends CompletedCleanupJournal {
  @override
  Future<void> save(CompletedOwnershipCleanup request) async {
    throw StateError('storage unavailable');
  }
}

CompletedOwnershipCleanup request({
  String actor = 'old',
  String event = 'event',
  CompletedCleanupKind kind = CompletedCleanupKind.disband,
}) => CompletedOwnershipCleanup(
  roomId: 'room',
  actorId: actor,
  targetId: actor,
  characterId: 'character',
  revision: 5,
  targetIndex: 0,
  actorIndex: 0,
  observedRevision: 3,
  memberUpdatedAt: DateTime.fromMicrosecondsSinceEpoch(
    12345987654,
    isUtc: true,
  ),
  eventId: event,
  kind: kind,
  successorIndex: 1,
  successorId: 'next',
  successorName: '후임',
  successorClass: '클래스',
  successorUpdatedAt: DateTime.fromMicrosecondsSinceEpoch(
    98765123456,
    isUtc: true,
  ),
  leaderIndex: 0,
  observedLeaderRevision: 4,
  targetName: '기존 캐릭터',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy journal envelopes are rejected and never replayed', () async {
    final oldEnvelope =
        jsonDecode(CompletedCleanupJournal.encode(request()))
            as Map<String, dynamic>;
    oldEnvelope['version'] = 1;
    expect(
      () => CompletedCleanupJournal.decode(jsonEncode(oldEnvelope)),
      throwsFormatException,
    );
    FlutterSecureStorage.setMockInitialValues({
      'completed_cleanup_v1/old/event': jsonEncode(oldEnvelope),
    });
    expect(await const CompletedCleanupJournal().pending('old'), isEmpty);
    expect(
      await const FlutterSecureStorage().read(
        key: 'completed_cleanup_v1/old/event',
      ),
      isNotNull,
    );
  });
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'cleanup receipts notify their audience without entering completion history',
    () {
      final mapper = PartyEventMapper(toDateTime: (value) => value as DateTime);
      for (final kind in CompletedCleanupKind.values) {
        final r = request(kind: kind);
        final event = r.event({
          'memberPlayerIds': ['old', 'next'],
          'leaderPlayerId': 'old',
          'partySlots': [{}, {}],
        }, DateTime.utc(2026));
        final mapped = mapper.mapShared(
          event,
          recipientPlayerId: 'old',
          documentId: r.eventId,
        )!;
        expect(mapped.knownType, isNotNull);
        expect(mapped.isRaidHistoryEvent, isFalse);
        expect(mapped.knownType!.isNotificationCandidate, isTrue);
        expect(
          PartyNotificationMessage.routeFor(
            type: mapped.type,
            recruitmentId: 'room',
          ),
          '/raid-status',
        );
        expect(mapper.mapShared(event, recipientPlayerId: 'stranger'), isNull);
      }
    },
  );

  test(
    'restart restores exact observations and isolates players and events',
    () async {
      const first = CompletedCleanupJournal();
      final original = request(kind: CompletedCleanupKind.leader);
      await first.save(original);
      await first.save(request(actor: 'other'));
      await first.save(request(event: 'second'));
      final restored = await const CompletedCleanupJournal().pending('old');
      expect(restored, hasLength(2));
      final r = restored.singleWhere((r) => r.eventId == 'event');
      expect(
        CompletedCleanupJournal.encode(r),
        CompletedCleanupJournal.encode(original),
      );
      expect(
        r.memberUpdatedAt,
        DateTime.fromMicrosecondsSinceEpoch(12345987654, isUtc: true),
      );
      await first.remove(r);
      expect((await first.pending('old')).single.eventId, 'second');
      expect((await first.pending('other')).single.actorId, 'other');
    },
  );

  test(
    'local save failure prevents sending; uncertain send survives restart',
    () async {
      var sends = 0;
      await expectLater(
        _FailingJournal().run(request(), () async {
          sends++;
        }),
        throwsStateError,
      );
      expect(sends, 0);
      const journal = CompletedCleanupJournal();
      await expectLater(
        journal.run(request(), () async {
          sends++;
          throw StateError('response lost');
        }),
        throwsStateError,
      );
      expect(
        (await const CompletedCleanupJournal().pending('old')),
        hasLength(1),
      );
      await journal.run(request(), () async {
        sends++;
      });
      expect(await journal.pending('old'), isEmpty);
      expect(sends, 2);
    },
  );

  test(
    'last completed member closes room without changing retained participation',
    () {
      final r = request();
      final room = <String, dynamic>{
        'recruitmentId': 'room',
        'schemaVersion': 2,
        'revision': 5,
        'status': 'active',
        'currentCycleStatus': 'completed',
        'continueTogether': true,
        'memberCount': 1,
        'leaderPlayerId': 'old',
        'memberPlayerIds': ['old'],
        'partySlots': [
          {'playerId': 'old', 'characterId': 'character'},
        ],
      };
      final patch = r.patch(room, 100);
      expect(patch['status'], 'disbanded');
      expect(patch['commandTargets'], isEmpty);
      expect(patch.keys, isNot(contains('partySlots')));
      expect(patch.keys, isNot(contains('memberPlayerIds')));
      expect(patch.keys, isNot(contains('raidStateTargets')));
      final event = r.event(room, 100);
      expect(r.matchesReceipt(Map<String, dynamic>.from(event)), isTrue);
      for (final changed in [
        {'actorPlayerId': 'new'},
        {'commandRevision': 7},
        {'commandId': 'different'},
        {'type': 'ownershipLeaderRemoved'},
      ]) {
        expect(r.matchesReceipt({...event, ...changed}), isFalse);
      }
      for (final changed in [
        {'revision': 6},
        {'leaderPlayerId': 'new'},
        {'memberCount': 2},
        {'currentCycleStatus': 'active'},
      ]) {
        expect(() => r.patch({...room, ...changed}, 100), throwsStateError);
      }
    },
  );
}
