import '../entities/party_cycle_command.dart';
import '../policies/party_cycle_policy.dart';

class PartyCycleCommandValidator {
  const PartyCycleCommandValidator();
  PartyCycleFailure? validateComplete(PartyCompleteCycleCommand command) => _invalidId(command.recruitmentId) || _invalidCycle(command.cycleKey) || command.expectedRecruitmentRevision < 1 ? PartyCycleFailure.invalidRequest : null;
  PartyCycleFailure? validateCancel(PartyCancelCompletionCommand command) => _invalidId(command.recruitmentId) || _invalidCycle(command.cycleKey) || command.expectedRecruitmentRevision < 1 || command.expectedCompletionRevision < 1 ? PartyCycleFailure.invalidRequest : null;
  PartyCycleFailure? validateRecurrence(PartySetRecurrenceCommand command) => _invalidId(command.recruitmentId) || command.expectedRecruitmentRevision < 1 ? PartyCycleFailure.invalidRequest : null;
  PartyCycleFailure? validateAdvance(PartyAdvanceCycleCommand command) => _invalidId(command.recruitmentId) || _invalidCycle(command.expectedCycleKey) || _invalidCycle(command.nextCycleKey) || command.expectedCycleKey == command.nextCycleKey || command.expectedRecruitmentRevision < 1 ? PartyCycleFailure.invalidRequest : null;
  bool _invalidId(String value) => value.trim().isEmpty || value.contains('/');
  bool _invalidCycle(String value) => const PartyCyclePolicy().fromKey(value) == null;
}
