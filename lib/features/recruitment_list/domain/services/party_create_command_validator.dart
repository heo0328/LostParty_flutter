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
        command.leaderItemLevel < command.metadata.minItemLevel ||
        !_validGroupLink(command)) {
      return PartyCreateFailure.invalidRequest;
    }
    return null;
  }

  bool _validGroupLink(PartyCreateCommand command) {
    if (!RecruitmentVisibility.isValid(command.visibility)) return false;
    final groupId = command.groupId;
    if (command.visibility == RecruitmentVisibility.group) {
      return groupId != null && !_invalidDocumentId(groupId);
    }
    return groupId == null || !_invalidDocumentId(groupId);
  }

  bool _invalidDocumentId(String value) =>
      value.trim().isEmpty || value.contains('/');
}
