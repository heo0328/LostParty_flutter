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

  test('기존 assignment Claim 개인 event fan-out을 사용하지 않는다', () {
    expect(repository, isNot(contains('activeRaidAssignments')));
    expect(repository, isNot(contains('weeklyRaidClaims')));
    expect(repository, isNot(contains(".collection('events')")));
    expect(repository, isNot(contains(".collection('members')")));
    expect(repository, isNot(contains(".collection('slots')")));
  });

  test('검증 단계에서는 운영 Router에 새 Repository를 연결하지 않는다', () {
    expect(router, isNot(contains('FirestorePartyAtomicCommandRepository')));
  });
}
