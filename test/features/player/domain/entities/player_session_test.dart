import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/player/domain/entities/player_session.dart';

void main() {
  test('AuthUid와 PlayerId를 서로 다른 식별자로 보관한다', () {
    final session = PlayerSession(authUid: 'auth-uid', playerId: 'player-id');

    expect(session.authUid, 'auth-uid');
    expect(session.playerId, 'player-id');
  });

  test('빈 식별자를 거부한다', () {
    expect(
      () => PlayerSession(authUid: '', playerId: 'player-id'),
      throwsArgumentError,
    );
    expect(
      () => PlayerSession(authUid: 'auth-uid', playerId: ' '),
      throwsArgumentError,
    );
  });
}
