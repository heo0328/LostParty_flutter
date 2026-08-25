import '../entities/party_create_command.dart';
import '../policies/party_cycle_policy.dart';

class PartyCreateCommandValidator {
  const PartyCreateCommandValidator();

  PartyCreateFailure? validate(PartyCreateCommand command) {
    if (_invalidDocumentId(command.recruitmentId) ||
        command.title.trim().isEmpty ||
        _invalidDocumentId(command.leaderCharacterId) ||
        const PartyCyclePolicy().fromKey(command.cycleKey) == null ||
        command.compositionRules.totalMembers < 1 ||
        command.leaderItemLevel < command.metadata.minItemLevel) {
      return PartyCreateFailure.invalidRequest;
    }
    return null;
  }

  bool _invalidDocumentId(String value) =>
      value.trim().isEmpty || value.contains('/');
}
