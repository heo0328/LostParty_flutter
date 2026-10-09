import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/repositories/party_raid_listing_backfill_batch.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_raid_listing_backfill_failure.dart';

void main() {
  test(
    'a malformed and denied room cannot starve a later valid room',
    () async {
      final visited = <String>[];
      try {
        await runPartyRaidListingBackfillBatch(['old', 'denied', 'valid'], (
          id,
        ) async {
          visited.add(id);
          if (id == 'old') throw StateError('private payload');
          if (id == 'denied') {
            throw FirebaseException(
              plugin: 'firestore',
              code: 'permission-denied',
            );
          }
        });
        fail('partial failure must be reported');
      } on PartyRaidListingBackfillFailure catch (error) {
        expect(visited, ['old', 'denied', 'valid']);
        expect(error.completed, 1);
        expect(error.unattempted, 0);
        expect(error.failures, {
          'old': 'invalid-source',
          'denied': 'permission-denied',
        });
        expect(error.toString(), isNot(contains('private payload')));
      }
    },
  );
  for (final code in ['unauthenticated', 'unavailable', 'deadline-exceeded']) {
    test('$code stops remaining requests without retry', () async {
      final visited = <String>[];
      await expectLater(
        runPartyRaidListingBackfillBatch(['ok', 'stop', 'later'], (id) async {
          visited.add(id);
          if (id == 'stop') {
            throw FirebaseException(plugin: 'firestore', code: code);
          }
        }),
        throwsA(
          isA<PartyRaidListingBackfillFailure>()
              .having((e) => e.completed, 'completed', 1)
              .having((e) => e.unattempted, 'unattempted', 1),
        ),
      );
      expect(visited, ['ok', 'stop']);
    });
  }
  test('unexpected programming failures are not swallowed', () async {
    await expectLater(
      runPartyRaidListingBackfillBatch(['one'], (_) async {
        throw ArgumentError('unexpected');
      }),
      throwsArgumentError,
    );
  });
}
