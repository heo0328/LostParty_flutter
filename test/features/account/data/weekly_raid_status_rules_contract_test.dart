import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('본인 raidState와 legacy assignment만 list할 수 있다', () {
    for (final match in [
      'match /raidStates/{stateId}',
      'match /activeRaidAssignments/{assignmentId}',
    ]) {
      final start = rules.indexOf(match);
      final end = rules.indexOf('\n      match /', start + match.length);
      final block = rules.substring(start, end);
      expect(block, contains('allow list: if hasActiveBinding()'));
      expect(block, contains('playerId == currentPlayerId()'));
    }
  });

  test('legacy assignment 쓰기는 계속 닫혀 있다', () {
    final start = rules.indexOf('match /activeRaidAssignments/{assignmentId}');
    final end = rules.indexOf('\n      match /', start + 1);
    final block = rules.substring(start, end);
    expect(block, contains('allow create, update, delete: if false;'));
  });
}
