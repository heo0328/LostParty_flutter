import '../../domain/entities/party_create_command.dart';
import 'party_raid_listing_sync.dart';

class PartyVisibilityWritePlan {
  const PartyVisibilityWritePlan({
    required this.recruitmentPatch,
    this.listingDocument,
    this.deleteListing = false,
  });

  factory PartyVisibilityWritePlan.change({
    required String visibility,
    required int recruitmentRevision,
    required Object serverTimestamp,
    required Map<String, Object?> currentRecruitment,
  }) {
    if (!RecruitmentVisibility.isValid(visibility)) {
      throw ArgumentError.value(visibility, 'visibility');
    }
    final patch = <String, Object?>{
      'visibility': visibility,
      'revision': recruitmentRevision + 1,
      'updatedAt': serverTimestamp,
    };
    final listing = PartyRaidListingSyncPlan.afterRecruitmentChange(
      currentRecruitment: currentRecruitment,
      recruitmentPatch: patch,
    );
    return PartyVisibilityWritePlan(
      recruitmentPatch: patch,
      listingDocument: listing.listingDocument,
      deleteListing: listing.deleteListing,
    );
  }

  final Map<String, Object?> recruitmentPatch;
  final Map<String, Object?>? listingDocument;
  final bool deleteListing;
}
