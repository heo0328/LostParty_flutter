import '../entities/party_cycle_command.dart';

abstract interface class PartyCycleCommandRepository {
  Future<PartyCycleResult> complete(PartyCompleteCycleCommand command);
  Future<PartyCycleResult> setRecurrence(PartySetRecurrenceCommand command);
  Future<PartyCycleResult> advance(PartyAdvanceCycleCommand command);
  Future<PartyCycleResult> disband(PartyDisbandCommand command);
  Future<PartyCycleResult> purgeStaleOwnAssignment(
    PartyPurgeStaleAssignmentCommand command,
  );
}
