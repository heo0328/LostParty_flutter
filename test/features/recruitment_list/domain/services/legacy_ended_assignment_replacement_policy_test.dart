import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/services/legacy_ended_assignment_replacement_policy.dart';

void main() {
  const policy = LegacyEndedAssignmentReplacementPolicy();

  bool decide({
    String status = 'incompleteEnded',
    String cycleStatus = 'incompleteEnded',
    bool continuesTogether = false,
    String assignmentCycleKey = '2026-09-02',
    String assignedCycleKey = '2026-09-02',
    String newCycleKey = '2026-09-09',
    String assignmentRaidId = 'raid-1',
    String newRaidId = 'raid-1',
  }) => policy.canReplace(
    assignmentExists: true,
    assignmentRecruitmentId: 'old-room',
    assignmentCycleKey: assignmentCycleKey,
    assignmentRaidId: assignmentRaidId,
    assignedRecruitmentExists: true,
    assignedRecruitmentStatus: status,
    assignedRecruitmentCycleStatus: cycleStatus,
    assignedRecruitmentCycleKey: assignedCycleKey,
    assignedRecruitmentContinuesTogether: continuesTogether,
    newRecruitmentId: 'new-room',
    newCycleKey: newCycleKey,
    newRaidId: newRaidId,
  );

  test('이전 주차 1회성 미완료 종료 점유는 새 방 점유로 교체한다', () {
    expect(decide(), isTrue);
  });

  test('반복방과 활성 방 점유는 교체하지 않는다', () {
    expect(decide(continuesTogether: true), isFalse);
    expect(decide(status: 'active', cycleStatus: 'active'), isFalse);
  });

  test('점유와 이전 방 회차가 다르면 안전하게 차단한다', () {
    expect(decide(assignedCycleKey: '2026-08-26'), isFalse);
  });

  test('현재 주차 또는 다른 레이드 점유는 교체하지 않는다', () {
    expect(decide(assignmentCycleKey: '2026-09-09'), isFalse);
    expect(decide(newRaidId: 'raid-2'), isFalse);
  });
}
