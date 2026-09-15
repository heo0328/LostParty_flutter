import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String visibilityRepo;
  late String groupJoinRepo;
  late String groupCreatePlan;
  late String router;

  setUpAll(() {
    visibilityRepo = File(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_party_atomic_visibility_command_repository.dart',
    ).readAsStringSync();
    groupJoinRepo = File(
      'lib/features/group/data/repositories/'
      'firestore_group_join_command_repository.dart',
    ).readAsStringSync();
    groupCreatePlan = File(
      'lib/features/group/data/mappers/group_create_write_plan.dart',
    ).readAsStringSync();
    router = File('lib/app/router/app_router.dart').readAsStringSync();
  });

  test('공개↔그룹 전환은 Aggregate 집계와 그룹 활성 수만 사용한다', () {
    expect(visibilityRepo.split('runTransaction(').length - 1, 1);
    expect(visibilityRepo, contains('PartyAtomicVisibilityWritePlan'));
    expect(visibilityRepo, contains('canBecomeGroupOnly'));
    expect(visibilityRepo, contains('activeRecruitmentCount'));
    expect(visibilityRepo, isNot(contains('memberPlayerIds')));
    expect(visibilityRepo, isNot(contains("where('status', isEqualTo: 'pending')")));
    expect(visibilityRepo, isNot(contains('limit(20)')));
  });

  test('그룹 해산은 raidListings 순회 대신 activeRecruitmentCount를 검사한다', () {
    expect(groupJoinRepo, contains('GroupActiveRecruitmentWritePlan.validateDisband'));
    expect(groupJoinRepo, contains("data()?['activeRecruitmentCount']"));
    expect(groupJoinRepo, isNot(contains("collection('raidListings').limit(20)")));
    expect(groupJoinRepo, isNot(contains('isBlockingActiveGroupRaid')));
  });

  test('그룹 생성은 activeRecruitmentCount 0으로 시작한다', () {
    expect(groupCreatePlan, contains("'activeRecruitmentCount': 0"));
  });

  test('운영 Router에 원자 visibility Repository를 연결한다', () {
    expect(
      router,
      contains('FirestorePartyAtomicVisibilityCommandRepository'),
    );
  });
}
