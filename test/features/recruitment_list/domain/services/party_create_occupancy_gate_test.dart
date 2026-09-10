import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_create_occupancy_gate.dart';

void main() {
  test('같은 생성 Transaction 재시도는 이미 만든 방으로 성공한다', () {
    expect(
      _decide(
        newRecruitmentId: 'raid-1',
        playerId: 'p1',
        newRecruitmentExists: true,
        newRecruitmentLeaderId: 'p1',
        assignmentRecruitmentId: 'raid-1',
        assignedRecruitmentExists: true,
        assignedRecruitmentStatus: 'active',
      ),
      PartyCreateOccupancyDecision.alreadyCreated,
    );
  });

  test('해산된 방의 남은 점유는 새 생성으로 교체한다', () {
    expect(
      _decide(
        newRecruitmentId: 'raid-2',
        playerId: 'p1',
        newRecruitmentExists: false,
        newRecruitmentLeaderId: null,
        assignmentRecruitmentId: 'raid-1',
        assignedRecruitmentExists: true,
        assignedRecruitmentStatus: 'disbanded',
      ),
      PartyCreateOccupancyDecision.replaceStaleAssignment,
    );
  });

  test('없는 모집을 가리키는 점유도 교체한다', () {
    expect(
      _decide(
        newRecruitmentId: 'raid-2',
        playerId: 'p1',
        newRecruitmentExists: false,
        newRecruitmentLeaderId: null,
        assignmentRecruitmentId: 'raid-1',
        assignedRecruitmentExists: false,
        assignedRecruitmentStatus: null,
      ),
      PartyCreateOccupancyDecision.replaceStaleAssignment,
    );
  });

  test('다른 활성 방 점유는 참가 충돌이다', () {
    expect(
      _decide(
        newRecruitmentId: 'raid-2',
        playerId: 'p1',
        newRecruitmentExists: false,
        newRecruitmentLeaderId: null,
        assignmentRecruitmentId: 'raid-1',
        assignedRecruitmentExists: true,
        assignedRecruitmentStatus: 'active',
      ),
      PartyCreateOccupancyDecision.participationConflict,
    );
  });

  test('만료된 1회성 이전 주차 점유만 새 주차 생성으로 교체한다', () {
    expect(
      _decide(
        newRecruitmentId: 'new-room',
        assignmentRecruitmentId: 'old-room',
        assignmentCycleKey: '2026-09-02',
        assignedRecruitmentCycleKey: '2026-09-02',
        assignedRecruitmentCycleEndsAt: DateTime.utc(2026, 9, 8, 21),
        now: DateTime.utc(2026, 9, 8, 21),
      ),
      PartyCreateOccupancyDecision.replaceStaleAssignment,
    );
  });

  test('만료됐어도 반복방 점유는 새 주차의 다른 방 생성을 차단한다', () {
    expect(
      _decide(
        newRecruitmentId: 'new-room',
        assignmentRecruitmentId: 'repeat-room',
        assignmentCycleKey: '2026-09-02',
        assignedRecruitmentCycleKey: '2026-09-02',
        assignedRecruitmentContinuesTogether: true,
        assignedRecruitmentCycleEndsAt: DateTime.utc(2026, 9, 8, 21),
        now: DateTime.utc(2026, 9, 8, 21),
      ),
      PartyCreateOccupancyDecision.participationConflict,
    );
  });

  test('현재 주차 활성 점유는 동일 레이드의 다른 난이도 생성도 차단한다', () {
    expect(
      _decide(
        newRecruitmentId: 'hard-room',
        assignmentRecruitmentId: 'normal-room',
        assignmentCycleKey: '2026-09-09',
        assignedRecruitmentCycleKey: '2026-09-09',
        assignedRecruitmentCycleEndsAt: DateTime.utc(2026, 9, 15, 21),
        now: DateTime.utc(2026, 9, 9),
      ),
      PartyCreateOccupancyDecision.participationConflict,
    );
  });

  test('assignment와 모집 회차가 어긋나면 임의로 stale 처리하지 않는다', () {
    expect(
      _decide(
        newRecruitmentId: 'new-room',
        assignmentRecruitmentId: 'old-room',
        assignmentCycleKey: '2026-08-26',
        assignedRecruitmentCycleKey: '2026-09-02',
        assignedRecruitmentCycleEndsAt: DateTime.utc(2026, 9, 8, 21),
        now: DateTime.utc(2026, 9, 9),
      ),
      PartyCreateOccupancyDecision.participationConflict,
    );
  });
}

PartyCreateOccupancyDecision _decide({
  required String newRecruitmentId,
  String playerId = 'p1',
  bool newRecruitmentExists = false,
  String? newRecruitmentLeaderId,
  bool assignmentExists = true,
  String? assignmentRecruitmentId,
  String? assignmentCycleKey = '2026-09-09',
  bool assignedRecruitmentExists = true,
  String? assignedRecruitmentStatus = 'active',
  String? assignedRecruitmentCycleKey = '2026-09-09',
  bool assignedRecruitmentContinuesTogether = false,
  DateTime? assignedRecruitmentCycleEndsAt,
  String newCycleKey = '2026-09-09',
  DateTime? now,
}) => PartyCreateOccupancyGate.decide(
  newRecruitmentId: newRecruitmentId,
  playerId: playerId,
  newRecruitmentExists: newRecruitmentExists,
  newRecruitmentLeaderId: newRecruitmentLeaderId,
  assignmentExists: assignmentExists,
  assignmentRecruitmentId: assignmentRecruitmentId,
  assignmentCycleKey: assignmentCycleKey,
  assignedRecruitmentExists: assignedRecruitmentExists,
  assignedRecruitmentStatus: assignedRecruitmentStatus,
  assignedRecruitmentCycleKey: assignedRecruitmentCycleKey,
  assignedRecruitmentContinuesTogether: assignedRecruitmentContinuesTogether,
  assignedRecruitmentCycleEndsAt: assignedRecruitmentCycleEndsAt,
  newCycleKey: newCycleKey,
  now: now ?? DateTime.utc(2026, 9, 9),
);
