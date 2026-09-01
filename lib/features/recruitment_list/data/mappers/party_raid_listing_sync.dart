import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/party_create_command.dart';

class PartyRaidListingSyncPlan {
  const PartyRaidListingSyncPlan({
    required this.groupId,
    this.listingDocument,
    this.deleteListing = false,
  });

  factory PartyRaidListingSyncPlan.afterRecruitmentChange({
    required Map<String, Object?> currentRecruitment,
    required Map<String, Object?> recruitmentPatch,
  }) {
    final after = <String, Object?>{
      ...currentRecruitment,
      ...recruitmentPatch,
    };
    final groupId = after['groupId'];
    final resolvedGroupId = groupId is String && groupId.isNotEmpty
        ? groupId
        : null;
    if (resolvedGroupId == null) {
      return const PartyRaidListingSyncPlan(groupId: null);
    }
    final wasGroup =
        currentRecruitment['visibility'] == RecruitmentVisibility.group;
    final isGroup = after['visibility'] == RecruitmentVisibility.group;
    final disbanded =
        after['status'] == 'disbanded' ||
        after['currentCycleStatus'] == 'disbanded';
    if (disbanded || (wasGroup && !isGroup)) {
      return PartyRaidListingSyncPlan(
        groupId: resolvedGroupId,
        deleteListing: true,
      );
    }
    if (!isGroup) {
      return PartyRaidListingSyncPlan(groupId: resolvedGroupId);
    }
    return PartyRaidListingSyncPlan(
      groupId: resolvedGroupId,
      listingDocument: after,
    );
  }

  final String? groupId;
  final Map<String, Object?>? listingDocument;
  final bool deleteListing;
}

class PartyRaidListingTx {
  const PartyRaidListingTx._(this.ref, this.snapshot);

  final DocumentReference<Map<String, dynamic>>? ref;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;

  static Future<PartyRaidListingTx> read({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required Object? groupId,
    required String recruitmentId,
  }) async {
    if (groupId is! String || groupId.isEmpty) {
      return const PartyRaidListingTx._(null, null);
    }
    final listingRef = firestore
        .collection('groups')
        .doc(groupId)
        .collection('raidListings')
        .doc(recruitmentId);
    return PartyRaidListingTx._(
      listingRef,
      await transaction.get(listingRef),
    );
  }

  void write({
    required Transaction transaction,
    required Map<String, Object?> currentRecruitment,
    required Map<String, Object?> recruitmentPatch,
  }) {
    final listingRef = ref;
    if (listingRef == null) return;
    final plan = PartyRaidListingSyncPlan.afterRecruitmentChange(
      currentRecruitment: currentRecruitment,
      recruitmentPatch: recruitmentPatch,
    );
    if (plan.deleteListing) {
      if (snapshot?.exists == true) {
        transaction.delete(listingRef);
      }
      return;
    }
    final document = plan.listingDocument;
    if (document != null) {
      transaction.set(listingRef, document);
    }
  }
}

Map<String, Object?> partyRecruitmentMap(Map<String, dynamic>? data) =>
    data == null ? const {} : Map<String, Object?>.from(data);
