import '../entities/weekly_raid_claim.dart';

enum WeeklyRaidClaimReadFailureType {
  permissionDenied,
  unavailable,
  contract,
  unknown,
}

class WeeklyRaidClaimReadException implements Exception {
  const WeeklyRaidClaimReadException(this.type);

  final WeeklyRaidClaimReadFailureType type;
}

/// 현재 Player 경로의 특정 주차 Claim만 읽는 경계다.
abstract interface class WeeklyRaidClaimRepository {
  Stream<List<WeeklyRaidClaim>> watchCurrentCycleClaims({
    required String playerId,
    required String cycleKey,
  });
}
