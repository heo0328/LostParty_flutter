import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/repositories/ownership_record_stream.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_status_projection.dart';
import 'package:lost_party/features/account/domain/services/ownership_record_visibility.dart';

void main() {
  Map<String, dynamic> authority(int revision, {String owner = 'A'}) => {
    'ownerPlayerId': owner,
    'ownershipRevision': revision,
    'status': 'active',
    'gameAccountId': 'account',
  };
  WeeklyRaidStatusRecord record(
    int revision, {
    String character = 'char',
    WeeklyRaidStatusRecordKind kind = WeeklyRaidStatusRecordKind.activeState,
  }) => WeeklyRaidStatusRecord(
    playerId: 'A',
    characterId: character,
    raidId: 'raid',
    cycleKey: 'week',
    kind: kind,
    ownershipRevision: revision,
  );
  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test(
    'old/current mixed evidence, transfer, and reacquisition never revive old records',
    () async {
      final source = StreamController<List<WeeklyRaidStatusRecord>>();
      final docs = <String, StreamController<Map<String, dynamic>?>>{};
      final values = <List<WeeklyRaidStatusRecord>>[], errors = <Object>[];
      final subscription = watchCurrentOwnershipRecords(
        source.stream,
        (path) => docs
            .putIfAbsent(
              path,
              () => StreamController<Map<String, dynamic>?>.broadcast(),
            )
            .stream,
      ).listen(values.add, onError: errors.add);
      source.add([
        record(1, kind: WeeklyRaidStatusRecordKind.legacyClaim),
        record(3),
      ]);
      await pump();
      expect(values, isEmpty);
      docs['characters/char']!.add(authority(3));
      await pump();
      expect(values, isEmpty);
      docs['gameAccounts/account']!.add(authority(3));
      await pump();
      expect(values.last.map((r) => r.ownershipRevision), [3]);
      docs['characters/char']!.add(authority(4, owner: 'B'));
      await pump();
      expect(errors.last, isA<FormatException>());
      final count = values.length;
      docs['gameAccounts/account']!.add(authority(4, owner: 'B'));
      await pump();
      expect(values.last, isEmpty);
      expect(values.length, count + 1);
      docs['gameAccounts/account']!.add(authority(5));
      await pump();
      docs['characters/char']!.add(authority(5));
      await pump();
      expect(values.last, isEmpty);
      await subscription.cancel();
      await source.close();
      for (final doc in docs.values) {
        await doc.close();
      }
    },
  );

  test(
    'removed dependencies, errors and cancellation cannot publish stale results',
    () async {
      final source = StreamController<List<WeeklyRaidStatusRecord>>();
      final docs = <String, StreamController<Map<String, dynamic>?>>{};
      final values = <List<WeeklyRaidStatusRecord>>[], errors = <Object>[];
      final subscription = watchCurrentOwnershipRecords(
        source.stream,
        (path) => docs
            .putIfAbsent(
              path,
              () => StreamController<Map<String, dynamic>?>.broadcast(),
            )
            .stream,
      ).listen(values.add, onError: errors.add);
      source.add([record(3)]);
      await pump();
      docs['characters/char']!.add(authority(3));
      await pump();
      source.add([record(3, character: 'new')]);
      await pump();
      docs['gameAccounts/account']!.add(authority(3));
      docs['characters/char']!.add(authority(3));
      await pump();
      expect(values, isEmpty);
      docs['characters/new']!.add(authority(3));
      await pump();
      docs['gameAccounts/account']!.add(authority(3));
      await pump();
      expect(values.last.single.characterId, 'new');
      source.addError(StateError('read failed'));
      await pump();
      final count = values.length;
      docs['gameAccounts/account']!.add(authority(3));
      await pump();
      expect(values.length, count);
      expect(errors, isNotEmpty);
      await subscription.cancel();
      docs['characters/new']!.add(authority(3));
      await pump();
      expect(values.length, count);
      expect(docs.values.every((d) => !d.hasListener), isTrue);
      await source.close();
      for (final doc in docs.values) {
        await doc.close();
      }
    },
  );

  test(
    'missing, future and same-generation foreign owner are unknown, not old',
    () {
      for (final pair in [
        (null, authority(3), 1),
        (authority(3), authority(4), 1),
        (authority(3), authority(3), 4),
        (authority(3, owner: 'B'), authority(3, owner: 'B'), 3),
      ]) {
        expect(
          () => isCurrentOwnershipRecord(
            playerId: 'A',
            revision: pair.$3,
            character: pair.$1,
            account: pair.$2,
          ),
          throwsFormatException,
        );
      }
      final legacy = authority(0)..remove('ownershipRevision');
      expect(
        isCurrentOwnershipRecord(
          playerId: 'A',
          revision: 0,
          character: legacy,
          account: legacy,
        ),
        isTrue,
      );
    },
  );
}
