import '../entities/party_membership_command.dart';

abstract interface class PartyMembershipCommandRepository {
  Future<PartyMembershipResult> changeCharacter(
    PartyChangeCharacterCommand command,
  );
  Future<PartyMembershipResult> leave(PartyRemoveMemberCommand command);
  Future<PartyMembershipResult> kick(PartyRemoveMemberCommand command);

  /// 그룹 전용 레이드에서 그룹 자격을 잃은 멤버를 제한적으로 정리한다.
  Future<PartyMembershipResult> removeLostGroupQualification(
    PartyRemoveMemberCommand command,
  );
  Future<PartyMembershipResult> setApprovalPermission(
    PartySetApprovalPermissionCommand command,
  );
  Future<PartyMembershipResult> repositionMembers(
    PartyRepositionMembersCommand command,
  );
}
