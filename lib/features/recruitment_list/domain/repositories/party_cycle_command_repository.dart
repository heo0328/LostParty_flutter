import '../entities/party_cycle_command.dart';

abstract interface class PartyCycleCommandRepository {
  Future<PartyCycleResult> complete(PartyCompleteCycleCommand command);
  Future<PartyCycleResult> cancelCompletion(PartyCancelCompletionCommand command);
  Future<PartyCycleResult> setRecurrence(PartySetRecurrenceCommand command);
  Future<PartyCycleResult> advance(PartyAdvanceCycleCommand command);
}
