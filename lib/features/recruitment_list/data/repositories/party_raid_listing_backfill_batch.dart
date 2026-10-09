import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/party_raid_listing_backfill_failure.dart';

Future<void> runPartyRaidListingBackfillBatch(
  List<String> roomIds,
  Future<void> Function(String roomId) repair,
) async {
  final failures = <String, String>{};
  var completed = 0;
  var attempted = 0;
  for (final roomId in roomIds) {
    attempted++;
    try {
      await repair(roomId);
      completed++;
    } on StateError {
      failures[roomId] = 'invalid-source';
    } on FormatException {
      failures[roomId] = 'invalid-source';
    } on FirebaseException catch (error) {
      failures[roomId] = error.code;
      if (!const {
        'permission-denied',
        'failed-precondition',
        'not-found',
      }.contains(error.code)) {
        break;
      }
    }
  }
  if (failures.isNotEmpty) {
    throw PartyRaidListingBackfillFailure(
      completed,
      roomIds.length - attempted,
      failures,
    );
  }
}
