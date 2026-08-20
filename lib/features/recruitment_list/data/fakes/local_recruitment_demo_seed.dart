import '../../domain/entities/party_recruitment.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/entities/recruitment_application.dart';
import '../../domain/policies/approval_policy.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/state/recruitment_state_machine.dart';

RecruitmentAggregate createLocalRecruitmentDemoSeed(DateTime now) =>
    RecruitmentAggregate(
      id: 'demo-recruitment-1',
      title: '4막 노말 로컬 모집',
      metadata: const RecruitmentMetadata(
        catalogVersion: '2026.08.20',
        raidId: 'kazeros_act4',
        difficultyId: 'normal',
        raidName: '4막',
        difficultyName: '노말',
        difficultyAlias: '4막노말',
        gateCount: 2,
        minItemLevel: 1700,
        minCombatPower: null,
        experienceLevel: null,
        maxPlayHours: null,
      ),
      state: RecruitmentState(
        leaderUserId: 'demo-leader',
        approvalPolicy: const ApprovalPolicy.leaderOnly(),
        compositionPolicy: const PartyCompositionPolicy(
          RecruitmentPartyRules(
            partyCount: 2,
            membersPerParty: 4,
            supportsPerParty: 1,
            maxDealersPerClassPerParty: 1,
          ),
        ),
        members: const [
          RecruitmentPartyMember(
            userId: 'demo-leader',
            characterId: '로컬파티장',
            className: '블레이드',
            role: PartyRole.dealer,
            partyIndex: 0,
          ),
        ],
      ),
      revision: 0,
      createdAt: now,
      updatedAt: now,
    );
