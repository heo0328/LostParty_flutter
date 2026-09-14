import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_atomic_application_write_plan.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_atomic_membership_write_plan.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_join_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_atomic_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';

void main() {
  final timestamp = Object();

  PartyCommandAggregate aggregate({int pending = 0, int pendingNonGroup = 0}) =>
      PartyCommandAggregate(
        recruitmentId: 'recruitment-1',
        leaderPlayerId: 'leader',
        currentCycleKey: '2026-09-09',
        currentCycleStatus: PartyRaidStateStatus.active,
        revision: 3,
        partySlots: [
          PartyAggregateSlot(
            playerId: 'leader',
            characterId: 'leader-character',
            role: PartyRole.support,
            classKey: '바드:지원',
            partyIndex: 0,
            slotIndex: 0,
          ),
        ],
        nonGroupMemberCount: 0,
        pendingApplicationCount: pending,
        pendingNonGroupApplicantCount: pendingNonGroup,
        groupId: 'group-1',
      );

  test('신청은 membership raidState 없이 pending 집계만 증가한다', () {
    final plan = PartyAtomicApplicationWritePlan.apply(
      application: {'status': 'pending', 'characterId': 'character-1'},
      aggregate: aggregate(),
      applicantPlayerId: 'applicant',
      applicantIsGroupMember: false,
      serverTimestamp: timestamp,
    );

    expect(plan.recruitmentPatch['pendingApplicationCount'], 1);
    expect(plan.recruitmentPatch['pendingNonGroupApplicantCount'], 1);
    expect(plan.application, isNot(contains('raidState')));
    expect(
      plan.event['audiencePlayerIds'],
      containsAll(['leader', 'applicant']),
    );
  });

  test('철회는 해당 신청자의 그룹 자격에 맞춰 집계를 되돌린다', () {
    final plan = PartyAtomicApplicationWritePlan.withdraw(
      application: {'status': 'withdrawn'},
      aggregate: aggregate(pending: 2, pendingNonGroup: 1),
      applicantPlayerId: 'applicant',
      applicantIsGroupMember: false,
      serverTimestamp: timestamp,
    );

    expect(plan.recruitmentPatch['pendingApplicationCount'], 1);
    expect(plan.recruitmentPatch['pendingNonGroupApplicantCount'], 0);
  });

  test('집계가 없는 철회와 참가 중인 Player 신청은 거절한다', () {
    expect(
      () => PartyAtomicApplicationWritePlan.withdraw(
        application: const {},
        aggregate: aggregate(),
        applicantPlayerId: 'applicant',
        applicantIsGroupMember: true,
        serverTimestamp: timestamp,
      ),
      throwsStateError,
    );
    expect(
      () => PartyAtomicApplicationWritePlan.apply(
        application: const {},
        aggregate: aggregate(),
        applicantPlayerId: 'leader',
        applicantIsGroupMember: true,
        serverTimestamp: timestamp,
      ),
      throwsStateError,
    );
  });

  test('승인은 pending 집계를 줄이는 동시에 가입 계획을 확정한다', () {
    final current = aggregate(pending: 1, pendingNonGroup: 1);
    final join = PartyAtomicJoinWritePlan.fromBase(
      base: PartyJoinWritePlan(
        recruitmentUpdate: const {'memberCount': 2, 'revision': 4},
        membership: const {
          'playerId': 'applicant',
          'characterId': 'character-1',
          'role': 'dealer',
          'partyIndex': 0,
          'slotIndex': 1,
          'joinedBy': 'leader',
        },
        assignment: const {
          'playerId': 'applicant',
          'characterId': 'character-1',
          'raidId': 'raid-1',
          'recruitmentId': 'recruitment-1',
          'cycleKey': '2026-09-09',
        },
      ),
      aggregate: current,
      rules: const RecruitmentPartyRules(
        partyCount: 1,
        membersPerParty: 4,
        supportsPerParty: 1,
        maxDealersPerClassPerParty: 1,
      ),
      classKey: '소서리스',
      raidId: 'raid-1',
      difficultyId: 'hard',
      joiningIsGroupMember: false,
      serverTimestamp: timestamp,
    );
    final plan = PartyAtomicApprovalWritePlan(
      join: join,
      aggregate: current,
      applicantIsGroupMember: false,
      applicationRevision: 2,
      serverTimestamp: timestamp,
    );

    expect(plan.recruitmentPatch['pendingApplicationCount'], 0);
    expect(plan.recruitmentPatch['pendingNonGroupApplicantCount'], 0);
    expect(plan.applicationPatch['status'], 'approved');
    expect(plan.applicationPatch['revision'], 3);
    expect(plan.raidStateId, 'character-1_raid-1');
  });
}
