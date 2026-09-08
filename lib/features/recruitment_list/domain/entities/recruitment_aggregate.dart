import '../state/recruitment_state_machine.dart';
import '../policies/approval_policy.dart';
import 'party_recruitment.dart';
import 'recruitment_application.dart';

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
    this.currentCycleKey = '',
    this.targetCycleKey = '',
    this.status = 'active',
    this.currentCycleStatus = 'active',
    this.continueTogether = false,
    this.cycleEndsAt,
    this.leaderCharacterName,
    this.leaderClassName,
    this.membersPerParty = 4,
    this.partyCount = 1,
    this.supportsPerParty = 1,
    this.dealerCount = 0,
    this.supportCount = 0,
    this.approvalMode = ApprovalMode.leaderOnly,
    this.visibility = 'public',
    this.groupId,
    this.memberPlayerIds,
  });

  factory PublicRecruitmentSummary.fromAggregate(
    RecruitmentAggregate aggregate,
  ) {
    RecruitmentPartyMember? leader;
    for (final member in aggregate.state.members) {
      if (member.userId == aggregate.state.leaderUserId) {
        leader = member;
        break;
      }
    }
    return PublicRecruitmentSummary(
      id: aggregate.id,
      title: aggregate.title,
      metadata: aggregate.metadata,
      leaderUserId: aggregate.state.leaderUserId,
      leaderCharacterName: leader?.characterId,
      leaderClassName: leader?.className,
      memberCount: aggregate.state.members.length,
      maxMemberCount: aggregate.state.compositionPolicy.rules.totalMembers,
      membersPerParty: aggregate.state.compositionPolicy.rules.membersPerParty,
      partyCount: aggregate.state.compositionPolicy.rules.partyCount,
      supportsPerParty:
          aggregate.state.compositionPolicy.rules.supportsPerParty,
      dealerCount: aggregate.state.members
          .where((member) => member.role == PartyRole.dealer)
          .length,
      supportCount: aggregate.state.members
          .where((member) => member.role == PartyRole.support)
          .length,
      isRecruiting: aggregate.state.isRecruiting,
      revision: aggregate.revision,
      updatedAt: aggregate.updatedAt,
      approvalMode: aggregate.state.approvalPolicy.mode,
      memberPlayerIds: {
        for (final member in aggregate.state.members) member.userId,
      },
    );
  }

  final String id;
  final String title;
  final String leaderUserId;
  final String? leaderCharacterName;
  final String? leaderClassName;
  final RecruitmentMetadata metadata;
  final int memberCount;
  final int maxMemberCount;
  final int membersPerParty;
  final int partyCount;
  final int supportsPerParty;
  final int dealerCount;
  final int supportCount;

  int get maxSupportCount => partyCount * supportsPerParty;
  int get maxDealerCount => maxMemberCount - maxSupportCount;
  final bool isRecruiting;
  final int revision;
  final DateTime updatedAt;
  final String currentCycleKey;

  /// 신청·가입 Rules가 요구하는 주차. 없으면 [currentCycleKey]와 동일하다.
  final String targetCycleKey;

  /// Firestore `status` (active / completed / incompleteEnded / disbanded).
  final String status;

  /// Firestore `currentCycleStatus`.
  final String currentCycleStatus;
  final bool continueTogether;
  final DateTime? cycleEndsAt;
  final ApprovalMode approvalMode;

  /// `public` 또는 `group`. 일반 레이드는 public.
  final String visibility;

  /// 그룹 레이드의 연결 그룹. 일반 레이드는 null.
  final String? groupId;

  /// 필터 매칭용 확정 참가 Player ID. 카드 UI에는 올리지 않는다.
  /// null이면 문서에 필드가 없어 그룹원 조건을 확인할 수 없다.
  final Set<String>? memberPlayerIds;

  bool get isGroupLinked => groupId != null && groupId!.isNotEmpty;
  bool get isGroupOnly => isGroupLinked && visibility == 'group';

  bool get isActiveRecruitment => status == 'active';
  bool get isCycleActive => currentCycleStatus == 'active';
  bool get isCycleCompleted => currentCycleStatus == 'completed';
  bool get isOneShotCompleted =>
      status == 'completed' && currentCycleStatus == 'completed';

  /// 이번 회차 레이드를 끝냈고 아직 해산되지 않은 상태(1회성 해산 대기·반복방 다음주 대기).
  bool get showsThisWeekRaidCompleteMark =>
      isCycleCompleted && status != 'disbanded';
}
