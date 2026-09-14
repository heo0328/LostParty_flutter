import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_atomic_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_atomic_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';

void main() {
  final timestamp = Object();
  final incrementOne = Object();

  PartyCommandAggregate aggregate() => PartyCommandAggregate(
    recruitmentId: 'recruitment-1',
    leaderPlayerId: 'player-0',
    currentCycleKey: '2026-09-09',
    currentCycleStatus: PartyRaidStateStatus.active,
    revision: 4,
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
  );

  PartyCommandEnvelope command(PartyAtomicCommandType type) =>
      PartyCommandEnvelope(
        commandId: 'command-1',
        recruitmentId: 'recruitment-1',
        type: type,
        actorPlayerId: 'player-0',
        expectedRevision: 4,
        expectedCycleKey: '2026-09-09',
        nextCycleKey: type == PartyAtomicCommandType.advanceCycle
            ? '2026-09-16'
            : null,
        targets: [
          PartyCommandTarget(
            playerId: 'player-0',
            raidStateId: 'character-0_raid-1',
          ),
        ],
      );

  test('완료는 모집과 raidState를 같은 다음 revision으로 만든다', () {
    final plan = PartyAtomicWritePlan(
      command: command(PartyAtomicCommandType.complete),
      aggregate: aggregate(),
      serverTimestamp: timestamp,
      incrementOne: incrementOne,
    );

    expect(plan.recruitmentPatch['currentCycleStatus'], 'completed');
    expect(plan.recruitmentPatch['status'], 'active');
    expect(plan.recruitmentPatch['revision'], 5);
    expect(plan.raidStateWrites.single.patch?['status'], 'completed');
    expect(plan.raidStateWrites.single.patch?['revision'], same(incrementOne));
  });

  test('1회성 모집 완료는 반복방과 달리 모집 자체도 completed가 된다', () {
    final oneShot = PartyCommandAggregate(
      recruitmentId: 'recruitment-1',
      leaderPlayerId: 'player-0',
      currentCycleKey: '2026-09-09',
      currentCycleStatus: PartyRaidStateStatus.active,
      revision: 4,
      partySlots: aggregate().partySlots,
      nonGroupMemberCount: 0,
      pendingApplicationCount: 0,
      pendingNonGroupApplicantCount: 0,
    );
    final plan = PartyAtomicWritePlan(
      command: command(PartyAtomicCommandType.complete),
      aggregate: oneShot,
      serverTimestamp: timestamp,
      incrementOne: incrementOne,
    );

    expect(plan.recruitmentPatch['status'], 'completed');
    expect(plan.listingPatch['status'], 'completed');
  });

  test('전환은 모집과 모든 raidState의 회차 키를 함께 바꾼다', () {
    final plan = PartyAtomicWritePlan(
      command: command(PartyAtomicCommandType.advanceCycle),
      aggregate: aggregate(),
      serverTimestamp: timestamp,
      incrementOne: incrementOne,
    );

    expect(plan.recruitmentPatch['currentCycleKey'], '2026-09-16');
    expect(plan.raidStateWrites.single.patch?['cycleKey'], '2026-09-16');
  });

  test('활성 해산은 raidState를 삭제하고 개인 이벤트를 복제하지 않는다', () {
    final plan = PartyAtomicWritePlan(
      command: command(PartyAtomicCommandType.disband),
      aggregate: aggregate(),
      serverTimestamp: timestamp,
      incrementOne: incrementOne,
    );

    expect(plan.recruitmentPatch['status'], 'disbanded');
    expect(
      plan.raidStateWrites.single.action,
      PartyRaidStateWriteAction.delete,
    );
    expect(plan.eventDocument['audiencePlayerIds'], ['player-0']);
  });

  test('8인 그룹 1회성 완료도 12건의 제한된 쓰기로 끝난다', () {
    final targets = List.generate(
      8,
      (index) => PartyCommandTarget(
        playerId: 'player-$index',
        raidStateId: 'character-${index}_raid-1',
      ),
    );
    final eightPlayerCommand = PartyCommandEnvelope(
      commandId: 'command-8',
      recruitmentId: 'recruitment-1',
      type: PartyAtomicCommandType.complete,
      actorPlayerId: 'player-0',
      expectedRevision: 4,
      expectedCycleKey: '2026-09-09',
      targets: targets,
    );
    final plan = PartyAtomicWritePlan(
      command: eightPlayerCommand,
      aggregate: PartyCommandAggregate(
        recruitmentId: 'recruitment-1',
        leaderPlayerId: 'player-0',
        currentCycleKey: '2026-09-09',
        currentCycleStatus: PartyRaidStateStatus.active,
        revision: 4,
        partySlots: List.generate(
          8,
          (index) => PartyAggregateSlot(
            playerId: 'player-$index',
            characterId: 'character-$index',
            role: index == 3 || index == 7
                ? PartyRole.support
                : PartyRole.dealer,
            classKey: 'class-$index',
            partyIndex: index ~/ 4,
            slotIndex: index % 4,
            countedAsNonGroupMember: false,
          ),
        ),
        nonGroupMemberCount: 0,
        pendingApplicationCount: 0,
        pendingNonGroupApplicantCount: 0,
        groupId: 'group-1',
        visibility: 'group',
      ),
      serverTimestamp: timestamp,
      incrementOne: incrementOne,
    );

    expect(plan.maximumWriteCount, 12);
    expect(plan.raidStateWrites, hasLength(8));
    expect(plan.closesActiveGroupRecruitment, isTrue);
    expect(plan.groupListingAction, PartyGroupListingWriteAction.delete);
  });

  test('오래된 revision 또는 다른 모집 Aggregate는 계획 전에 거절한다', () {
    final stale = command(PartyAtomicCommandType.complete);
    final current = PartyCommandAggregate(
      recruitmentId: 'recruitment-1',
      leaderPlayerId: 'player-0',
      currentCycleKey: '2026-09-09',
      currentCycleStatus: PartyRaidStateStatus.active,
      revision: 5,
      partySlots: aggregate().partySlots,
      nonGroupMemberCount: 0,
      pendingApplicationCount: 0,
      pendingNonGroupApplicantCount: 0,
    );

    expect(
      () => PartyAtomicWritePlan(
        command: stale,
        aggregate: current,
        serverTimestamp: timestamp,
        incrementOne: incrementOne,
      ),
      throwsStateError,
    );
  });

  test('현재 슬롯과 다른 raidState 대상은 계획 전에 거절한다', () {
    final wrongTarget = PartyCommandEnvelope(
      commandId: 'command-wrong',
      recruitmentId: 'recruitment-1',
      type: PartyAtomicCommandType.complete,
      actorPlayerId: 'player-0',
      expectedRevision: 4,
      expectedCycleKey: '2026-09-09',
      targets: [
        PartyCommandTarget(
          playerId: 'player-0',
          raidStateId: 'other-character_raid-1',
        ),
      ],
    );

    expect(
      () => PartyAtomicWritePlan(
        command: wrongTarget,
        aggregate: aggregate(),
        serverTimestamp: timestamp,
        incrementOne: incrementOne,
      ),
      throwsStateError,
    );
  });

  test('raidState는 같은 모집 회차 revision의 허용 상태만 받는다', () {
    final plan = PartyAtomicWritePlan(
      command: command(PartyAtomicCommandType.complete),
      aggregate: aggregate(),
      serverTimestamp: timestamp,
      incrementOne: incrementOne,
    );
    final valid = {
      'player-0/character-0_raid-1': <String, Object?>{
        'recruitmentId': 'recruitment-1',
        'cycleKey': '2026-09-09',
        'revision': 4,
        'status': 'active',
      },
    };

    expect(plan.raidStateDocumentsAllow(valid), isTrue);
    expect(
      plan.raidStateDocumentsAllow({
        for (final entry in valid.entries)
          entry.key: {...entry.value, 'revision': 'invalid'},
      }),
      isFalse,
    );
  });

  test('완료 후 해산은 completed raidState 보존을 위해 대상이 없어야 한다', () {
    final completed = PartyCommandAggregate(
      recruitmentId: 'recruitment-1',
      leaderPlayerId: 'player-0',
      currentCycleKey: '2026-09-09',
      currentCycleStatus: PartyRaidStateStatus.completed,
      revision: 4,
      partySlots: aggregate().partySlots,
      nonGroupMemberCount: 0,
      pendingApplicationCount: 0,
      pendingNonGroupApplicantCount: 0,
    );

    expect(
      () => PartyAtomicWritePlan(
        command: command(PartyAtomicCommandType.disband),
        aggregate: completed,
        serverTimestamp: timestamp,
        incrementOne: incrementOne,
      ),
      throwsStateError,
    );
    final completedDisband = PartyAtomicWritePlan(
      command: PartyCommandEnvelope(
        commandId: 'command-completed-disband',
        recruitmentId: 'recruitment-1',
        type: PartyAtomicCommandType.disband,
        actorPlayerId: 'player-0',
        expectedRevision: 4,
        expectedCycleKey: '2026-09-09',
        targets: const [],
      ),
      aggregate: completed,
      serverTimestamp: timestamp,
      incrementOne: incrementOne,
    );
    expect(completedDisband.raidStateWrites, isEmpty);
    expect(completedDisband.maximumWriteCount, 2);
  });
}
