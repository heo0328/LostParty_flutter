import '../../domain/entities/party_recruitment.dart';

class LocalRecruitmentListDataSource {
  Future<List<PartyRecruitment>> fetchRecruitments() async {
    return [
      PartyRecruitment(
        id: 'recruitment_001',
        title: '4막 노말 딜러 구해요',
        raid: const PartyRaid(
          catalogVersion: '2026.08.20',
          raidId: 'kazeros_act4',
          difficultyId: 'normal',
          raidName: '4막',
          difficultyName: '노말',
          difficultyAlias: '4막노말',
          gateProgress: GateProgress(startGate: 1, endGate: 2),
        ),
        leader: const PartyLeader(
          characterName: '세인트바드',
          className: '바드',
          role: PartyRole.support,
        ),
        memberSummary: const MemberSummary(currentCount: 6, maxCount: 8),
        recruitmentStatus: const RecruitmentStatus(
          status: RecruitmentStatusType.recruiting,
          roles: RecruitmentRoleSummary(
            dealer: RoleSlotStatus(
              currentCount: 4,
              targetCount: 6,
              remainingCount: 2,
            ),
            support: RoleSlotStatus(
              currentCount: 2,
              targetCount: 2,
              remainingCount: 0,
            ),
          ),
        ),
        requirements: const RecruitmentRequirements(
          minCombatPower: 250000,
          experienceLevel: ExperienceLevel.clearExp,
        ),
        schedule: RecruitmentSchedule(
          raidStartAt: DateTime.now().add(const Duration(hours: 2)),
          maxPlayHours: 3,
          recruitmentOpenedAt: DateTime.now().subtract(
            const Duration(hours: 5),
          ),
          recruitmentClosedAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
      PartyRecruitment(
        id: 'recruitment_002',
        title: '종막 하드 서폿 1분',
        raid: const PartyRaid(
          catalogVersion: '2026.08.20',
          raidId: 'kazeros_finale',
          difficultyId: 'hard',
          raidName: '종막',
          difficultyName: '하드',
          difficultyAlias: '카제하드',
          gateProgress: GateProgress(startGate: 1, endGate: 2),
        ),
        leader: const PartyLeader(
          characterName: '버스트킹',
          className: '버서커',
          role: PartyRole.dealer,
        ),
        memberSummary: const MemberSummary(currentCount: 7, maxCount: 8),
        recruitmentStatus: const RecruitmentStatus(
          status: RecruitmentStatusType.recruiting,
          roles: RecruitmentRoleSummary(
            dealer: RoleSlotStatus(
              currentCount: 6,
              targetCount: 6,
              remainingCount: 0,
            ),
            support: RoleSlotStatus(
              currentCount: 1,
              targetCount: 2,
              remainingCount: 1,
            ),
          ),
        ),
        requirements: const RecruitmentRequirements(
          minCombatPower: 280000,
          experienceLevel: ExperienceLevel.multiClearExp,
        ),
        schedule: RecruitmentSchedule(
          raidStartAt: DateTime.now().add(const Duration(hours: 4)),
          maxPlayHours: 2,
          recruitmentOpenedAt: DateTime.now().subtract(
            const Duration(hours: 2),
          ),
          recruitmentClosedAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      ),
      PartyRecruitment(
        id: 'recruitment_003',
        title: '세르카 노말 트라이팟',
        raid: const PartyRaid(
          catalogVersion: '2026.08.20',
          raidId: 'serca',
          difficultyId: 'normal',
          raidName: '세르카',
          difficultyName: '노말',
          difficultyAlias: '노르카',
          gateProgress: GateProgress(startGate: 1, endGate: 2),
        ),
        leader: const PartyLeader(
          characterName: '초보소서',
          className: '소서리스',
          role: PartyRole.dealer,
        ),
        memberSummary: const MemberSummary(currentCount: 3, maxCount: 4),
        recruitmentStatus: const RecruitmentStatus(
          status: RecruitmentStatusType.recruiting,
          roles: RecruitmentRoleSummary(
            dealer: RoleSlotStatus(
              currentCount: 3,
              targetCount: 3,
              remainingCount: 1,
            ),
            support: RoleSlotStatus(
              currentCount: 1,
              targetCount: 1,
              remainingCount: 0,
            ),
          ),
        ),
        requirements: const RecruitmentRequirements(
          minCombatPower: 210000,
          experienceLevel: ExperienceLevel.tryLevel,
        ),
        schedule: RecruitmentSchedule(
          raidStartAt: DateTime.now().add(const Duration(days: 1)),
          maxPlayHours: null,
          recruitmentOpenedAt: DateTime.now().subtract(
            const Duration(hours: 1),
          ),
          recruitmentClosedAt: DateTime.now().add(const Duration(hours: 10)),
        ),
      ),
      PartyRecruitment(
        id: 'recruitment_004',
        title: '나르카 숙련 딜러 모집',
        raid: const PartyRaid(
          catalogVersion: '2026.08.20',
          raidId: 'serca',
          difficultyId: 'nightmare',
          raidName: '세르카',
          difficultyName: '나이트메어',
          difficultyAlias: '나르카',
          gateProgress: GateProgress(startGate: 1, endGate: 2),
        ),
        leader: const PartyLeader(
          characterName: '신의홀리',
          className: '홀리나이트',
          role: PartyRole.support,
        ),
        memberSummary: const MemberSummary(currentCount: 3, maxCount: 4),
        recruitmentStatus: const RecruitmentStatus(
          status: RecruitmentStatusType.recruiting,
          roles: RecruitmentRoleSummary(
            dealer: RoleSlotStatus(
              currentCount: 3,
              targetCount: 3,
              remainingCount: 1,
            ),
            support: RoleSlotStatus(
              currentCount: 1,
              targetCount: 1,
              remainingCount: 0,
            ),
          ),
        ),
        requirements: const RecruitmentRequirements(
          minCombatPower: 300000,
          experienceLevel: ExperienceLevel.experienced,
        ),
        schedule: RecruitmentSchedule(
          raidStartAt: DateTime.now().add(const Duration(hours: 8)),
          maxPlayHours: 3,
          recruitmentOpenedAt: DateTime.now().subtract(
            const Duration(hours: 6),
          ),
          recruitmentClosedAt: DateTime.now().add(const Duration(hours: 3)),
        ),
      ),
      PartyRecruitment(
        id: 'recruitment_005',
        title: '지평의 성당 3단계 세미숙련',
        raid: const PartyRaid(
          catalogVersion: '2026.08.20',
          raidId: 'horizon_cathedral',
          difficultyId: 'stage3',
          raidName: '지평의 성당',
          difficultyName: '3단계',
          difficultyAlias: '지평3단',
          gateProgress: GateProgress(startGate: 1, endGate: 2),
        ),
        leader: const PartyLeader(
          characterName: '달빛블레이드',
          className: '블레이드',
          role: PartyRole.dealer,
        ),
        memberSummary: const MemberSummary(currentCount: 4, maxCount: 4),
        recruitmentStatus: const RecruitmentStatus(
          status: RecruitmentStatusType.closed,
          roles: RecruitmentRoleSummary(
            dealer: RoleSlotStatus(
              currentCount: 3,
              targetCount: 3,
              remainingCount: 0,
            ),
            support: RoleSlotStatus(
              currentCount: 1,
              targetCount: 1,
              remainingCount: 0,
            ),
          ),
        ),
        requirements: const RecruitmentRequirements(
          minCombatPower: 190000,
          experienceLevel: ExperienceLevel.semiExperienced,
        ),
        schedule: RecruitmentSchedule(
          raidStartAt: DateTime.now().add(const Duration(minutes: 30)),
          maxPlayHours: 2,
          recruitmentOpenedAt: DateTime.now().subtract(
            const Duration(hours: 8),
          ),
          recruitmentClosedAt: DateTime.now().subtract(
            const Duration(minutes: 10),
          ),
        ),
      ),
      PartyRecruitment(
        id: 'recruitment_006',
        title: '벨가르딘 하드 빠르게 갑니다',
        raid: const PartyRaid(
          catalogVersion: '2026.08.20',
          raidId: 'belgardin',
          difficultyId: 'hard',
          raidName: '벨가르딘',
          difficultyName: '하드',
          difficultyAlias: '하르딘',
          gateProgress: GateProgress(startGate: 1, endGate: 2),
        ),
        leader: const PartyLeader(
          characterName: '천상의도화가',
          className: '도화가',
          role: PartyRole.support,
        ),
        memberSummary: const MemberSummary(currentCount: 8, maxCount: 8),
        recruitmentStatus: const RecruitmentStatus(
          status: RecruitmentStatusType.completed,
          roles: RecruitmentRoleSummary(
            dealer: RoleSlotStatus(
              currentCount: 6,
              targetCount: 6,
              remainingCount: 0,
            ),
            support: RoleSlotStatus(
              currentCount: 2,
              targetCount: 2,
              remainingCount: 0,
            ),
          ),
        ),
        requirements: const RecruitmentRequirements(
          minCombatPower: 240000,
          experienceLevel: ExperienceLevel.clearExp,
        ),
        schedule: RecruitmentSchedule(
          raidStartAt: DateTime.now().subtract(const Duration(hours: 3)),
          maxPlayHours: 2,
          recruitmentOpenedAt: DateTime.now().subtract(
            const Duration(hours: 7),
          ),
          recruitmentClosedAt: DateTime.now().subtract(
            const Duration(hours: 4),
          ),
        ),
      ),
    ];
  }
}
