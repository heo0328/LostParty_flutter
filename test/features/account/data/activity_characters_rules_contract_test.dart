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
    expect(rules, contains('character.ownerPlayerId == playerId'));
    expect(rules, contains('character.gameAccountId == gameAccountId'));
    expect(
      rules,
      contains('ownership.representativeCharacterId != characterId'),
    );
    expect(
      rules,
      contains(
        'existsAfter(characterActivityPath(playerId, representativeId))',
      ),
    );
    expect(rules, contains('!(representativeId is string)'));
    expect(rules, contains('exists(path)'));
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
}
