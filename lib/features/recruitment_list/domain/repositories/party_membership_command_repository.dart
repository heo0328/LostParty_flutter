import '../entities/party_membership_command.dart';

abstract interface class PartyMembershipCommandRepository {
  Future<PartyMembershipResult> changeCharacter(PartyChangeCharacterCommand command);
  Future<PartyMembershipResult> leave(PartyRemoveMemberCommand command);
  Future<PartyMembershipResult> kick(PartyRemoveMemberCommand command);
  Future<PartyMembershipResult> setApprovalPermission(PartySetApprovalPermissionCommand command);
}
