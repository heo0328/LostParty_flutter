import '../entities/party_application_command.dart';

class PartyApplicationCommandValidator {
  const PartyApplicationCommandValidator();
  PartyApplicationFailure? validateApply(PartyApplyCommand command) =>
      _invalidId(command.recruitmentId) || _invalidId(command.characterId) || command.cycleKey.trim().isEmpty
          ? PartyApplicationFailure.invalidRequest : null;
  PartyApplicationFailure? validateWithdraw(PartyWithdrawApplicationCommand command) =>
      _invalidId(command.recruitmentId) || command.expectedRevision < 1
          ? PartyApplicationFailure.invalidRequest : null;
  bool _invalidId(String value) => value.trim().isEmpty || value.contains('/');
}
