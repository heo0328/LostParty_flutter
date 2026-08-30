import '../../../account/domain/repositories/account_repository.dart';
import '../../domain/entities/group_join_command.dart';
import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_request_character.dart';
import '../../domain/repositories/group_character_search_repository.dart';
import '../../domain/repositories/group_join_command_repository.dart';
import '../../domain/repositories/group_read_repository.dart';
import '../../domain/services/group_join_command_validator.dart';
import 'group_character_options.dart';

const _validator = GroupJoinCommandValidator();

/// 계약 §11. 금지된 사용자는 구체적인 운영 정보 대신 가입 불가 결과만 받는다.
/// 정원·revision·코드 폐기 경쟁은 새로고침·재시도 안내를 포함한다.
String groupJoinFailureMessage(GroupJoinFailure failure) => switch (failure) {
  GroupJoinFailure.unauthenticated ||
  GroupJoinFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
  GroupJoinFailure.invalidRequest => '요청 정보를 확인해 주세요.',
  GroupJoinFailure.invalidCharacter =>
    '사용할 수 없는 캐릭터입니다. 내 계정에서 정보를 새로고침한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.ownershipLost => '캐릭터 소유권을 확인하지 못했습니다.',
  GroupJoinFailure.groupNotFound => '그룹을 찾을 수 없습니다.',
  GroupJoinFailure.groupClosed => '종료된 그룹입니다.',
  GroupJoinFailure.notGroupMember => '그룹원만 초대할 수 있습니다.',
  GroupJoinFailure.notGroupLeader => '그룹장만 신청을 처리할 수 있습니다.',
  GroupJoinFailure.alreadyMember => '이미 이 그룹의 멤버입니다.',
  GroupJoinFailure.blocked ||
  GroupJoinFailure.permissionDenied => '이 그룹에 가입할 수 없습니다.',
  GroupJoinFailure.requestAlreadyPending => '이미 진행 중인 초대·신청 요청이 있습니다.',
  GroupJoinFailure.requestNotFound => '요청을 찾을 수 없습니다.',
  GroupJoinFailure.requestNotPending => '이미 처리된 요청입니다.',
  GroupJoinFailure.requestExpired => '요청이 만료되었습니다.',
  GroupJoinFailure.revisionConflict =>
    '요청이 이미 변경되었습니다. 새로고침한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.groupCapacityFull =>
    '그룹 정원이 가득 찼습니다. 새로고침한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.activeGroupLimitReached => '가입한 그룹이 50개입니다. 더 가입할 수 없습니다.',
  GroupJoinFailure.joinCodeActive =>
    '이미 활성 초대코드가 있습니다. 폐기한 뒤 새로 만들어 주세요.',
  GroupJoinFailure.joinCodeMissing =>
    '초대코드가 없거나 폐기되었습니다. 코드를 확인하거나 새로고침한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.joinCodeInvalid => '초대코드 형식이 올바르지 않습니다.',
  GroupJoinFailure.temporarilyUnavailable =>
    '일시적으로 처리할 수 없습니다. 새로고침한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.unknown => '요청을 처리하지 못했습니다.',
};

/// 계약 §8.3. 정확한 캐릭터명 검색 결과에서 대상 Player를 확정한다.
class GroupInviteViewModel {
  const GroupInviteViewModel({
    required this.searchRepository,
    required this.commandRepository,
  });

  final GroupCharacterSearchRepository searchRepository;
  final GroupJoinCommandRepository commandRepository;

  bool isValidQuery(String value) =>
      _validator.isValidCharacterNameQuery(value);

  Future<List<GroupRequestCharacter>> search(String characterName) =>
      searchRepository.searchActiveCharactersByExactName(characterName);

  Future<GroupJoinCommandResult> invite({
    required String groupId,
    required GroupRequestCharacter character,
  }) => commandRepository.invite(
    GroupInviteCommand(
      groupId: groupId,
      targetCharacterId: character.characterId,
    ),
  );
}

/// 계약 §11 요청 현황 탭. 내가 받은 초대와 내가 보낸 신청만 다룬다.
class GroupRequestsViewModel {
  const GroupRequestsViewModel({
    required this.readRepository,
    required this.commandRepository,
  });

  final GroupReadRepository readRepository;
  final GroupJoinCommandRepository commandRepository;

  Stream<GroupReadSnapshot<GroupRelation>> watchMyRequests(String playerId) =>
      readRepository.watchMyRequests(playerId);

  Future<GroupJoinCommandResult> acceptInvitation(GroupRelation relation) =>
      commandRepository.acceptInvitation(_decisionFor(relation));

  Future<GroupJoinCommandResult> rejectInvitation(GroupRelation relation) =>
      commandRepository.rejectInvitation(_decisionFor(relation));

  GroupInvitationDecisionCommand _decisionFor(GroupRelation relation) =>
      GroupInvitationDecisionCommand(
        groupId: relation.groupId,
        expectedRelationRevision: relation.sourceRevision,
      );
}

/// 그룹 상세에서 내 관계에 맞는 행동(신청·수락·거절·초대)을 고르기 위한 모델.
class GroupMembershipActionViewModel {
  const GroupMembershipActionViewModel({
    required this.accountRepository,
    required this.readRepository,
    required this.commandRepository,
  });

  final AccountRepository accountRepository;
  final GroupReadRepository readRepository;
  final GroupJoinCommandRepository commandRepository;

  Future<GroupRelation?> loadMyRelation({
    required String playerId,
    required String groupId,
  }) => readRepository.loadMyRelation(playerId: playerId, groupId: groupId);

  Future<List<GroupCharacterOption>> loadAuthenticatedCharacters() =>
      GroupCharacterOptionLoader(accountRepository: accountRepository).load();

  Future<GroupJoinCommandResult> apply({
    required String groupId,
    required GroupCharacterOption character,
  }) => commandRepository.apply(
    GroupApplyCommand(
      groupId: groupId,
      characterId: character.serverCharacterId,
    ),
  );

  Future<GroupJoinCommandResult> acceptInvitation(GroupRelation relation) =>
      commandRepository.acceptInvitation(
        GroupInvitationDecisionCommand(
          groupId: relation.groupId,
          expectedRelationRevision: relation.sourceRevision,
        ),
      );

  Future<GroupJoinCommandResult> rejectInvitation(GroupRelation relation) =>
      commandRepository.rejectInvitation(
        GroupInvitationDecisionCommand(
          groupId: relation.groupId,
          expectedRelationRevision: relation.sourceRevision,
        ),
      );
}
