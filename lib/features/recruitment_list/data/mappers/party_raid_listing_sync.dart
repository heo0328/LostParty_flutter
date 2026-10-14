import 'party_raid_listing_document.dart';

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
    final after = <String, Object?>{...currentRecruitment, ...recruitmentPatch};
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
      listingDocument: partyRaidListingDocument(currentRecruitment: after),
    );
  }

  final String? groupId;
  final Map<String, Object?>? listingDocument;
  final bool deleteListing;
}
