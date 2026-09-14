import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_atomic_member_removal_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_atomic_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';

void main() {
  final timestamp = Object();
  const rules = RecruitmentPartyRules(
    partyCount: 2,
    membersPerParty: 4,
    supportsPerParty: 1,
    maxDealersPerClassPerParty: 1,
  );

  test('일반 탈퇴는 대상 membership·raidState와 공용 이벤트 한 건만 계획한다', () {
    final plan = PartyAtomicMemberRemovalWritePlan(
      aggregate: _aggregate(),
      rules: rules,
      targetPlayerId: 'third',
      actorPlayerId: 'third',
      type: PartyAtomicMemberRemovalType.leave,
      raidId: 'raid-1',
      targetIsGroupMember: false,
      serverTimestamp: timestamp,
    );

    expect(plan.successorPlayerId, isNull);
    expect(plan.targetRaidStateId, 'third-character_raid-1');
    expect(plan.recruitmentPatch['memberPlayerIds'], ['leader', 'second']);
    expect(plan.recruitmentPatch['nonGroupMemberCount'], 1);
    expect(plan.event['audiencePlayerIds'], ['leader', 'second', 'third']);
    expect(plan.maximumWriteCount, 4);
  });

  test('파티장 탈퇴는 가입 순서의 첫 번째 잔류자 한 명만 승계한다', () {
    final plan = PartyAtomicMemberRemovalWritePlan(
      aggregate: _aggregate(),
      rules: rules,
      targetPlayerId: 'leader',
      actorPlayerId: 'leader',
      type: PartyAtomicMemberRemovalType.leave,
      raidId: 'raid-1',
      targetIsGroupMember: true,
      successorSnapshot: const PartyLeaderSuccessorSnapshot(
        playerId: 'second',
        characterName: '두번째',
        className: '버서커',
      ),
      serverTimestamp: timestamp,
    );

    expect(plan.successorPlayerId, 'second');
    expect(plan.successorMembershipPatch, {
      'canApproveApplications': true,
      'updatedAt': timestamp,
    });
    expect(plan.recruitmentPatch['leaderPlayerId'], 'second');
    expect(plan.recruitmentPatch['leaderCharacterNameSnapshot'], '두번째');
    expect(plan.maximumWriteCount, 5);
  });

  test('추방 권한과 마지막 한 명의 일반 탈퇴를 거절한다', () {
    expect(
      () => PartyAtomicMemberRemovalWritePlan(
        aggregate: _aggregate(),
        rules: rules,
        targetPlayerId: 'third',
        actorPlayerId: 'second',
        type: PartyAtomicMemberRemovalType.kick,
        raidId: 'raid-1',
        targetIsGroupMember: false,
        serverTimestamp: timestamp,
      ),
      throwsStateError,
    );
    expect(
      () => PartyAtomicMemberRemovalWritePlan(
        aggregate: _soloAggregate(),
        rules: rules,
        targetPlayerId: 'leader',
        actorPlayerId: 'leader',
        type: PartyAtomicMemberRemovalType.leave,
        raidId: 'raid-1',
        targetIsGroupMember: true,
        serverTimestamp: timestamp,
      ),
      throwsStateError,
    );
  });
}

PartyCommandAggregate _aggregate() => PartyCommandAggregate(
  recruitmentId: 'recruitment-1',
  leaderPlayerId: 'leader',
  currentCycleKey: '2026-09-09',
  currentCycleStatus: PartyRaidStateStatus.active,
  revision: 4,
  partySlots: [
    _slot('leader', 'leader-character', PartyRole.support, 0),
    _slot('second', 'second-character', PartyRole.dealer, 1),
    _slot('third', 'third-character', PartyRole.dealer, 2),
  ],
  nonGroupMemberCount: 2,
  pendingApplicationCount: 0,
  pendingNonGroupApplicantCount: 0,
  groupId: 'group-1',
);

PartyCommandAggregate _soloAggregate() => PartyCommandAggregate(
  recruitmentId: 'recruitment-1',
  leaderPlayerId: 'leader',
  currentCycleKey: '2026-09-09',
  currentCycleStatus: PartyRaidStateStatus.active,
  revision: 4,
  partySlots: [_slot('leader', 'leader-character', PartyRole.support, 0)],
  nonGroupMemberCount: 0,
  pendingApplicationCount: 0,
  pendingNonGroupApplicantCount: 0,
  groupId: 'group-1',
);

PartyAggregateSlot _slot(
  String playerId,
  String characterId,
  PartyRole role,
  int slotIndex,
) => PartyAggregateSlot(
  playerId: playerId,
  characterId: characterId,
  role: role,
  classKey: role == PartyRole.support ? '바드:지원' : '버서커',
  partyIndex: 0,
  slotIndex: slotIndex,
);
