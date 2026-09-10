import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_cycle_assignment_write_plan.dart';

void main() {
  test('반복방의 이전 회차 점유는 새 회차로 갱신한다', () {
    expect(
      _decide(continueTogether: true),
      PartyCycleAssignmentAction.update,
    );
  });

  test('반복방 assignment가 없으면 새 회차 점유를 만든다', () {
    expect(
      _decide(continueTogether: true, assignmentExists: false),
      PartyCycleAssignmentAction.create,
    );
  });

  test('1회성 방의 이전 회차 점유는 삭제한다', () {
    expect(
      _decide(continueTogether: false),
      PartyCycleAssignmentAction.delete,
    );
  });

  test('1회성 방 종료가 다른 새 방의 점유를 삭제하지 않는다', () {
    expect(
      _decide(
        continueTogether: false,
        assignmentRecruitmentId: 'new-room',
      ),
      PartyCycleAssignmentAction.skip,
    );
  });

  test('반복방 승계가 다른 새 방의 점유를 덮어쓰지 않는다', () {
    expect(
      _decide(
        continueTogether: true,
        assignmentRecruitmentId: 'new-room',
      ),
      PartyCycleAssignmentAction.conflict,
    );
  });

  test('알 수 없는 회차의 같은 방 점유는 안전하게 충돌 처리한다', () {
    expect(
      _decide(continueTogether: true, assignmentCycleKey: '2026-08-26'),
      PartyCycleAssignmentAction.conflict,
    );
  });

  test('이미 목표 회차로 승계된 반복방 점유는 no-op다', () {
    expect(
      _decide(continueTogether: true, assignmentCycleKey: '2026-09-09'),
      PartyCycleAssignmentAction.skip,
    );
  });
}

PartyCycleAssignmentAction _decide({
  required bool continueTogether,
  bool assignmentExists = true,
  String assignmentRecruitmentId = 'old-room',
  String assignmentCycleKey = '2026-09-02',
}) => PartyCycleAssignmentWritePlan.decide(
  continueTogether: continueTogether,
  assignmentExists: assignmentExists,
  assignmentRecruitmentId: assignmentRecruitmentId,
  assignmentCycleKey: assignmentCycleKey,
  recruitmentId: 'old-room',
  oldCycleKey: '2026-09-02',
  targetCycleKey: '2026-09-09',
);
