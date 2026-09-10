import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('Rules 생성 경로는 map 인자에 null sentinel을 전달하지 않는다', () {
    expect(
      rules,
      isNot(
        contains(
          'validMembershipStateAdd(\n'
          '          playerId,\n'
          '          docId,\n'
          '          null,',
        ),
      ),
    );
    expect(
      rules,
      isNot(
        contains(
          'validLeaderApprovedMembershipStateAdd(\n'
          '          playerId,\n'
          '          docId,\n'
          '          null,',
        ),
      ),
    );
    expect(
      rules,
      isNot(
        contains(
          'validGroupInvitationCreate(\n'
          '          groupId,\n'
          '          playerId,\n'
          '          null,',
        ),
      ),
    );
    expect(
      rules,
      isNot(
        contains(
          'validGroupApplicationCreate(\n'
          '          groupId,\n'
          '          playerId,\n'
          '          null,',
        ),
      ),
    );
    expect(
      rules,
      isNot(
        contains(
          'validGroupApplicantStatsWrite(\n'
          '          groupId,\n'
          '          playerId,\n'
          '          null,',
        ),
      ),
    );
  });

  test('Rules 소유권 판정은 nullable 문자열 반환을 사용하지 않는다', () {
    expect(rules, isNot(contains('manualVerificationActiveOwnerPlayerId')));
    expect(
      rules,
      isNot(contains("'targetGameAccountId' in data ? data.targetGameAccountId : null")),
    );
    expect(
      rules,
      isNot(
        contains(
          'let representativeId = exists(ownershipDoc)\n'
          '        ? get(ownershipDoc).data.representativeCharacterId\n'
          '        : null;',
        ),
      ),
    );
  });

  test('모집 참가 검증에는 사용하지 않는 recruitmentId 인자가 없다', () {
    expect(rules, contains('function validRecruitmentJoin(oldData, newData)'));
    expect(
      rules,
      isNot(
        contains(
          'function validRecruitmentJoin(recruitmentId, oldData, newData)',
        ),
      ),
    );
  });
}
