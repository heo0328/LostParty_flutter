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

  for (final previousRole in PartyRole.values) {
    for (final nextRole in PartyRole.values) {
      for (final sameCharacter in [false, true]) {
        if (sameCharacter && previousRole == nextRole) continue;
        test(
          '$previousRole → $nextRole sameCharacter=$sameCharacter 역할 저장',
          () {
            final aggregate = _aggregate(
              slots: [
                PartyAggregateSlot(
                  playerId: 'leader',
                  characterId: 'original',
                  role: previousRole,
                  classKey: '바드',
                  partyIndex: 0,
                  slotIndex: 0,
                  countedAsNonGroupMember: false,
                ),
              ],
            );
            PartyAtomicCharacterChangeWritePlan build() =>
                PartyAtomicCharacterChangeWritePlan(
                  aggregate: aggregate,
                  rules: rules,
                  playerId: 'leader',
                  newCharacterId: sameCharacter ? 'original' : 'replacement',
                  previousRaidStateRevision: sameCharacter ? 3 : null,
                  newClassKey: nextRole == PartyRole.support
                      ? '바드:지원'
                      : '바드:공격',
                  newRole: nextRole,
                  raidId: 'raid-1',
                  difficultyId: 'hard',
                  membershipPatch: {'role': nextRole.name},
                  serverTimestamp: timestamp,
                );
            final plan = build();
            expect(plan.nextRaidState['revision'], sameCharacter ? 4 : 1);
            expect(plan.nextRaidState['role'], nextRole.name);
            expect(
              (plan.recruitmentPatch['partySlots'] as List).single['role'],
              nextRole.name,
            );
          },
        );
      }
    }
  }

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

  test('완료 반복방 준비 변경은 구성과 이벤트만 만들고 완료 필드를 쓰지 않는다', () {
    final plan = PartyAtomicNextWeekCharacterChangeWritePlan(
      aggregate: _aggregate(cycleStatus: PartyRaidStateStatus.completed),
      rules: rules,
      playerId: 'member',
      newCharacterId: 'new-character',
      newClassKey: '소서리스',
      newRole: PartyRole.dealer,
      raidId: 'raid-1',
      difficultyId: 'hard',
      ownershipRevision: 5,
      membershipPatch: {'characterId': 'new-character', 'role': 'dealer'},
      serverTimestamp: timestamp,
    );
    expect(plan.recruitmentPatch.keys.toSet(), {
      'partySlots',
      'raidStateTargets',
      'dealerCount',
      'supportCount',
      'revision',
      'updatedAt',
    });
    expect(plan.membershipPatch['characterId'], 'new-character');
    expect(plan.event['type'], 'characterChanged');
    expect(plan.recruitmentPatch['revision'], 5);
    expect(
      (plan.recruitmentPatch['raidStateTargets'] as List)[1]['stateId'],
      'new-character_raid-1',
    );
  });

  test('진행 중 회차는 준비 전용 writer를 사용할 수 없다', () {
    expect(
      () => PartyAtomicNextWeekCharacterChangeWritePlan(
        aggregate: _aggregate(),
        rules: rules,
        playerId: 'member',
        newCharacterId: 'new-character',
        newClassKey: '소서리스',
        newRole: PartyRole.dealer,
        raidId: 'raid-1',
        difficultyId: 'hard',
        ownershipRevision: 5,
        membershipPatch: {},
        serverTimestamp: timestamp,
      ),
      throwsStateError,
    );
  });

  test('같은 캐릭터의 준비 역할 변경은 참가 경로를 보존하고 빈자리로 배치한다', () {
    final plan = PartyAtomicNextWeekCharacterChangeWritePlan(
      aggregate: _aggregate(cycleStatus: PartyRaidStateStatus.completed),
      rules: rules,
      playerId: 'member',
      newCharacterId: 'old-character',
      newClassKey: '버서커',
      newRole: PartyRole.support,
      raidId: 'raid-1',
      difficultyId: 'hard',
      ownershipRevision: 5,
      membershipPatch: {'characterId': 'old-character', 'role': 'support'},
      serverTimestamp: timestamp,
    );
    expect(plan.membershipPatch['partyIndex'], 1);
    expect(plan.membershipPatch['slotIndex'], 1);
    expect(
      (plan.recruitmentPatch['raidStateTargets'] as List)[1]['stateId'],
      'old-character_raid-1',
    );
    expect(plan.event['previousCharacterId'], plan.event['nextCharacterId']);
  });

  test('현재 역할 그대로 또는 revision 없는 동일 캐릭터 갱신은 거절한다', () {
    for (final role in PartyRole.values) {
      expect(
        () => PartyAtomicCharacterChangeWritePlan(
          aggregate: _aggregate(),
          rules: rules,
          playerId: 'member',
          newCharacterId: 'old-character',
          newClassKey: '버서커',
          newRole: role,
          raidId: 'raid-1',
          difficultyId: 'hard',
          ownershipRevision: 5,
          membershipPatch: {},
          serverTimestamp: timestamp,
          previousRaidStateRevision: role == PartyRole.dealer ? 2 : null,
        ),
        throwsStateError,
      );
    }
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
    expect(emptyMove.maximumWriteCount, 3);
    expect(swap.membershipPatches.keys, containsAll(['member', 'other']));
    expect(swap.maximumWriteCount, 4);
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

PartyCommandAggregate _aggregate({
  List<PartyAggregateSlot>? slots,
  PartyRaidStateStatus cycleStatus = PartyRaidStateStatus.active,
}) => PartyCommandAggregate(
  recruitmentId: 'recruitment-1',
  raidId: 'raid-1',
  difficultyId: 'hard',
  leaderPlayerId: 'leader',
  currentCycleKey: '2026-09-09',
  currentCycleStatus: cycleStatus,
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
