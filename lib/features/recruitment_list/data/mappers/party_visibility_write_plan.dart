import '../../domain/entities/party_create_command.dart';

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
    final goingGroup = visibility == RecruitmentVisibility.group;
    return PartyVisibilityWritePlan(
      recruitmentPatch: patch,
      listingDocument: goingGroup
          ? {
              ...currentRecruitment,
              ...patch,
            }
          : null,
      deleteListing: !goingGroup,
    );
  }

  final Map<String, Object?> recruitmentPatch;
  final Map<String, Object?>? listingDocument;
  final bool deleteListing;
}
