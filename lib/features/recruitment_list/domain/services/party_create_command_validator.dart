import '../entities/party_create_command.dart';

class PartyCreateCommandValidator {
  const PartyCreateCommandValidator();

  PartyCreateFailure? validate(PartyCreateCommand command) {
    if (_invalidDocumentId(command.recruitmentId) ||
        command.title.trim().isEmpty ||
        _invalidDocumentId(command.leaderCharacterId) ||
        command.cycleKey.trim().isEmpty ||
        command.compositionRules.totalMembers < 1 ||
        command.leaderItemLevel < command.metadata.minItemLevel) {
      return PartyCreateFailure.invalidRequest;
    }
    return null;
  }

  bool _invalidDocumentId(String value) =>
      value.trim().isEmpty || value.contains('/');
}
