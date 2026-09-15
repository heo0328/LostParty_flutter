import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_atomic_membership_write_plan.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_create_write_plan.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_join_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_atomic_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_create_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';

void main() {
  final timestamp = Object();
  const rules = RecruitmentPartyRules(
    partyCount: 2,
    membersPerParty: 4,
    supportsPerParty: 1,
    maxDealersPerClassPerParty: 1,
  );

  test('생성은 기존 membership Snapshot을 보존하고 raidState를 만든다', () {
    final base = PartyCreateWritePlan(
      recruitment: {
        'status': 'active',
        'visibility': 'public',
        'groupId': null,
        'continueTogether': false,
        'currentCycleKey': '2026-09-09',
        'currentCycleStatus': 'active',
        'revision': 1,
      },
      leaderMembership: {
        'playerId': 'player-0',
        'characterId': 'character-0',
        'buildIntegritySnapshot': {'status': 'error'},
      },
      assignment: {
        'playerId': 'player-0',
        'characterId': 'character-0',
        'raidId': 'raid-1',
        'recruitmentId': 'recruitment-1',
        'cycleKey': '2026-09-09',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      },
    );
    final plan = PartyAtomicCreateWritePlan.fromBase(
      base: base,
      command: _createCommand(rules),
      playerId: 'player-0',
      classKey: '바드:지원',
      serverTimestamp: timestamp,
    );

    expect(plan.recruitment['schemaVersion'], 2);
    expect((plan.recruitment['partySlots']! as List), hasLength(1));
    expect(plan.raidStateId, 'character-0_raid-1');
    expect(plan.raidState['status'], 'active');
    expect(plan.raidState['source'], 'party');
    expect(plan.leaderMembership['buildIntegritySnapshot'], {
      'status': 'error',
    });
    expect(plan.event['audiencePlayerIds'], ['player-0']);
    expect(plan.recruitment['groupActiveRecruitmentCountAfter'], 0);
  });

  test('그룹 모집 생성은 전달된 activeRecruitmentCountAfter를 기록한다', () {
    final base = PartyCreateWritePlan(
      recruitment: {
        'status': 'active',
        'visibility': 'group',
        'groupId': 'group-1',
        'continueTogether': false,
        'currentCycleKey': '2026-09-09',
        'currentCycleStatus': 'active',
        'revision': 1,
      },
      leaderMembership: {
        'playerId': 'player-0',
        'characterId': 'character-0',
      },
      assignment: {
        'playerId': 'player-0',
        'characterId': 'character-0',
        'raidId': 'raid-1',
        'recruitmentId': 'recruitment-1',
        'cycleKey': '2026-09-09',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      },
    );
    final plan = PartyAtomicCreateWritePlan.fromBase(
      base: base,
      command: _createCommand(rules, groupId: 'group-1'),
      playerId: 'player-0',
      classKey: '바드:지원',
      serverTimestamp: timestamp,
      groupActiveRecruitmentCountAfter: 2,
    );

    expect(plan.recruitment['groupActiveRecruitmentCountAfter'], 2);
    expect(plan.groupActiveRecruitmentDelta, 1);
  });

  test('가입은 고정 슬롯과 raidState를 추가하고 공용 이벤트 한 건을 만든다', () {
    final plan = PartyAtomicJoinWritePlan.fromBase(
      base: _joinBase(className: '소서리스', partyIndex: 0, slotIndex: 1),
      aggregate: _aggregate(),
      rules: rules,
      classKey: '소서리스',
      raidId: 'raid-1',
      difficultyId: 'hard',
      joiningIsGroupMember: false,
      serverTimestamp: timestamp,
    );

    expect((plan.recruitmentPatch['partySlots']! as List), hasLength(2));
    expect(plan.recruitmentPatch['nonGroupMemberCount'], 1);
    expect(plan.raidStateId, 'character-1_raid-1');
    expect(plan.raidState['revision'], 1);
    expect(plan.membership['buildIntegritySnapshot'], {'status': 'error'});
    expect(plan.event['audiencePlayerIds'], ['player-0', 'player-1']);
    expect(plan.event['actorPlayerId'], 'player-0');
  });

  test('같은 파티의 동일 딜러 classKey 가입은 계획 단계에서 거절한다', () {
    expect(
      () => PartyAtomicJoinWritePlan.fromBase(
        base: _joinBase(className: '버서커', partyIndex: 0, slotIndex: 1),
        aggregate: _aggregate(),
        rules: rules,
        classKey: '버서커',
        raidId: 'raid-1',
        difficultyId: 'hard',
        joiningIsGroupMember: true,
        serverTimestamp: timestamp,
      ),
      throwsStateError,
    );
  });
}

PartyCommandAggregate _aggregate() => PartyCommandAggregate(
  recruitmentId: 'recruitment-1',
  leaderPlayerId: 'player-0',
  currentCycleKey: '2026-09-09',
  currentCycleStatus: PartyRaidStateStatus.active,
  revision: 1,
  partySlots: [
    PartyAggregateSlot(
      playerId: 'player-0',
      characterId: 'character-0',
      role: PartyRole.dealer,
      classKey: '버서커',
      partyIndex: 0,
      slotIndex: 0,
      countedAsNonGroupMember: false,
    ),
  ],
  nonGroupMemberCount: 0,
  pendingApplicationCount: 0,
  pendingNonGroupApplicantCount: 0,
  continueTogether: true,
  groupId: 'group-1',
);

PartyJoinWritePlan _joinBase({
  required String className,
  required int partyIndex,
  required int slotIndex,
}) => PartyJoinWritePlan(
  recruitmentUpdate: {
    'memberPlayerIds': ['player-0', 'player-1'],
    'memberCount': 2,
    'dealerCount': 2,
    'supportCount': 0,
    'revision': 2,
  },
  membership: {
    'playerId': 'player-1',
    'characterId': 'character-1',
    'classNameSnapshot': className,
    'role': 'dealer',
    'partyIndex': partyIndex,
    'slotIndex': slotIndex,
    'joinedBy': 'player-0',
    'buildIntegritySnapshot': {'status': 'error'},
  },
  assignment: {
    'playerId': 'player-1',
    'characterId': 'character-1',
    'raidId': 'raid-1',
    'recruitmentId': 'recruitment-1',
    'cycleKey': '2026-09-09',
  },
);

PartyCreateCommand _createCommand(
  RecruitmentPartyRules rules, {
  String? groupId,
}) => PartyCreateCommand(
      recruitmentId: 'recruitment-1',
      title: '테스트',
      metadata: const RecruitmentMetadata(
        catalogVersion: 'v1',
        raidId: 'raid-1',
        difficultyId: 'hard',
        raidName: '레이드',
        difficultyName: '하드',
        difficultyAlias: '하드',
        gateCount: 3,
        minItemLevel: 1700,
        minCombatPower: null,
        experienceLevel: ExperienceLevel.experienced,
        maxPlayHours: 2,
      ),
      leaderCharacterId: 'character-0',
      leaderCharacterName: '캐릭터',
      leaderClassName: '바드',
      leaderRole: PartyRole.support,
      leaderItemLevel: 1700,
      approvalPolicy: const ApprovalPolicy.leaderOnly(),
      compositionRules: rules,
      cycleKey: '2026-09-09',
      visibility: groupId == null
          ? RecruitmentVisibility.public
          : RecruitmentVisibility.group,
      groupId: groupId,
    );
