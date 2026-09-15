import '../entities/party_membership_command.dart';

/// 캐릭터 변경·자리 이동 원자 Repository.
///
/// 운영 Router에는 아직 연결하지 않는다.
abstract interface class PartyAtomicMemberMutationRepository {
  Future<PartyMembershipResult> changeCharacter(
    PartyChangeCharacterCommand command,
  );

  Future<PartyMembershipResult> repositionMembers(
    PartyRepositionMembersCommand command,
  );
}
