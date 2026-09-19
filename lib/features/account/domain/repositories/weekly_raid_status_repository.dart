import '../entities/weekly_raid_status_projection.dart';
import 'weekly_raid_claim_repository.dart';

abstract interface class WeeklyRaidStatusRepository {
  Stream<List<WeeklyRaidStatusProjection>> watchCurrentCycleStatuses({
    required String playerId,
    required String cycleKey,
  });
}

/// Firestore 읽기 오류 계약은 기존 주간 Claim 화면과 공유한다.
typedef WeeklyRaidStatusReadException = WeeklyRaidClaimReadException;
typedef WeeklyRaidStatusReadFailureType = WeeklyRaidClaimReadFailureType;
