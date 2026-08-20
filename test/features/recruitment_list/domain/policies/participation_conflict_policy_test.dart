import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/active_raid_assignment.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/participation_conflict_policy.dart';

void main() {
  const policy = ParticipationConflictPolicy();

  test('같은 사용자는 본계정과 부계정 캐릭터로 같은 모집에 중복 참가할 수 없다', () {
    final decision = policy.evaluate(
      proposed: _assignment(
        characterId: '부계정바드',
        recruitmentId: 'party-a',
        raidId: 'serca',
      ),
      activeAssignments: [
        _assignment(
          characterId: '본계정블레이드',
          recruitmentId: 'party-a',
          raidId: 'kazeros-act4',
        ),
      ],
    );

    expect(decision.canConfirm, isFalse);
    expect(
      decision.conflicts.map((conflict) => conflict.type),
      contains(ParticipationConflictType.sameUserInRecruitment),
    );
  });

  test('같은 캐릭터는 시간이 달라도 동일 레이드의 다른 난이도에 확정 참가할 수 없다', () {
    final decision = policy.evaluate(
      proposed: _assignment(
        recruitmentId: 'hard-party',
        difficultyId: 'hard',
        startHour: 20,
        endHour: 22,
      ),
      activeAssignments: [
        _assignment(
          recruitmentId: 'normal-party',
          difficultyId: 'normal',
          startHour: 10,
        ),
      ],
    );

    expect(decision.canConfirm, isFalse);
    expect(
      decision.conflicts.map((conflict) => conflict.type),
      contains(ParticipationConflictType.sameCharacterAndRaid),
    );
  });

  test('같은 사용자의 다른 캐릭터도 시간이 겹치면 확정 참가할 수 없다', () {
    final decision = policy.evaluate(
      proposed: _assignment(
        characterId: '이슈하이',
        raidId: 'serca',
        recruitmentId: 'party-b',
        startHour: 11,
      ),
      activeAssignments: [
        _assignment(
          characterId: '이슈아이',
          raidId: 'kazeros-act4',
          recruitmentId: 'party-a',
          startHour: 10,
        ),
      ],
    );

    expect(decision.canConfirm, isFalse);
    expect(
      decision.conflicts.map((conflict) => conflict.type),
      contains(ParticipationConflictType.overlappingSchedule),
    );
  });

  test('종료 시각과 다음 시작 시각이 같으면 일정이 겹치지 않는다', () {
    final decision = policy.evaluate(
      proposed: _assignment(
        characterId: '이슈하이',
        raidId: 'serca',
        recruitmentId: 'party-b',
        startHour: 12,
        endHour: 14,
      ),
      activeAssignments: [_assignment(endHour: 12)],
    );

    expect(decision.canConfirm, isTrue);
  });

  test('종료 시각이 없는 일정은 확정 전에 해결해야 하는 충돌로 반환한다', () {
    final decision = policy.evaluate(
      proposed: _assignment(
        characterId: '이슈하이',
        raidId: 'serca',
        recruitmentId: 'party-b',
      ),
      activeAssignments: [_assignment(hasKnownEnd: false)],
    );

    expect(decision.canConfirm, isFalse);
    expect(decision.hasBlockingConflict, isFalse);
    expect(decision.requiresScheduleResolution, isTrue);
  });

  test('한쪽 종료 시각이 없어도 알려진 일정이 먼저 끝나면 충돌하지 않는다', () {
    final decision = policy.evaluate(
      proposed: _assignment(
        characterId: '이슈하이',
        raidId: 'serca',
        recruitmentId: 'party-b',
        startHour: 12,
        hasKnownEnd: false,
      ),
      activeAssignments: [_assignment(endHour: 12)],
    );

    expect(decision.canConfirm, isTrue);
  });

  test('다른 사용자의 참가 상태는 같은 모집과 일정이어도 충돌하지 않는다', () {
    final decision = policy.evaluate(
      proposed: _assignment(userId: 'user-b'),
      activeAssignments: [_assignment(userId: 'user-a')],
    );

    expect(decision.canConfirm, isTrue);
  });

  test('잘못된 일정 범위와 빈 식별자를 허용하지 않는다', () {
    expect(
      () => RaidParticipationSchedule(
        startAt: DateTime.utc(2026, 8, 20, 12),
        expectedEndAt: DateTime.utc(2026, 8, 20, 12),
      ),
      throwsArgumentError,
    );
    expect(() => _assignment(characterId: ' '), throwsArgumentError);
  });
}

ActiveRaidAssignment _assignment({
  String userId = 'user-a',
  String characterId = '이슈아이',
  String raidId = 'kazeros-act4',
  String difficultyId = 'normal',
  String recruitmentId = 'party-a',
  int startHour = 10,
  int endHour = 12,
  bool hasKnownEnd = true,
}) => ActiveRaidAssignment(
  userId: userId,
  characterId: characterId,
  raidId: raidId,
  difficultyId: difficultyId,
  recruitmentId: recruitmentId,
  schedule: RaidParticipationSchedule(
    startAt: DateTime.utc(2026, 8, 20, startHour),
    expectedEndAt: hasKnownEnd
        ? DateTime.utc(2026, 8, 20, endHour)
        : null,
  ),
);
