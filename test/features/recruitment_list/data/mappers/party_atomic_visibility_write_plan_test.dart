import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_atomic_visibility_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_atomic_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_create_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';

void main() {
  final timestamp = Object();

  test('공개에서 그룹 전용 전환은 집계만으로 자격을 판정하고 활성 수를 증가시킨다', () {
    final plan = PartyAtomicVisibilityWritePlan(
      aggregate: _aggregate(),
      nextVisibility: RecruitmentVisibility.group,
      groupActiveRecruitmentCount: 1,
      groupRevision: 4,
      serverTimestamp: timestamp,
    );

    expect(plan.recruitmentPatch['visibility'], 'group');
    expect(plan.recruitmentPatch['revision'], 8);
    expect(plan.groupPatch['activeRecruitmentCount'], 2);
  });

  test('그룹 전용에서 공개 전환은 listing 삭제와 활성 수 감소를 함께 계획한다', () {
    final plan = PartyAtomicVisibilityWritePlan(
      aggregate: _aggregate(visibility: RecruitmentVisibility.group),
      nextVisibility: RecruitmentVisibility.public,
      groupActiveRecruitmentCount: 1,
      groupRevision: 4,
      serverTimestamp: timestamp,
    );

    expect(plan.groupPatch['activeRecruitmentCount'], 0);
  });

  test('비그룹 참가자 또는 신청자가 있으면 그룹 전용 전환을 거절한다', () {
    expect(
      () => PartyAtomicVisibilityWritePlan(
        aggregate: _aggregate(nonGroupMembers: 1),
        nextVisibility: RecruitmentVisibility.group,
        groupActiveRecruitmentCount: 0,
        groupRevision: 4,
        serverTimestamp: timestamp,
      ),
      throwsStateError,
    );
    expect(
      () => PartyAtomicVisibilityWritePlan(
        aggregate: _aggregate(pendingNonGroup: 1),
        nextVisibility: RecruitmentVisibility.group,
        groupActiveRecruitmentCount: 0,
        groupRevision: 4,
        serverTimestamp: timestamp,
      ),
      throwsStateError,
    );
  });
}

PartyCommandAggregate _aggregate({
  String visibility = RecruitmentVisibility.public,
  int nonGroupMembers = 0,
  int pendingNonGroup = 0,
}) => PartyCommandAggregate(
  recruitmentId: 'recruitment-1',
  raidId: 'raid-1',
  difficultyId: 'hard',
  leaderPlayerId: 'leader',
  currentCycleKey: '2026-09-09',
  currentCycleStatus: PartyRaidStateStatus.active,
  revision: 7,
  partySlots: [
    PartyAggregateSlot(
      playerId: 'leader',
      characterId: 'leader-character',
      role: PartyRole.support,
      classKey: '바드:지원',
      partyIndex: 0,
      slotIndex: 0,
      countedAsNonGroupMember: nonGroupMembers == 1,
    ),
  ],
  nonGroupMemberCount: nonGroupMembers,
  pendingApplicationCount: pendingNonGroup,
  pendingNonGroupApplicantCount: pendingNonGroup,
  groupId: 'group-1',
  visibility: visibility,
);
