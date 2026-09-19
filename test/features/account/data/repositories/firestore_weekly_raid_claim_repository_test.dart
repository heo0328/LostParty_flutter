import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart';

void main() {
  group('readAccessiblePendingRecruitment', () {
    test('returns an accessible recruitment', () async {
      expect(await readAccessiblePendingRecruitment(() async => 'room'), 'room');
    });

    test('skips only a denied parent recruitment read', () async {
      expect(
        await readAccessiblePendingRecruitment<String>(() async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        }),
        isNull,
      );
    });

    test('propagates other Firebase failures', () async {
      final failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await expectLater(
        readAccessiblePendingRecruitment<String>(() async => throw failure),
        throwsA(same(failure)),
      );
    });
  });
}
