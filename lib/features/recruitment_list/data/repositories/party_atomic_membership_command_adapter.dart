import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_membership_command.dart';
import '../../domain/repositories/party_atomic_member_mutation_repository.dart';
import '../../domain/repositories/party_atomic_member_removal_repository.dart';
import '../../domain/repositories/party_membership_command_repository.dart';

/// 기존 membership 인터페이스를 원자 mutation·removal Repository에 연결한다.
class PartyAtomicMembershipCommandAdapter
    implements PartyMembershipCommandRepository {
  const PartyAtomicMembershipCommandAdapter({
    required PartyAtomicMemberMutationRepository mutationRepository,
    required PartyAtomicMemberRemovalRepository removalRepository,
  }) : _mutationRepository = mutationRepository,
       _removalRepository = removalRepository;

  final PartyAtomicMemberMutationRepository _mutationRepository;
  final PartyAtomicMemberRemovalRepository _removalRepository;

  @override
  Future<PartyMembershipResult> changeCharacter(
    PartyChangeCharacterCommand command,
  ) => _mutationRepository.changeCharacter(command);

  @override
  Future<PartyMembershipResult> leave(PartyRemoveMemberCommand command) =>
      _removalRepository.remove(command, PartyAtomicMemberRemovalType.leave);

  @override
  Future<PartyMembershipResult> kick(PartyRemoveMemberCommand command) =>
      _removalRepository.remove(command, PartyAtomicMemberRemovalType.kick);

  @override
  Future<PartyMembershipResult> removeLostGroupQualification(
    PartyRemoveMemberCommand command,
  ) => _removalRepository.remove(
    command,
    PartyAtomicMemberRemovalType.lostGroupQualification,
  );

  @override
  Future<PartyMembershipResult> setApprovalPermission(
    PartySetApprovalPermissionCommand command,
  ) async =>
      const PartyMembershipResult.failure(PartyMembershipFailure.invalidRequest);

  @override
  Future<PartyMembershipResult> repositionMembers(
    PartyRepositionMembersCommand command,
  ) => _mutationRepository.repositionMembers(command);
}
