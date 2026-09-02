import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('활동 Character 쓰기는 Player 하위 문서와 최소 1명·대표 포함을 강제한다', () {
    expect(rules, contains('match /characterActivity/{docId}'));
    expect(rules, contains('validCharacterActivityDocument'));
    expect(rules, contains('activityIncludesAccountRepresentative'));
    expect(rules, contains("docId == 'current'"));
    expect(rules, contains('data.activityCharacterIds.size() >= 1'));
    expect(
      rules,
      contains('activityIds.hasAny([ownership.representativeCharacterId])'),
    );
    expect(rules, contains('allow create, update: if docId == \'current\''));
  });

  test('활동 설정 문서는 인증·소유권 필드를 허용 키에 넣지 않는다', () {
    final start = rules.indexOf('function validCharacterActivityDocument');
    final end = rules.indexOf('match /authBindings/{authUid}');
    final activityRules = rules.substring(start, end);
    expect(activityRules, contains("data.keys().hasOnly(["));
    expect(activityRules, contains("'schemaVersion'"));
    expect(activityRules, contains("'activityCharacterIds'"));
    expect(activityRules, contains("'gameAccountIds'"));
    expect(activityRules, contains("'updatedAt'"));
    expect(activityRules, isNot(contains("'ownerPlayerId'")));
    expect(
      activityRules.substring(
        activityRules.indexOf('data.keys().hasOnly(['),
        activityRules.indexOf(
          '])',
          activityRules.indexOf('data.keys().hasOnly(['),
        ),
      ),
      isNot(contains("'status'")),
    );
  });
}
