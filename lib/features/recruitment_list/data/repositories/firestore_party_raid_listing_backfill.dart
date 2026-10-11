import '../mappers/party_raid_listing_document.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'party_raid_listing_backfill_batch.dart';

/// 손대지 않은 그룹 전용 모집에 listing이 없으면, 현재 원본 Snapshot으로 만든다.
/// 모집 revision은 바꾸지 않는다. 부분 실패는 집계하여 호출 측에 전달한다.
class FirestorePartyRaidListingBackfill {
  const FirestorePartyRaidListingBackfill({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<void> backfillOwnGroupListings({required String playerId}) async {
    if (playerId.trim().isEmpty) return;
    final snapshot = await _firestore
        .collection('recruitments')
        .where('schemaVersion', isEqualTo: 2)
        .where('memberPlayerIds', arrayContains: playerId)
        .where('status', isEqualTo: 'active')
        .limit(50)
        .get();
    final groupsByRoom = <String, String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['visibility'] != 'group') continue;
      final groupId = data['groupId'];
      if (groupId is! String || groupId.isEmpty) continue;
      groupsByRoom[doc.id] = groupId;
    }
    await runPartyRaidListingBackfillBatch(
      groupsByRoom.keys.toList(),
      (roomId) => _createIfMissing(
        recruitmentId: roomId,
        groupId: groupsByRoom[roomId]!,
        playerId: playerId,
      ),
    );
  }

  Future<void> _createIfMissing({
    required String recruitmentId,
    required String groupId,
    required String playerId,
  }) async {
    final listingRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('raidListings')
        .doc(recruitmentId);
    final recruitmentRef = _firestore
        .collection('recruitments')
        .doc(recruitmentId);
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(recruitmentRef);
      final listing = await transaction.get(listingRef);
      if (listing.exists) return;
      final after = current.data();
      if (after == null) return;
      if (after['visibility'] != 'group' || after['groupId'] != groupId) {
        return;
      }
      if (after['status'] != 'active' ||
          after['currentCycleStatus'] == 'disbanded') {
        return;
      }
      final members = after['memberPlayerIds'];
      if (members is! List || !members.contains(playerId)) return;
      transaction.set(
        listingRef,
        partyRaidListingDocument(currentRecruitment: after),
      );
    });
  }
}
