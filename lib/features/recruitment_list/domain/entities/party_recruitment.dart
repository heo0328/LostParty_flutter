enum PartyRole {
  dealer,
  support,
}

enum RecruitmentStatusType {
  recruiting,
  closed,
  completed,
}

enum ExperienceLevel {
  tryLevel,
  clearExp,
  multiClearExp,
  semiExperienced,
  experienced,
}

class PartyRecruitment {
  final String id;
  final String title;
  final PartyRaid raid;
  final PartyLeader leader;
  final MemberSummary memberSummary;
  final RecruitmentStatus recruitmentStatus;
  final RecruitmentRequirements requirements;
  final RecruitmentSchedule schedule;

  const PartyRecruitment({
    required this.id,
    required this.title,
    required this.raid,
    required this.leader,
    required this.memberSummary,
    required this.recruitmentStatus,
    required this.requirements,
    required this.schedule,
  });
}

class PartyRaid {
  final String raidId;
  final GateProgress gateProgress;

  const PartyRaid({
    required this.raidId,
    required this.gateProgress,
  });
}

class GateProgress {
  final int startGate;
  final int endGate;

  const GateProgress({
    required this.startGate,
    required this.endGate,
  });
}

class PartyLeader {
  final String characterName;
  final String className;
  final PartyRole role;

  const PartyLeader({
    required this.characterName,
    required this.className,
    required this.role,
  });
}

class MemberSummary {
  final int currentCount;
  final int maxCount;

  const MemberSummary({
    required this.currentCount,
    required this.maxCount,
  });
}

class RecruitmentStatus {
  final RecruitmentStatusType status;
  final RecruitmentRoleSummary roles;

  const RecruitmentStatus({
    required this.status,
    required this.roles,
  });
}

class RecruitmentRoleSummary {
  final RoleSlotStatus dealer;
  final RoleSlotStatus support;

  const RecruitmentRoleSummary({
    required this.dealer,
    required this.support,
  });
}

class RoleSlotStatus {
  final int currentCount;
  final int targetCount;
  final int remainingCount;

  const RoleSlotStatus({
    required this.currentCount,
    required this.targetCount,
    required this.remainingCount,
  });
}

class RecruitmentRequirements {
  final int minCombatPower;
  final ExperienceLevel experienceLevel;

  const RecruitmentRequirements({
    required this.minCombatPower,
    required this.experienceLevel,
  });
}

class RecruitmentSchedule {
  final DateTime raidStartAt;
  final int? maxPlayHours;
  final DateTime recruitmentOpenedAt;
  final DateTime recruitmentClosedAt;

  const RecruitmentSchedule({
    required this.raidStartAt,
    required this.maxPlayHours,
    required this.recruitmentOpenedAt,
    required this.recruitmentClosedAt,
  });
}