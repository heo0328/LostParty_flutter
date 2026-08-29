import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/manual_verification/domain/entities/manual_verification_request.dart';
import 'package:lost_party/features/manual_verification/domain/manual_verification_account_scope.dart';

ManualVerificationRequest _request({
  int? localAccountId,
  String? targetGameAccountId,
  String identityKey = 'char-1',
}) {
  return ManualVerificationRequest(
    id: 'req-1',
    requesterPlayerId: 'player-1',
    targetIdentityKey: identityKey,
    localAccountId: localAccountId,
    targetGameAccountId: targetGameAccountId,
    localAccountLabelSnapshot: '메인',
    proofServerName: '루페온',
    proofCharacterName: '이슈아이',
    verificationCode: 'LP-7K4M2Q',
    status: ManualVerificationStatus.pendingProof,
    attemptNumberForTarget: 1,
    totalAttemptNumberForPlayer: 1,
    createdAt: DateTime.utc(2026, 8, 28),
    expiresAt: DateTime.utc(2026, 8, 29),
  );
}

void main() {
  test('같은 로컬 계정의 다른 캐릭터는 동일 계정으로 본다', () {
    expect(
      isSameManualVerificationAccount(
        request: _request(localAccountId: 1, identityKey: 'char-1'),
        localAccountId: 1,
        serverGameAccountId: null,
        rosterIdentityKeys: {'char-1', 'char-5'},
      ),
      isTrue,
    );
  });

  test('원정대에 포함된 증명 캐릭터면 로컬 ID가 없어도 동일 계정으로 본다', () {
    expect(
      isSameManualVerificationAccount(
        request: _request(identityKey: 'char-1'),
        localAccountId: 1,
        serverGameAccountId: null,
        rosterIdentityKeys: {'char-1', 'char-5'},
      ),
      isTrue,
    );
  });

  test('다른 부계정은 별도 요청으로 본다', () {
    expect(
      isSameManualVerificationAccount(
        request: _request(localAccountId: 1, identityKey: 'main-1'),
        localAccountId: 2,
        serverGameAccountId: null,
        rosterIdentityKeys: {'alt-1', 'alt-5'},
      ),
      isFalse,
    );
  });
}
