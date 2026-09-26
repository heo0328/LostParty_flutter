import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  for (final rulesPath in [
    'firestore.rules',
    'tools/party_scalability_proof.rules',
  ]) {
    test('$rulesPath는 만료된 1회성 모집만 미완료 종료로 허용한다', () {
      final rules = read(rulesPath);

      expect(rules, contains("newData.lastCommandType == 'incompleteEnd'"));
      expect(rules, contains("oldData.continueTogether == false"));
      expect(rules, contains('oldData.schemaVersion == 2'));
      expect(rules, contains('newData.schemaVersion == 2'));
      expect(rules, contains("newData.status == 'incompleteEnded'"));
      expect(
        rules,
        contains('request.time >= oldData.cycleEndsAt'),
      );
      expect(
        rules,
        anyOf(
          contains('atomicValidIncompleteEndShape'),
          contains('validIncompleteEndShape'),
        ),
      );
      expect(rules, contains("? 'partyIncompleteEnded'"));
      expect(rules, contains('commandTargets.size() == 0'));

      final raidStateUpdateStart = rules.indexOf(
        rulesPath == 'firestore.rules'
            ? 'function validAtomicRaidStateUpdate'
            : 'function validRaidStateUpdate',
      );
      final eventStart = rules.indexOf(
        rulesPath == 'firestore.rules'
            ? 'function atomicEventTargetMatches'
            : 'function eventTargetMatches',
      );
      expect(raidStateUpdateStart, greaterThanOrEqualTo(0));
      expect(eventStart, greaterThan(raidStateUpdateStart));
      expect(
        rules.substring(raidStateUpdateStart, eventStart),
        isNot(contains("lastCommandType == 'incompleteEnd'")),
      );
    });
  }

  test('클라이언트는 1회성 전환만 target 없는 미완료 종료 명령으로 바꾼다', () {
    final adapter = read(
      'lib/features/recruitment_list/data/repositories/'
      'party_atomic_cycle_command_adapter.dart',
    );
    final repository = read(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_party_atomic_command_repository.dart',
    );

    expect(adapter, contains('!aggregate.continueTogether'));
    expect(adapter, contains('PartyAtomicCommandType.incompleteEnd'));
    expect(adapter, contains('completedDisband || targetlessIncompleteEnd'));
    expect(
      repository,
      contains('aggregate.partySlots.any((slot) => slot.playerId == playerId)'),
    );
  });
}
