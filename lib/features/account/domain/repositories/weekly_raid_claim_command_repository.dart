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

abstract interface class WeeklyRaidClaimCommandRepository {
  Future<WeeklyRaidClaimCommandResult> createManualClaim(
    CreateManualWeeklyRaidClaimCommand command,
  );

  Future<WeeklyRaidClaimCommandResult> deleteManualClaim(
    DeleteManualWeeklyRaidClaimCommand command,
  );
}
