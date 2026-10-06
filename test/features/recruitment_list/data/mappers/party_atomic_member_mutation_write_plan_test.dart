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
      ownershipRevision: 3,
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
    expect(plan.nextRaidState['ownershipRevision'], 3);
    expect(plan.membershipPatch['ownershipRevision'], 3);
    expect(
      (plan.recruitmentPatch['partySlots']! as List).firstWhere(
        (s) => s['playerId'] == 'member',
      )['ownershipRevision'],
      3,
    );
    expect(plan.nextRaidState['status'], 'active');
    expect(plan.nextRaidState['role'], 'dealer');
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
    for (final plan in [emptyMove, swap]) {
      final slots = plan.recruitmentPatch['partySlots']! as List;
      expect(
        slots.firstWhere((s) => s['playerId'] == 'member')['ownershipRevision'],
        5,
      );
      expect(
        slots.firstWhere((s) => s['playerId'] == 'other')['ownershipRevision'],
        0,
      );
      expect(
        slots
            .firstWhere((s) => s['playerId'] == 'leader')
            .containsKey('ownershipRevision'),
        false,
      );
    }
  });

  test('8인 구성 변경은 빈자리 우선이고 만석 교환은 자동 실행하지 않는다', () {
    final full = [
      for (var index = 0; index < 8; index++)
        PartyAggregateSlot(
          playerId: index == 0 ? 'leader' : 'p$index',
          characterId: 'c$index',
          classKey: 'class$index',
          role: index % 4 == 3 ? PartyRole.support : PartyRole.dealer,
          partyIndex: index ~/ 4,
          slotIndex: index % 4,
          countedAsNonGroupMember: false,
        ),
    ];
    for (final hasVacancy in [true, false]) {
      final slots = full
          .where((s) => !hasVacancy || s.playerId != 'p6')
          .toList();
      final plan = PartyAtomicCharacterChangeWritePlan(
        aggregate: _aggregate(slots: slots),
        rules: rules,
        playerId: 'p1',
        newCharacterId: 'new-character',
        newClassKey: 'class0',
        newRole: PartyRole.dealer,
        raidId: 'raid-1',
        difficultyId: 'hard',
        membershipPatch: const {'partyIndex': 99, 'slotIndex': 99},
        serverTimestamp: timestamp,
      );
      expect(plan.membershipPatch['partyIndex'], hasVacancy ? 1 : 0);
      expect(plan.membershipPatch['slotIndex'], hasVacancy ? 2 : 1);
      final after = plan.recruitmentPatch['partySlots']! as List;
      for (var index = 0; index < slots.length; index++) {
        if (slots[index].playerId == 'p1') continue;
        expect(after[index]['partyIndex'], slots[index].partyIndex);
        expect(after[index]['slotIndex'], slots[index].slotIndex);
        expect(after[index]['characterId'], slots[index].characterId);
      }
      expect(plan.event['type'], 'characterChanged');
    }
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

PartyCommandAggregate _aggregate({List<PartyAggregateSlot>? slots}) =>
    PartyCommandAggregate(
      recruitmentId: 'recruitment-1',
      raidId: 'raid-1',
      difficultyId: 'hard',
      leaderPlayerId: 'leader',
      currentCycleKey: '2026-09-09',
      currentCycleStatus: PartyRaidStateStatus.active,
      revision: 4,
      partySlots:
          slots ??
          [
            PartyAggregateSlot(
              playerId: 'leader',
              characterId: 'leader-character',
              role: PartyRole.support,
              classKey: '바드:지원',
              partyIndex: 0,
              slotIndex: 0,
              countedAsNonGroupMember: false,
            ),
            PartyAggregateSlot(
              playerId: 'member',
              characterId: 'old-character',
              ownershipRevision: 5,
              role: PartyRole.dealer,
              classKey: '버서커',
              partyIndex: 0,
              slotIndex: 1,
              countedAsNonGroupMember: false,
            ),
            PartyAggregateSlot(
              playerId: 'other',
              characterId: 'other-character',
              ownershipRevision: 0,
              role: PartyRole.dealer,
              classKey: '디스트로이어',
              partyIndex: 1,
              slotIndex: 0,
              countedAsNonGroupMember: false,
            ),
          ],
      nonGroupMemberCount: 0,
      pendingApplicationCount: 0,
      pendingNonGroupApplicantCount: 0,
      continueTogether: true,
    );
