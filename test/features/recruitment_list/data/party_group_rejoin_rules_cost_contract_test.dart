import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('그룹 재가입 네 쓰기는 값싼 marker 뒤 기존 validator를 먼저 평가한다', () {
    final recruitment = _between(
      rules,
      'match /recruitments/{recruitmentId}',
      'match /members/{playerId}',
    );
    expect(
      recruitment,
      contains(
        'request.resource.data.memberCount\n'
        '          == resource.data.memberCount + 1\n'
        '        && validAtomicRecruitmentJoin(',
      ),
    );
    expect(
      recruitment.indexOf('validAtomicRecruitmentJoin('),
      lessThan(recruitment.indexOf('validRecurrenceChange(')),
    );

    final members = _between(
      rules,
      'match /members/{playerId}',
      'match /slots/{slotId}',
    );
    expect(
      members,
      contains(
        'request.resource.data.canApproveApplications == false\n'
        '          && validAtomicJoinedMembership(',
      ),
    );
    expect(
      members.indexOf('validAtomicJoinedMembership('),
      lessThan(members.indexOf('validAtomicInitialLeaderMembership(')),
    );

    final states = _between(
      rules,
      'match /raidStates/{stateId}',
      'match /characterActivity/{characterId}',
    );
    expect(states, contains("request.resource.data.source == 'party'"));
    expect(states, contains("'createdAt' in request.resource.data"));
    expect(
      states.indexOf('validAtomicRaidStateCreate('),
      lessThan(states.indexOf('validAtomicAdvanceRaidStateCreate(')),
    );

    final listings = _between(
      rules,
      'match /raidListings/{recruitmentId}',
      'match /joinRelations/{playerId}',
    );
    expect(listings, contains("!('sourceRevision' in request.resource.data)"));
    expect(
      listings.indexOf('validGroupRaidListingCreate('),
      lessThan(listings.indexOf('validPersonalCompletionListingUpdate(')),
    );
  });

  test('marker는 상세 권한·소유권·점유·원본 일치 검증을 대체하지 않는다', () {
    expect(rules, contains('function validAtomicRecruitmentJoin('));
    expect(rules, contains('function validAtomicJoinedMembership('));
    expect(rules, contains('isCurrentGroupMember(before.groupId)'));
    expect(rules, contains('ownsActiveCharacterForPlayer('));
    expect(rules, contains('!hasWeeklyRaidCompletionAfter('));
    expect(
      rules,
      contains('data.diff(recruitment).affectedKeys().size() == 0'),
    );
  });
}

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  return source.substring(startIndex, endIndex);
}
