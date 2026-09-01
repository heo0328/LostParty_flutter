import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_create_occupancy_gate.dart';

void main() {
  test('같은 생성 Transaction 재시도는 이미 만든 방으로 성공한다', () {
    expect(
      PartyCreateOccupancyGate.decide(
        newRecruitmentId: 'raid-1',
        playerId: 'p1',
        newRecruitmentExists: true,
        newRecruitmentLeaderId: 'p1',
        assignmentExists: true,
        assignmentRecruitmentId: 'raid-1',
        assignedRecruitmentExists: true,
        assignedRecruitmentStatus: 'active',
      ),
      PartyCreateOccupancyDecision.alreadyCreated,
    );
  });

  test('해산된 방의 남은 점유는 새 생성으로 교체한다', () {
    expect(
      PartyCreateOccupancyGate.decide(
        newRecruitmentId: 'raid-2',
        playerId: 'p1',
        newRecruitmentExists: false,
        newRecruitmentLeaderId: null,
        assignmentExists: true,
        assignmentRecruitmentId: 'raid-1',
        assignedRecruitmentExists: true,
        assignedRecruitmentStatus: 'disbanded',
      ),
      PartyCreateOccupancyDecision.replaceStaleAssignment,
    );
  });

  test('없는 모집을 가리키는 점유도 교체한다', () {
    expect(
      PartyCreateOccupancyGate.decide(
        newRecruitmentId: 'raid-2',
        playerId: 'p1',
        newRecruitmentExists: false,
        newRecruitmentLeaderId: null,
        assignmentExists: true,
        assignmentRecruitmentId: 'raid-1',
        assignedRecruitmentExists: false,
        assignedRecruitmentStatus: null,
      ),
      PartyCreateOccupancyDecision.replaceStaleAssignment,
    );
  });

  test('다른 활성 방 점유는 참가 충돌이다', () {
    expect(
      PartyCreateOccupancyGate.decide(
        newRecruitmentId: 'raid-2',
        playerId: 'p1',
        newRecruitmentExists: false,
        newRecruitmentLeaderId: null,
        assignmentExists: true,
        assignmentRecruitmentId: 'raid-1',
        assignedRecruitmentExists: true,
        assignedRecruitmentStatus: 'active',
      ),
      PartyCreateOccupancyDecision.participationConflict,
    );
  });
}
