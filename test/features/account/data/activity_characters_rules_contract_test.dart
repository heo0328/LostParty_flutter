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
        'existsAfter(characterActivityPath(playerId, representativeId))',
      ),
    );
    expect(rules, contains('!(representativeId is string)'));
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

  test('활동 Character Projection은 그룹원 읽기와 활동 문서 동기 쓰기를 강제한다', () {
    expect(
      rules,
      contains('match /activityCharacterProjections/{characterId}'),
    );
    expect(rules, contains('validActivityCharacterProjectionWrite'));
    expect(rules, contains('validActivityCharacterProjectionDelete'));
    expect(rules, contains('canReadActivityCharacterProjection'));
    expect(rules, contains('sharesActiveGroupWith'));
    expect(
      rules,
      contains(
        'existsAfter(activityCharacterProjectionPath(playerId, characterId))',
      ),
    );
    expect(
      rules,
      contains(
        '!existsAfter(activityCharacterProjectionPath(playerId, characterId))',
      ),
    );
    expect(
      rules,
      contains('existsAfter(characterActivityPath(playerId, characterId))'),
    );
    final start = rules.indexOf(
      'function validActivityCharacterProjectionWrite',
    );
    final end = rules.indexOf(
      'function validActivityCharacterProjectionDelete',
    );
    final projectionRules = rules.substring(start, end);
    expect(projectionRules, contains("'characterName'"));
    expect(projectionRules, contains("'displayOrder'"));
    expect(projectionRules, contains("'isRepresentative'"));
    expect(projectionRules, isNot(contains("'gameAccountId'")));
    expect(projectionRules, isNot(contains("'ownerPlayerId'")));
    expect(projectionRules, isNot(contains("'status'")));
  });
}
