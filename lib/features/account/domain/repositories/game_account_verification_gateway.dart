import '../entities/game_account_verification.dart';

abstract interface class GameAccountVerificationGateway {
  /// 진행 중인 챌린지. 화면을 나갔다 와도 게이트웨이 수명 동안 유지된다.
  GameAccountVerificationChallenge? get activeChallenge;

  Future<GameAccountVerificationChallenge> start({
    required String characterName,
    required String source,
    int? localAccountId,
  });

  Future<GameAccountVerificationResult> confirm(String challengeId);
}
