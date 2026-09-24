import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repository;
  late String router;
  late String rules;

  setUpAll(() {
    repository = File(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_party_atomic_member_removal_repository.dart',
    ).readAsStringSync();
    router = File('lib/app/router/app_router.dart').readAsStringSync();
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
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

  test('추방은 타인의 개인 raidState 읽기 없이 서버 삭제 검증을 사용한다', () {
    expect(
      repository,
      contains('if (command.targetPlayerId == actorPlayerId)'),
    );
    expect(
      repository,
      contains('final raidState = await transaction.get(raidStateRef)'),
    );
    expect(repository, contains('transaction.delete(raidStateRef)'));
  });

  test('그룹방 참가자 제거는 listing의 인원·revision·시각만 함께 갱신한다', () {
    expect(repository, contains(".collection('raidListings')"));
    expect(repository, contains("'memberCount': aggregate.memberCount - 1"));
    expect(repository, contains("'sourceRevision': aggregate.revision + 1"));
    expect(repository, contains("'updatedAt': now"));

    final start = rules.indexOf(
      'function validAtomicMemberRemovalListingUpdate(',
    );
    final end = rules.indexOf(
      'function validPersonalCompletionSuccessor(',
      start,
    );
    final listingRule = rules.substring(start, end);
    expect(listingRule, contains('validAtomicRecruitmentMemberRemoval('));
    expect(
      listingRule,
      contains(
        "newData.diff(oldData).affectedKeys().hasOnly([\n"
        "          'memberCount', 'sourceRevision', 'updatedAt'\n"
        '        ])',
      ),
    );
    expect(
      listingRule,
      contains('newData.memberCount == recruitmentAfter.memberCount'),
    );
    expect(
      listingRule,
      contains('newData.sourceRevision == recruitmentAfter.revision'),
    );
    expect(
      rules,
      contains(
        'validAtomicMemberRemovalListingUpdate(\n'
        '          groupId,\n'
        '          recruitmentId,',
      ),
    );
  });

  test('그룹 listing 전체 동기화는 부분 갱신 validator보다 먼저 평가한다', () {
    final start = rules.indexOf('match /raidListings/{recruitmentId}');
    final end = rules.indexOf('match /joinRelations/{playerId}', start);
    final listingMatch = rules.substring(start, end);
    expect(
      listingMatch,
      contains('allow update: if validGroupRaidListingCreate('),
    );
    expect(
      listingMatch.indexOf('validGroupRaidListingCreate('),
      lessThan(
        listingMatch.indexOf('validAtomicMemberRemovalListingUpdate('),
      ),
    );
  });

  test('운영 Router에 원자 탈퇴 Repository를 연결한다', () {
    expect(router, contains('FirestorePartyAtomicMemberRemovalRepository'));
  });
}
