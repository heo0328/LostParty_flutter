import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_raid_listing_sync.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_create_command.dart';

Map<String, Object?> _groupRaid({String status = 'active'}) => {
  'schemaVersion': 1,
  'title': '방',
  'visibility': RecruitmentVisibility.group,
  'groupId': 'group-1',
  'status': status,
  'currentCycleStatus': 'active',
  'memberCount': 2,
  'maxMemberCount': 8,
  'hasAvailableSlot': true,
  'revision': 4,
};

void main() {
  test('그룹 전용 인원 변경은 listing을 원본 스냅샷으로 덮어쓴다', () {
    final plan = PartyRaidListingSyncPlan.afterRecruitmentChange(
      currentRecruitment: _groupRaid(),
      recruitmentPatch: {
        'memberCount': 3,
        'hasAvailableSlot': true,
        'revision': 5,
        'updatedAt': 'ts',
      },
    );

    expect(plan.deleteListing, isFalse);
    expect(plan.listingDocument?['memberCount'], 3);
    expect(plan.listingDocument?['title'], '방');
    expect(plan.listingDocument?['revision'], 5);
    expect(plan.listingDocument?['visibility'], RecruitmentVisibility.group);
  });

  test('만석과 회차 완료는 listing을 유지하고 최신 상태로 덮어쓴다', () {
    final full = PartyRaidListingSyncPlan.afterRecruitmentChange(
      currentRecruitment: _groupRaid(),
      recruitmentPatch: {
        'memberCount': 8,
        'hasAvailableSlot': false,
        'revision': 5,
      },
    );
    expect(full.deleteListing, isFalse);
    expect(full.listingDocument?['hasAvailableSlot'], isFalse);

    final completed = PartyRaidListingSyncPlan.afterRecruitmentChange(
      currentRecruitment: _groupRaid(),
      recruitmentPatch: {
        'status': 'active',
        'currentCycleStatus': 'completed',
        'manualRecruitmentEnabled': true,
        'revision': 5,
      },
    );
    expect(completed.deleteListing, isFalse);
    expect(completed.listingDocument?['currentCycleStatus'], 'completed');
  });

  test('전체 공개 전환과 해산은 listing을 삭제한다', () {
    final toPublic = PartyRaidListingSyncPlan.afterRecruitmentChange(
      currentRecruitment: _groupRaid(),
      recruitmentPatch: {'visibility': RecruitmentVisibility.public},
    );
    expect(toPublic.deleteListing, isTrue);
    expect(toPublic.listingDocument, isNull);

    final disbanded = PartyRaidListingSyncPlan.afterRecruitmentChange(
      currentRecruitment: _groupRaid(),
      recruitmentPatch: {
        'status': 'disbanded',
        'currentCycleStatus': 'disbanded',
        'leaderPlayerId': null,
      },
    );
    expect(disbanded.deleteListing, isTrue);
  });

  test('이미 전체 공개인 방은 listing을 건드리지 않는다', () {
    final plan = PartyRaidListingSyncPlan.afterRecruitmentChange(
      currentRecruitment: {
        ..._groupRaid(),
        'visibility': RecruitmentVisibility.public,
      },
      recruitmentPatch: {'memberCount': 3, 'revision': 5},
    );
    expect(plan.deleteListing, isFalse);
    expect(plan.listingDocument, isNull);
  });

  test('listing이 없던 그룹 전용 방도 변경 시 생성한다', () {
    final plan = PartyRaidListingSyncPlan.afterRecruitmentChange(
      currentRecruitment: _groupRaid(),
      recruitmentPatch: {'revision': 5, 'updatedAt': 'ts'},
    );
    expect(plan.listingDocument?['revision'], 5);
    expect(plan.deleteListing, isFalse);
  });

  test('기존 listing 참가 갱신은 모집 patch 전체와 sourceRevision을 사용한다', () {
    final patch = partyRaidListingJoinPatch({
      'memberPlayerIds': ['p1', 'p2'],
      'memberCount': 2,
      'partySlots': const [],
      'revision': 5,
      'updatedAt': 'ts',
    });

    expect(patch['memberPlayerIds'], ['p1', 'p2']);
    expect(patch['memberCount'], 2);
    expect(patch['revision'], 5);
    expect(patch['sourceRevision'], 5);
    expect(patch['updatedAt'], 'ts');
  });
}
