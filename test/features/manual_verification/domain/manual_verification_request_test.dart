import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/manual_verification/domain/entities/manual_verification_request.dart';

void main() {
  test('대기 요청은 만료 시각이 지나면 만료로 본다', () {
    final request = ManualVerificationRequest(
      id: 'req-1',
      requesterPlayerId: 'player-1',
      targetIdentityKey: 'key',
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
    expect(request.isExpiredAt(DateTime.utc(2026, 8, 29)), isTrue);
    expect(request.isExpiredAt(DateTime.utc(2026, 8, 28, 23)), isFalse);
  });

  test('분쟁 응답 기한이 지나면 무응답으로 본다', () {
    final request = ManualVerificationRequest(
      id: 'req-2',
      requesterPlayerId: 'player-2',
      targetIdentityKey: 'key',
      localAccountLabelSnapshot: '메인',
      proofServerName: '루페온',
      proofCharacterName: '이슈아이',
      verificationCode: 'LP-7K4M2Q',
      status: ManualVerificationStatus.awaitingOwnerResponse,
      attemptNumberForTarget: 1,
      totalAttemptNumberForPlayer: 1,
      createdAt: DateTime.utc(2026, 8, 28),
      expiresAt: DateTime.utc(2026, 8, 29),
      ownerResponseDeadlineAt: DateTime.utc(2026, 8, 29, 12),
    );
    expect(request.isOwnerResponseOverdueAt(DateTime.utc(2026, 8, 29, 11)), isFalse);
    expect(request.isOwnerResponseOverdueAt(DateTime.utc(2026, 8, 29, 12)), isTrue);
  });
}
