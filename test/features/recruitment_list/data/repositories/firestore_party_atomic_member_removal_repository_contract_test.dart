import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repository;
  late String router;

  setUpAll(() {
    repository = File(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_party_atomic_member_removal_repository.dart',
    ).readAsStringSync();
    router = File('lib/app/router/app_router.dart').readAsStringSync();
  });

  test('탈퇴·추방은 한 Transaction에서 대상 raidState와 공용 이벤트를 사용한다', () {
    expect(repository.split('runTransaction(').length - 1, 1);
    expect(repository, contains(".collection('raidStates')"));
    expect(repository, contains(".collection('partyEvents')"));
    expect(repository, contains('transaction.delete(targetMembershipRef)'));
    expect(repository, contains('transaction.delete(raidStateRef)'));
  });

  test('전원 조회·구 점유·개인 이벤트 fan-out을 사용하지 않는다', () {
    expect(repository, isNot(contains("collection('members').get(")));
    expect(repository, isNot(contains('activeRaidAssignments')));
    expect(repository, isNot(contains('weeklyRaidClaims')));
    expect(repository, isNot(contains(".collection('slots')")));
    expect(repository, isNot(contains(".collection('events')")));
  });

  test('운영 Router에 원자 탈퇴 Repository를 연결한다', () {
    expect(router, contains('FirestorePartyAtomicMemberRemovalRepository'));
  });
}
