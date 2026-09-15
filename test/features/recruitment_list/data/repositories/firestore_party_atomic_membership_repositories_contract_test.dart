import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String createRepo;
  late String applicationRepo;
  late String joinRepo;
  late String mutationRepo;
  late String router;

  setUpAll(() {
    createRepo = File(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_party_atomic_create_repository.dart',
    ).readAsStringSync();
    applicationRepo = File(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_party_atomic_application_command_repository.dart',
    ).readAsStringSync();
    joinRepo = File(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_party_atomic_join_command_repository.dart',
    ).readAsStringSync();
    mutationRepo = File(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_party_atomic_member_mutation_repository.dart',
    ).readAsStringSync();
    router = File('lib/app/router/app_router.dart').readAsStringSync();
  });

  test('생성은 raidState·공용 이벤트·그룹 활성 수를 쓰고 slots·assignment를 쓰지 않는다', () {
    expect(createRepo.split('runTransaction(').length - 1, 1);
    expect(createRepo, contains(".collection('raidStates')"));
    expect(createRepo, contains(".collection('partyEvents')"));
    expect(createRepo, contains('GroupActiveRecruitmentWritePlan.open'));
    expect(createRepo, isNot(contains('activeRaidAssignments')));
    expect(createRepo, isNot(contains('weeklyRaidClaims')));
    expect(createRepo, isNot(contains(".collection('slots')")));
    expect(createRepo, isNot(contains(".collection('events')")));
  });

  test('신청·재신청·철회는 pending 집계와 공용 이벤트만 갱신한다', () {
    expect(applicationRepo.split('runTransaction(').length - 1, 1);
    expect(applicationRepo, contains('PartyAtomicApplicationWritePlan.apply'));
    expect(applicationRepo, contains('PartyAtomicApplicationWritePlan.withdraw'));
    expect(applicationRepo, contains('PartyApplicationWritePlan.reapply'));
    expect(applicationRepo, contains(".collection('partyEvents')"));
    expect(applicationRepo, isNot(contains('activeRaidAssignments')));
    expect(applicationRepo, isNot(contains(".collection('events')")));
  });

  test('가입·승인·거절은 Aggregate 슬롯으로 배치하고 전원 members.get을 쓰지 않는다', () {
    expect(joinRepo.split('runTransaction(').length - 1, 1);
    expect(joinRepo, contains('PartyAtomicJoinWritePlan.fromBase'));
    expect(joinRepo, contains('PartyAtomicApprovalWritePlan'));
    expect(joinRepo, contains('PartyAtomicApplicationRejectWritePlan'));
    expect(joinRepo, contains(".collection('raidStates')"));
    expect(joinRepo, contains(".collection('partyEvents')"));
    expect(joinRepo, isNot(contains("collection('members').get(")));
    expect(joinRepo, isNot(contains('activeRaidAssignments')));
    expect(joinRepo, isNot(contains('weeklyRaidClaims')));
    expect(joinRepo, isNot(contains(".collection('events')")));
  });

  test('캐릭터 변경·자리 이동은 대상 문서만 읽고 개인 event fan-out을 쓰지 않는다', () {
    expect(mutationRepo.split('runTransaction(').length - 1, 1);
    expect(mutationRepo, contains('PartyAtomicCharacterChangeWritePlan'));
    expect(mutationRepo, contains('PartyAtomicRepositionWritePlan'));
    expect(mutationRepo, contains(".collection('raidStates')"));
    expect(mutationRepo, contains(".collection('partyEvents')"));
    expect(mutationRepo, isNot(contains("collection('members').get(")));
    expect(mutationRepo, isNot(contains('activeRaidAssignments')));
    expect(mutationRepo, isNot(contains('weeklyRaidClaims')));
    expect(mutationRepo, isNot(contains(".collection('events')")));
  });

  test('운영 Router에 원자 생성·신청·가입·mutation Repository를 연결한다', () {
    expect(router, contains('FirestorePartyAtomicCreateRepository'));
    expect(router, contains('FirestorePartyAtomicApplicationCommandRepository'));
    expect(router, contains('FirestorePartyAtomicJoinCommandRepository'));
    expect(router, contains('FirestorePartyAtomicMemberMutationRepository'));
    expect(router, contains('PartyAtomicMembershipCommandAdapter'));
  });
}
