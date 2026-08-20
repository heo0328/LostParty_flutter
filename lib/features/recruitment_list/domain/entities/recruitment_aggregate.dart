import '../state/recruitment_state_machine.dart';

class RecruitmentAggregate {
  const RecruitmentAggregate({
    required this.id,
    required this.title,
    required this.state,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final RecruitmentState state;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecruitmentAggregate copyWith({
    RecruitmentState? state,
    int? revision,
    DateTime? updatedAt,
  }) => RecruitmentAggregate(
    id: id,
    title: title,
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
  final int memberCount;
  final int maxMemberCount;
  final bool isRecruiting;
  final int revision;
  final DateTime updatedAt;
}
