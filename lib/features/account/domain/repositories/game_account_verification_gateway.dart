import '../entities/game_account_verification.dart';

abstract interface class GameAccountVerificationGateway {
  Future<GameAccountVerificationChallenge> start({
    required String characterName,
    required String source,
    int? localAccountId,
  });

  Future<GameAccountVerificationResult> confirm(String challengeId);
}
