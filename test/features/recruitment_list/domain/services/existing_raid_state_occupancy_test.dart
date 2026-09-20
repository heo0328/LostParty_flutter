import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_create_occupancy_gate.dart';

void main() {
  test('없는 모집을 가리키는 이전 주차 active는 historical orphan이다', () {
    expect(
      _classify(recruitmentExists: false),
      ExistingRaidStateOccupancyDecision.historicalOrphanActive,
    );
  });

  test('수명이 끝난 이전 주차 1회성 모집은 historical orphan이다', () {
    expect(
      _classify(recruitmentCycleEndsAt: DateTime.utc(2026, 9, 8, 21)),
      ExistingRaidStateOccupancyDecision.historicalOrphanActive,
    );
  });

  test('유효한 반복 모집의 이전 주차 active는 정리하지 않는다', () {
    expect(
      _classify(recruitmentContinuesTogether: true),
      ExistingRaidStateOccupancyDecision.participationConflict,
    );
  });

  test('state와 모집 주차가 다르면 만료만으로 정리하지 않는다', () {
    expect(
      _classify(
        recruitmentCycleKey: '2026-09-09',
        recruitmentCycleEndsAt: DateTime.utc(2026, 9, 8, 21),
      ),
      ExistingRaidStateOccupancyDecision.participationConflict,
    );
  });

  test('이전 주차 completed는 orphan이 아닌 rollover 대상이다', () {
    expect(
      _classify(stateStatus: 'completed'),
      ExistingRaidStateOccupancyDecision.historicalCompleted,
    );
  });

  test('현재 주차의 없는 모집 참가는 기존 current orphan으로 유지한다', () {
    expect(
      _classify(stateCycleKey: '2026-09-09', recruitmentExists: false),
      ExistingRaidStateOccupancyDecision.currentOrphanActive,
    );
  });
}

ExistingRaidStateOccupancyDecision _classify({
  String requestedCycleKey = '2026-09-09',
  String stateCycleKey = '2026-09-02',
  String stateStatus = 'active',
  bool recruitmentExists = true,
  String? recruitmentStatus = 'active',
  String? recruitmentCycleStatus = 'active',
  String? recruitmentCycleKey = '2026-09-02',
  bool recruitmentContinuesTogether = false,
  DateTime? recruitmentCycleEndsAt,
}) => PartyCreateOccupancyGate.classifyExistingRaidState(
  requestedCycleKey: requestedCycleKey,
  stateCycleKey: stateCycleKey,
  stateStatus: stateStatus,
  recruitmentExists: recruitmentExists,
  recruitmentStatus: recruitmentStatus,
  recruitmentCycleStatus: recruitmentCycleStatus,
  recruitmentCycleKey: recruitmentCycleKey,
  recruitmentContinuesTogether: recruitmentContinuesTogether,
  recruitmentCycleEndsAt: recruitmentCycleEndsAt,
  now: DateTime.utc(2026, 9, 9),
);
