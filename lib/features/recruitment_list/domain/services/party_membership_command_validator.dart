import '../entities/party_membership_command.dart';

class PartyMembershipCommandValidator {
  const PartyMembershipCommandValidator();
  PartyMembershipFailure? validateChange(PartyChangeCharacterCommand command) =>
      _invalid(command.recruitmentId) ||
          _invalid(command.newCharacterId) ||
          command.expectedRecruitmentRevision < 1
      ? PartyMembershipFailure.invalidRequest
      : null;
  PartyMembershipFailure? validateRemove(PartyRemoveMemberCommand command) =>
      _invalid(command.recruitmentId) ||
          _invalid(command.targetPlayerId) ||
          command.expectedRecruitmentRevision < 1
      ? PartyMembershipFailure.invalidRequest
      : null;
  PartyMembershipFailure? validatePermission(
    PartySetApprovalPermissionCommand command,
  ) =>
      _invalid(command.recruitmentId) ||
          _invalid(command.targetPlayerId) ||
          command.expectedRecruitmentRevision < 1
      ? PartyMembershipFailure.invalidRequest
      : null;
  PartyMembershipFailure? validateReposition(
    PartyRepositionMembersCommand command,
  ) =>
      _invalid(command.recruitmentId) ||
          _invalid(command.sourcePlayerId) ||
          command.destinationPartyIndex < 0 ||
          command.destinationSlotIndex < 0 ||
          command.expectedRecruitmentRevision < 1
      ? PartyMembershipFailure.invalidRequest
      : null;
  bool _invalid(String value) => value.trim().isEmpty || value.contains('/');
}
