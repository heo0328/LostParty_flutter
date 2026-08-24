import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/policies/approval_policy.dart';

class RecruitmentFormDraft {
  const RecruitmentFormDraft({
    required this.title,
    required this.raidId,
    required this.difficultyId,
    required this.experienceLevel,
    required this.minCombatPower,
    required this.approvalMode,
    required this.usesAutoTitle,
  });

  const RecruitmentFormDraft.empty()
    : title = '',
      raidId = '',
      difficultyId = '',
      experienceLevel = null,
      minCombatPower = null,
      approvalMode = ApprovalMode.leaderOnly,
      usesAutoTitle = true;

  factory RecruitmentFormDraft.fromAggregate(RecruitmentAggregate aggregate) =>
      RecruitmentFormDraft(
        title: aggregate.title,
        raidId: aggregate.metadata.raidId,
        difficultyId: aggregate.metadata.difficultyId,
        experienceLevel: aggregate.metadata.experienceLevel,
        minCombatPower: aggregate.metadata.minCombatPower,
        approvalMode: aggregate.state.approvalPolicy.mode,
        usesAutoTitle: false,
      );

  final String title;
  final String raidId;
  final String difficultyId;
  final ExperienceLevel? experienceLevel;
  final int? minCombatPower;
  final ApprovalMode approvalMode;
  final bool usesAutoTitle;

  RecruitmentFormDraft copyWith({
    String? title,
    String? raidId,
    String? difficultyId,
    Object? experienceLevel = _unset,
    Object? minCombatPower = _unset,
    ApprovalMode? approvalMode,
    bool? usesAutoTitle,
  }) => RecruitmentFormDraft(
    title: title ?? this.title,
    raidId: raidId ?? this.raidId,
    difficultyId: difficultyId ?? this.difficultyId,
    experienceLevel: identical(experienceLevel, _unset)
        ? this.experienceLevel
        : experienceLevel as ExperienceLevel?,
    minCombatPower: identical(minCombatPower, _unset)
        ? this.minCombatPower
        : minCombatPower as int?,
    approvalMode: approvalMode ?? this.approvalMode,
    usesAutoTitle: usesAutoTitle ?? this.usesAutoTitle,
  );

  static int? normalizeMinCombatPower(String value) {
    final parsed = num.tryParse(value.replaceAll(',', '').trim());
    final truncated = parsed?.toInt() ?? 0;
    return truncated > 0 ? truncated : null;
  }

  static const _unset = Object();
}
