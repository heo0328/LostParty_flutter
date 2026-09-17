import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repository;
  late String router;

  setUpAll(() {
    repository = File(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_party_atomic_command_repository.dart',
    ).readAsStringSync();
    router = File('lib/app/router/app_router.dart').readAsStringSync();
  });

  test('원자 Repository는 한 Transaction과 통합 raidState를 사용한다', () {
    expect(repository.split('runTransaction(').length - 1, 1);
    expect(repository, contains(".collection('raidStates')"));
    expect(repository, contains(".collection('partyEvents')"));
  });

  test('그룹 1회성 완료는 활성 수와 listing을 닫고 완료 후 해산은 이중 감소하지 않는다', () {
    expect(repository, contains('plan.closesActiveGroupRecruitment'));
    expect(repository, contains('PartyGroupListingWriteAction.delete'));
    expect(repository, contains('transaction.delete(listingRef)'));
  });

  test('기존 assignment Claim 개인 event fan-out을 사용하지 않는다', () {
    expect(repository, isNot(contains('activeRaidAssignments')));
    expect(repository, isNot(contains('weeklyRaidClaims')));
    expect(repository, isNot(contains(".collection('events')")));
    expect(repository, isNot(contains(".collection('members')")));
    expect(repository, isNot(contains(".collection('slots')")));
  });

  test('해산은 타인 raidState를 읽지 않고 전체 대상 삭제를 Rules에 맡긴다', () {
    expect(
      repository,
      contains('if (command.type != PartyAtomicCommandType.disband)'),
    );
    expect(repository, contains('transaction.delete(ref)'));
  });

  test('운영 Router에 원자 lifecycle Repository를 연결한다', () {
    expect(router, contains('FirestorePartyAtomicCommandRepository'));
    expect(router, contains('PartyAtomicCycleCommandAdapter'));
  });
}
