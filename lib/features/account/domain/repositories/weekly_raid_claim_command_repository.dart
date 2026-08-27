import '../entities/weekly_raid_claim_command.dart';

enum WeeklyRaidClaimCommandFailure {
  unauthenticated,
  invalidRequest,
  activeAssignment,
  pendingApplication,
  permissionDenied,
  temporarilyUnavailable,
  unknown,
}

class WeeklyRaidClaimCommandResult {
  const WeeklyRaidClaimCommandResult._({this.failure});

  const WeeklyRaidClaimCommandResult.success() : this._();
  const WeeklyRaidClaimCommandResult.failure(
    WeeklyRaidClaimCommandFailure failure,
  ) : this._(failure: failure);

  final WeeklyRaidClaimCommandFailure? failure;
  bool get isSuccess => failure == null;
}

class WeeklyRaidClaimImpactResult {
  const WeeklyRaidClaimImpactResult.success(this.impact) : failure = null;
  const WeeklyRaidClaimImpactResult.failure(this.failure) : impact = null;

  final ManualWeeklyRaidClaimImpact? impact;
  final WeeklyRaidClaimCommandFailure? failure;
  bool get isSuccess => failure == null;
}

abstract interface class WeeklyRaidClaimCommandRepository {
  Future<WeeklyRaidClaimImpactResult> inspectManualClaimImpact(
    CreateManualWeeklyRaidClaimCommand command,
  );

  Future<WeeklyRaidClaimCommandResult> createManualClaim(
    CreateManualWeeklyRaidClaimCommand command, {
    bool resolveConflicts = false,
  }
  );

  Future<WeeklyRaidClaimCommandResult> deleteManualClaim(
    DeleteManualWeeklyRaidClaimCommand command,
  );
}
