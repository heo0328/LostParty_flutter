import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('활동 Character 쓰기는 캐릭터별 문서에서 소유권과 대표 해제를 검증한다', () {
    expect(rules, contains('match /characterActivity/{characterId}'));
    expect(rules, contains('validCharacterActivityWrite'));
    expect(rules, contains('validCharacterActivityDelete'));
    expect(rules, contains('ownedActiveCharacterMatches'));
    expect(rules, contains('ownedActiveGameAccount'));
    expect(rules, contains('representativeActivityCovered'));
    expect(rules, contains('get(characterDoc).data.ownerPlayerId == playerId'));
    expect(
      rules,
      contains('get(characterDoc).data.gameAccountId == gameAccountId'),
    );
    expect(
      rules,
      contains('ownership.representativeCharacterId != characterId'),
    );
    expect(
      rules,
      contains(
        'get(ownershipDoc).data.representativeCharacterId',
      ),
    );
    expect(
      rules,
      contains(
        '!(get(ownershipDoc).data.representativeCharacterId is string)',
      ),
    );
    expect(rules, contains('exists(characterDoc)'));
    expect(rules, contains('exists(ownershipDoc)'));
    expect(rules, contains('function removedMemberIdLow(oldIds, kept)'));
    expect(rules, contains('function removedMemberIdHigh(oldIds, kept)'));
    expect(rules, isNot(contains('activityIdListHasStrings')));
    expect(rules, isNot(contains('activityCoversDeclaredAccounts')));
  });

  test('활동 설정 문서는 인증·소유권 필드를 허용 키에 넣지 않는다', () {
    final start = rules.indexOf('function validCharacterActivityWrite');
    final end = rules.indexOf('function validCharacterActivityDelete');
    final activityRules = rules.substring(start, end);
    expect(activityRules, contains("data.keys().hasOnly(["));
    expect(activityRules, contains("'schemaVersion'"));
    expect(activityRules, contains("'characterId'"));
    expect(activityRules, contains("'gameAccountId'"));
    expect(activityRules, contains("'updatedAt'"));
    expect(activityRules, isNot(contains("'ownerPlayerId'")));
    expect(activityRules, isNot(contains("'status'")));
    expect(activityRules, isNot(contains("'activityCharacterIds'")));
  });

  test('활동 Character 목록은 바인딩된 사용자가 읽고 별도 Projection 컬렉션은 두지 않는다', () {
    expect(rules, contains('match /characterActivity/{characterId}'));
    expect(rules, contains('allow get, list: if hasActiveBinding();'));
    expect(rules, isNot(contains('match /activityCharacterProjections/{characterId}')));
    expect(rules, isNot(contains('validActivityCharacterProjectionWrite')));
    expect(rules, isNot(contains('canReadActivityCharacterProjection')));
    expect(rules, isNot(contains('sharesActiveGroupWith')));
    expect(
      rules,
      isNot(contains('activityCharacterProjectionPath')),
    );
  });
}
