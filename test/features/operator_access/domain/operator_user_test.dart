import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/operator_access/domain/entities/operator_user.dart';

void main() {
  test('사용자 표시 ID는 원본 PlayerId 전체를 노출하지 않는다', () {
    const user = OperatorUserSummary(
      playerId: 'private-player-abcdef123456',
      status: 'active',
      createdAt: null,
      lastSeenAt: null,
      hasVerifiedGameAccount: false,
    );

    expect(user.displayId, 'LP-123456');
    expect(user.displayId, isNot(contains('private-player')));
  });
}
