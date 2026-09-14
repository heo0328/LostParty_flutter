import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_atomic_member_mutation_write_plan.dart';
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

  test('캐릭터 변경은 기존 raidState 삭제와 신규 상태 생성만 계획한다', () {
    final plan = PartyAtomicCharacterChangeWritePlan(
      aggregate: _aggregate(),
      rules: rules,
      playerId: 'member',
      newCharacterId: 'new-character',
      newClassKey: '소서리스',
      newRole: PartyRole.dealer,
      raidId: 'raid-1',
      difficultyId: 'hard',
      membershipPatch: {
        'characterId': 'new-character',
        'characterNameSnapshot': '새캐릭',
        'classNameSnapshot': '소서리스',
        'role': 'dealer',
        'updatedAt': timestamp,
      },
      serverTimestamp: timestamp,
    );

    expect(plan.previousRaidStateId, 'old-character_raid-1');
    expect(plan.nextRaidStateId, 'new-character_raid-1');
    expect(plan.nextRaidState['revision'], 1);
    expect(plan.nextRaidState['status'], 'active');
    expect((plan.recruitmentPatch['partySlots']! as List), hasLength(3));
  });

  test('빈자리 이동은 한 명, 점유 자리 교환은 두 명만 갱신한다', () {
    final emptyMove = PartyAtomicRepositionWritePlan(
      aggregate: _aggregate(),
      rules: rules,
      sourcePlayerId: 'member',
      destinationPartyIndex: 1,
      destinationSlotIndex: 1,
      actorPlayerId: 'leader',
      serverTimestamp: timestamp,
    );
    final swap = PartyAtomicRepositionWritePlan(
      aggregate: _aggregate(),
      rules: rules,
      sourcePlayerId: 'member',
      destinationPartyIndex: 1,
      destinationSlotIndex: 0,
      actorPlayerId: 'leader',
      serverTimestamp: timestamp,
    );

    expect(emptyMove.membershipPatches.keys, ['member']);
    expect(emptyMove.maximumWriteCount, 4);
    expect(swap.membershipPatches.keys, containsAll(['member', 'other']));
    expect(swap.maximumWriteCount, 5);
  });

  test('파티장 이동과 범위 밖 슬롯은 거절한다', () {
    expect(
      () => PartyAtomicRepositionWritePlan(
        aggregate: _aggregate(),
        rules: rules,
        sourcePlayerId: 'leader',
        destinationPartyIndex: 1,
        destinationSlotIndex: 1,
        actorPlayerId: 'leader',
        serverTimestamp: timestamp,
      ),
      throwsStateError,
    );
    expect(
      () => PartyAtomicRepositionWritePlan(
        aggregate: _aggregate(),
        rules: rules,
        sourcePlayerId: 'member',
        destinationPartyIndex: 2,
        destinationSlotIndex: 0,
        actorPlayerId: 'leader',
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
    PartyAggregateSlot(
      playerId: 'leader',
      characterId: 'leader-character',
      role: PartyRole.support,
      classKey: '바드:지원',
      partyIndex: 0,
      slotIndex: 0,
    ),
    PartyAggregateSlot(
      playerId: 'member',
      characterId: 'old-character',
      role: PartyRole.dealer,
      classKey: '버서커',
      partyIndex: 0,
      slotIndex: 1,
    ),
    PartyAggregateSlot(
      playerId: 'other',
      characterId: 'other-character',
      role: PartyRole.dealer,
      classKey: '디스트로이어',
      partyIndex: 1,
      slotIndex: 0,
    ),
  ],
  nonGroupMemberCount: 0,
  pendingApplicationCount: 0,
  pendingNonGroupApplicantCount: 0,
  continueTogether: true,
);
