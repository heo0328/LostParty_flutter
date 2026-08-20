import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/active_raid_assignment.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/participation_conflict_policy.dart';

void main() {
  test('최초 확정만 저장하고 충돌하는 두 번째 확정을 거절한다', () async {
    final repository = InMemoryActiveRaidAssignmentRepository();
    final first = _assignment(recruitmentId: 'party-a');
    final second = _assignment(
      recruitmentId: 'party-b',
      difficultyId: 'hard',
      startHour: 20,
      endHour: 22,
    );

    expect((await repository.acquire(first)).isSuccess, isTrue);
    final rejected = await repository.acquire(second);

    expect(rejected.isSuccess, isFalse);
    expect(
      rejected.decision.conflicts.map((conflict) => conflict.type),
      contains(ParticipationConflictType.sameCharacterAndRaid),
    );
    expect(await repository.getByUser('user-a'), [first]);
  });

  test('정확한 모집만 확정 점유를 해제할 수 있다', () async {
    final repository = InMemoryActiveRaidAssignmentRepository();
    final assignment = _assignment();
    await repository.acquire(assignment);

    expect(
      await repository.release(
        userId: assignment.userId,
        characterId: assignment.characterId,
        raidId: assignment.raidId,
        recruitmentId: 'other-party',
      ),
      isFalse,
    );
    expect(
      await repository.release(
        userId: assignment.userId,
        characterId: assignment.characterId,
        raidId: assignment.raidId,
        recruitmentId: assignment.recruitmentId,
      ),
      isTrue,
    );
    expect(await repository.getByUser(assignment.userId), isEmpty);
  });

  test('서로 충돌하지 않는 확정 참가는 함께 저장한다', () async {
    final repository = InMemoryActiveRaidAssignmentRepository();
    final first = _assignment();
    final second = _assignment(
      characterId: '이슈하이',
      raidId: 'serca',
      recruitmentId: 'party-b',
      startHour: 12,
      endHour: 14,
    );

    expect((await repository.acquire(first)).isSuccess, isTrue);
    expect((await repository.acquire(second)).isSuccess, isTrue);
    expect(await repository.getByUser('user-a'), hasLength(2));
  });

  test('같은 모집의 캐릭터 점유를 원자적으로 교체한다', () async {
    final repository = InMemoryActiveRaidAssignmentRepository();
    final current = _assignment();
    final replacement = _assignment(characterId: '이슈하이');
    await repository.acquire(current);

    final result = await repository.replace(
      current: current,
      replacement: replacement,
    );

    expect(result.isSuccess, isTrue);
    expect(await repository.getByUser('user-a'), [replacement]);
  });
}

ActiveRaidAssignment _assignment({
  String characterId = '이슈아이',
  String raidId = 'kazeros-act4',
  String difficultyId = 'normal',
  String recruitmentId = 'party-a',
  int startHour = 10,
  int endHour = 12,
}) => ActiveRaidAssignment(
  userId: 'user-a',
  characterId: characterId,
  raidId: raidId,
  difficultyId: difficultyId,
  recruitmentId: recruitmentId,
  schedule: RaidParticipationSchedule(
    startAt: DateTime.utc(2026, 8, 20, startHour),
    expectedEndAt: DateTime.utc(2026, 8, 20, endHour),
  ),
);
