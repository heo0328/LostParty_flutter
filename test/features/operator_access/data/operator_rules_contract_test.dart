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
    expect(rules, contains('validRepresentativeCharacterSeed'));
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

  test('수동 인증 요청은 본인 생성과 운영자 판정으로 분리된다', () {
    expect(rules, contains('match /manualVerificationRequests/{requestId}'));
    expect(rules, contains('match /manualVerificationBlocks/{blockId}'));
    expect(rules, contains('manualVerificationRequesterAlreadyOwns'));
    expect(rules, contains('manualVerificationAccountOwnedBy'));
    expect(rules, contains('manualVerificationOperatorContextUnchanged'));
    expect(rules, contains('validManualVerificationOperatorForceBody'));
    expect(rules, contains("newData.reviewReason == 'ownerDefenseFailed'"));
    expect(
      "!('defenseOfRequestId' in oldData".allMatches(rules).length,
      greaterThanOrEqualTo(2),
      reason: '분쟁 개시와 강제 승인 모두 선택 필드 부재를 먼저 확인해야 한다.',
    );
    expect(rules, contains('validManualVerificationCreate'));
    expect(rules, contains('validManualVerificationRequesterCancel'));
    expect(rules, contains('validManualVerificationReissue'));
    expect(rules, contains('validManualVerificationOperatorWrite'));
    expect(rules, contains('validManualVerificationBlockWrite'));
    expect(rules, contains('data.localAccountId is number'));
    expect(rules, contains("data.status == 'pendingProof'"));
    expect(rules, contains("newData.status == 'approved'"));
    expect(rules, contains("allow create, update, delete: if false;"));
  });
}
