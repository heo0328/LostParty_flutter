import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_atomic_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';

void main() {
  PartyAggregateSlot slot(int index, {PartyRole role = PartyRole.dealer}) =>
      PartyAggregateSlot(
        playerId: 'player-$index',
        characterId: 'character-$index',
        role: role,
        classKey: role == PartyRole.support ? '바드:지원' : '버서커',
        partyIndex: index ~/ 4,
        slotIndex: index % 4,
        countedAsNonGroupMember: false,
      );

  PartyCommandAggregate aggregate({
    int revision = 4,
    String? lastCommandId,
    PartyAtomicCommandType? lastCommandType,
    List<PartyAggregateSlot>? slots,
  }) => PartyCommandAggregate(
    recruitmentId: 'recruitment-1',
    raidId: 'raid-1',
    difficultyId: 'hard',
    leaderPlayerId: 'player-0',
    currentCycleKey: '2026-09-09',
    currentCycleStatus: PartyRaidStateStatus.active,
    revision: revision,
    partySlots: slots ?? [slot(0), slot(1, role: PartyRole.support)],
    nonGroupMemberCount: 0,
    pendingApplicationCount: 0,
    pendingNonGroupApplicantCount: 0,
    lastCommandId: lastCommandId,
    lastCommandType: lastCommandType,
  );

  test('raidState ID는 캐릭터와 레이드 기준이며 난이도를 포함하지 않는다', () {
    expect(
      PartyRaidState.documentIdFor(characterId: 'char-1', raidId: 'raid-1'),
      'char-1_raid-1',
    );
  });

  test('Aggregate는 Player와 자리 중복 및 8칸 초과를 거절한다', () {
    expect(() => aggregate(slots: [slot(0), slot(0)]), throwsArgumentError);
    expect(() => aggregate(slots: List.generate(9, slot)), throwsArgumentError);
  });

  test('집계와 역할 수는 고정 슬롯에서 결정된다', () {
    final value = aggregate();

    expect(value.memberCount, 2);
    expect(value.dealerCount, 1);
    expect(value.supporterCount, 1);
    expect(value.canBecomeGroupOnly, isTrue);
  });

  test('명령 봉투는 최대 8개의 고유 대상을 요구한다', () {
    expect(
      () => PartyCommandEnvelope(
        commandId: 'command-1',
        recruitmentId: 'recruitment-1',
        type: PartyAtomicCommandType.complete,
        actorPlayerId: 'player-0',
        expectedRevision: 4,
        expectedCycleKey: '2026-09-09',
        targets: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => PartyCommandEnvelope(
        commandId: 'command-2',
        recruitmentId: 'recruitment-1',
        type: PartyAtomicCommandType.disband,
        actorPlayerId: 'player-0',
        expectedRevision: 4,
        expectedCycleKey: '2026-09-09',
        targets: const [],
      ),
      returnsNormally,
    );
    expect(
      () => PartyCommandEnvelope(
        commandId: 'command-1',
        recruitmentId: 'recruitment-1',
        type: PartyAtomicCommandType.complete,
        actorPlayerId: 'player-0',
        expectedRevision: 4,
        expectedCycleKey: '2026-09-09',
        targets: [
          PartyCommandTarget(playerId: 'player-1', raidStateId: 'state-1'),
          PartyCommandTarget(playerId: 'player-1', raidStateId: 'state-1'),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('주차 전환만 서로 다른 다음 회차 키를 요구한다', () {
    expect(
      () => PartyCommandEnvelope(
        commandId: 'command-3',
        recruitmentId: 'recruitment-1',
        type: PartyAtomicCommandType.advanceCycle,
        actorPlayerId: 'player-0',
        expectedRevision: 4,
        expectedCycleKey: '2026-09-09',
        nextCycleKey: '2026-09-09',
        nextCycleStartedAt: DateTime.utc(2026, 9, 8, 21),
        nextCycleEndsAt: DateTime.utc(2026, 9, 15, 21),
        targets: [
          PartyCommandTarget(playerId: 'player-0', raidStateId: 'state-0'),
        ],
      ),
      throwsArgumentError,
    );

    expect(
      () => PartyCommandEnvelope(
        commandId: 'command-4',
        recruitmentId: 'recruitment-1',
        type: PartyAtomicCommandType.advanceCycle,
        actorPlayerId: 'player-0',
        expectedRevision: 4,
        expectedCycleKey: '2026-09-09',
        nextCycleKey: '2026-09-16',
        nextCycleStartedAt: DateTime.utc(2026, 9, 15, 21),
        nextCycleEndsAt: DateTime.utc(2026, 9, 22, 21),
        targets: [
          PartyCommandTarget(playerId: 'player-0', raidStateId: 'state-0'),
        ],
      ),
      returnsNormally,
    );
  });

  test('응답 유실 후 revision과 commandId로 적용 여부를 판정한다', () {
    final applied = aggregate(
      revision: 5,
      lastCommandId: 'command-1',
      lastCommandType: PartyAtomicCommandType.complete,
    );
    final untouched = aggregate(revision: 4);
    final changedByOther = aggregate(revision: 6);

    expect(applied.classify('command-1', 4), PartyCommandRecovery.applied);
    expect(untouched.classify('command-1', 4), PartyCommandRecovery.notApplied);
    expect(
      changedByOther.classify('command-1', 4),
      PartyCommandRecovery.conflict,
    );
  });
}
