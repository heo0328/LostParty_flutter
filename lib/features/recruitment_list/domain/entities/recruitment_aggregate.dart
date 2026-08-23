import '../state/recruitment_state_machine.dart';
import 'party_recruitment.dart';

class RecruitmentMetadata {
  const RecruitmentMetadata({
    required this.catalogVersion,
    required this.raidId,
    required this.difficultyId,
    required this.raidName,
    required this.difficultyName,
    required this.difficultyAlias,
    required this.gateCount,
    required this.minItemLevel,
    required this.minCombatPower,
    required this.experienceLevel,
    required this.maxPlayHours,
    this.raidStartAt,
  });

  final String catalogVersion;
  final String raidId;
  final String difficultyId;
  final String raidName;
  final String difficultyName;
  final String difficultyAlias;
  final int gateCount;
  final int minItemLevel;
  final int? minCombatPower;
  final ExperienceLevel? experienceLevel;
  final int? maxPlayHours;
  final DateTime? raidStartAt;
}

class RecruitmentAggregate {
  const RecruitmentAggregate({
    required this.id,
    required this.title,
    required this.metadata,
    required this.state,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final RecruitmentMetadata metadata;
  final RecruitmentState state;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecruitmentAggregate copyWith({
    String? title,
    RecruitmentMetadata? metadata,
    RecruitmentState? state,
    int? revision,
    DateTime? updatedAt,
  }) => RecruitmentAggregate(
    id: id,
    title: title ?? this.title,
    metadata: metadata ?? this.metadata,
    state: state ?? this.state,
    revision: revision ?? this.revision,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class PublicRecruitmentSummary {
  const PublicRecruitmentSummary({
    required this.id,
    required this.title,
    required this.leaderUserId,
    required this.metadata,
    required this.memberCount,
    required this.maxMemberCount,
    required this.isRecruiting,
    required this.revision,
    required this.updatedAt,
  });

  factory PublicRecruitmentSummary.fromAggregate(
    RecruitmentAggregate aggregate,
  ) => PublicRecruitmentSummary(
    id: aggregate.id,
    title: aggregate.title,
    metadata: aggregate.metadata,
    leaderUserId: aggregate.state.leaderUserId,
    memberCount: aggregate.state.members.length,
    maxMemberCount: aggregate.state.compositionPolicy.rules.totalMembers,
    isRecruiting: aggregate.state.isRecruiting,
    revision: aggregate.revision,
    updatedAt: aggregate.updatedAt,
  );

  final String id;
  final String title;
  final String leaderUserId;
  final RecruitmentMetadata metadata;
  final int memberCount;
  final int maxMemberCount;
  final bool isRecruiting;
  final int revision;
  final DateTime updatedAt;
}
