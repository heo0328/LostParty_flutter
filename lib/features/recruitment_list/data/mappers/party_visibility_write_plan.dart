import '../../domain/entities/party_create_command.dart';

class PartyVisibilityWritePlan {
  const PartyVisibilityWritePlan({required this.recruitmentPatch});

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
    return PartyVisibilityWritePlan(recruitmentPatch: patch);
  }

  final Map<String, Object?> recruitmentPatch;
}
