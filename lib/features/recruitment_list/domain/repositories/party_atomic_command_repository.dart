import '../entities/party_atomic_command.dart';

enum PartyAtomicCommandFailure {
  unauthenticated,
  unauthorized,
  notFound,
  recruitmentClosed,
  cycleMismatch,
  revisionConflict,
  raidStateConflict,
  permissionDenied,
  temporarilyUnavailable,
  invalidRequest,
  unknown,
}

class PartyAtomicCommandResult {
  const PartyAtomicCommandResult.applied({required this.revision})
    : failure = null;

  const PartyAtomicCommandResult.failure(this.failure) : revision = null;

  final int? revision;
  final PartyAtomicCommandFailure? failure;

  bool get isApplied => failure == null;
}

abstract interface class PartyAtomicCommandRepository {
  Future<PartyAtomicCommandResult> execute(PartyCommandEnvelope command);

  Future<PartyCommandAggregate?> findAggregate(String recruitmentId);
}
