import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('운영자 지정은 본인 get만 가능하고 클라이언트 쓰기는 닫혀 있다', () {
    expect(rules, contains('match /operatorAssignments/{playerId}'));
    expect(
      rules,
      contains(
        'allow get: if hasActiveBinding() && currentPlayerId() == playerId;',
      ),
    );
    expect(rules, contains('allow list, create, update, delete: if false;'));
  });

  test('Player list와 lastSeenAt 갱신은 분리된 권한 경계를 사용한다', () {
    expect(rules, contains('allow list: if isActiveOperator();'));
    expect(rules, contains("affectedKeys().hasOnly(['lastSeenAt'])"));
    expect(rules, contains('newData.lastSeenAt == request.time'));
    expect(rules, contains('newData.lastSeenAt == null'));
  });

  test('대표 Character 변경은 소유·동일 계정·서버 시각·5분을 검증한다', () {
    expect(rules, contains('validRepresentativeCharacterUpdate'));
    expect(rules, contains("duration.value(5, 'm')"));
    expect(
      rules,
      contains('newData.representativeCharacterUpdatedAt == request.time'),
    );
    expect(rules, contains('character.ownerPlayerId == oldData.playerId'));
    expect(rules, contains('character.gameAccountId == oldData.gameAccountId'));
    expect(rules, contains("character.status == 'active'"));
  });
}
