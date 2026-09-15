import '../../../account/domain/repositories/account_repository.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../account/domain/repositories/character_combat_power_sync_gateway.dart';
import '../../domain/entities/group_join_command.dart';
import '../../domain/entities/group_leader_exit_command.dart';
import '../../domain/entities/group_leave_command.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_member_display.dart';
import '../../domain/entities/group_member_display_snapshot.dart';
import '../../domain/entities/group_member_display_snapshot_refresh_command.dart';
import '../../domain/services/group_local_member_display_lookup.dart';
import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_request_character.dart';
import '../../domain/repositories/group_character_search_repository.dart';
import '../../domain/repositories/group_join_command_repository.dart';
import '../../domain/repositories/group_read_repository.dart';
import '../../domain/services/activity_display_characters.dart';
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
  GroupJoinFailure.revisionConflict => '요청이 이미 변경되었습니다. 새로고침한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.groupCapacityFull => '그룹 정원이 가득 찼습니다. 새로고침한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.activeGroupLimitReached => '가입한 그룹이 50개입니다. 더 가입할 수 없습니다.',
  GroupJoinFailure.joinCodeActive => '이미 활성 초대코드가 있습니다. 폐기한 뒤 새로 만들어 주세요.',
  GroupJoinFailure.joinCodeMissing =>
    '초대코드가 없거나 폐기되었습니다. 코드를 확인하거나 새로고침한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.joinCodeInvalid => '초대코드 형식이 올바르지 않습니다.',
  GroupJoinFailure.leaderCannotLeave =>
    '그룹장은 지금 탈퇴할 수 없습니다. 그룹장 이전 또는 해산이 필요합니다.',
  GroupJoinFailure.transferTargetInvalid =>
    '그룹장을 넘길 수 있는 일반 그룹원이 아닙니다. 목록을 새로고침한 뒤 다시 선택해 주세요.',
  GroupJoinFailure.disbandRequiresSoloGroup =>
    '다른 그룹원이 있으면 해산할 수 없습니다. 그룹장을 이전하거나 멤버가 탈퇴한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.pendingGroupRequests =>
    '대기 중인 초대나 가입 신청이 있습니다. 취소하거나 거절한 뒤 해산해 주세요.',
  GroupJoinFailure.activeGroupRaidExists =>
    '아직 끝나지 않은 그룹만 공개 레이드가 있습니다. 해당 방을 해산한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.temporarilyUnavailable =>
    '일시적으로 처리할 수 없습니다. 새로고침한 뒤 다시 시도해 주세요.',
  GroupJoinFailure.unknown => '요청을 처리하지 못했습니다.',
};

/// 해산 차단 안내. 활성 초대코드는 관리 화면에서 먼저 폐기한다.
String groupDisbandFailureMessage(GroupJoinFailure failure) =>
    switch (failure) {
      GroupJoinFailure.joinCodeActive =>
        '활성 초대코드가 있습니다. 초대코드 화면에서 폐기한 뒤 다시 해산하세요.',
      GroupJoinFailure.permissionDenied =>
        '그룹 해산 권한을 확인하지 못했습니다. 최신 Firestore Rules 적용 상태를 확인해 주세요.',
      _ => groupJoinFailureMessage(failure),
    };

/// 탈퇴 명령 전용 안내. 가입 실패 문구와 구분한다.
String groupLeaveFailureMessage(GroupJoinFailure failure) => switch (failure) {
  GroupJoinFailure.leaderCannotLeave => groupJoinFailureMessage(
    GroupJoinFailure.leaderCannotLeave,
  ),
  GroupJoinFailure.activeGroupRaidExists =>
    '아직 그룹만 공개인 레이드 방의 파티장입니다. 전체 공개로 바꾸거나 해산한 뒤 탈퇴해 주세요.',
  GroupJoinFailure.notGroupMember => '그룹원만 탈퇴할 수 있습니다.',
  GroupJoinFailure.permissionDenied =>
    '그룹 탈퇴를 처리하지 못했습니다. Firestore Rules 배포 후 다시 시도해 주세요.',
  GroupJoinFailure.revisionConflict ||
  GroupJoinFailure.temporarilyUnavailable => groupJoinFailureMessage(failure),
  GroupJoinFailure.groupNotFound => '그룹을 찾을 수 없습니다.',
  GroupJoinFailure.groupClosed => '종료된 그룹입니다.',
  GroupJoinFailure.unauthenticated ||
  GroupJoinFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
  _ => '그룹 탈퇴를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.',
};

/// 그룹장 이전 전용 안내. 가입 실패 문구와 구분한다.
String groupTransferFailureMessage(GroupJoinFailure failure) =>
    switch (failure) {
      GroupJoinFailure.notGroupLeader => '그룹장만 그룹장을 이전할 수 있습니다.',
      GroupJoinFailure.transferTargetInvalid => groupJoinFailureMessage(
        GroupJoinFailure.transferTargetInvalid,
      ),
      GroupJoinFailure.permissionDenied =>
        '그룹장 이전 권한을 확인하지 못했습니다. 최신 Firestore Rules 적용 상태를 확인해 주세요.',
      GroupJoinFailure.revisionConflict ||
      GroupJoinFailure.temporarilyUnavailable => groupJoinFailureMessage(failure),
      GroupJoinFailure.groupNotFound => '그룹을 찾을 수 없습니다.',
      GroupJoinFailure.groupClosed => '종료된 그룹입니다.',
      GroupJoinFailure.unauthenticated ||
      GroupJoinFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
      _ => '그룹장 이전을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.',
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
    required this.characterSearchRepository,
    this.combatPowerSyncGateway,
    this.activityCharactersRepository,
    this.playerId,
  });

  final AccountRepository accountRepository;
  final GroupReadRepository readRepository;
  final GroupJoinCommandRepository commandRepository;
  final GroupCharacterSearchRepository characterSearchRepository;
  final CharacterCombatPowerSyncGateway? combatPowerSyncGateway;
  final ActivityCharactersRepository? activityCharactersRepository;
  final String? playerId;

  Future<GroupRelation?> loadMyRelation({
    required String playerId,
    required String groupId,
  }) => readRepository.loadMyRelation(playerId: playerId, groupId: groupId);

  Future<GroupMember?> loadMyMembership({
    required String playerId,
    required String groupId,
  }) => readRepository.loadGroupMember(groupId: groupId, playerId: playerId);

  Future<GroupMemberDisplayLoadResult> loadMemberDisplays({
    required String groupId,
    required String playerId,
  }) async {
    var syncFailed = false;
    try {
      final localDisplays = await GroupLocalMemberDisplayLookup(
        accountRepository: accountRepository,
        activityCharactersRepository: activityCharactersRepository,
        playerId: playerId,
      ).loadByServerCharacterId();
      // 각 캐릭터 자신의 값만 공유한다. 대표 전투력을 다른 캐릭터에 복사하지 않는다.
      try {
        await combatPowerSyncGateway?.updateCombatPowers({
          for (final entry in localDisplays.entries)
            if (entry.value.combatPower != null)
              entry.key: entry.value.combatPower!,
        });
      } catch (_) {
        syncFailed = true;
      }
      await _refreshMyDisplaySnapshotIfNeeded(
        groupId: groupId,
        playerId: playerId,
        localDisplays: localDisplays,
      );
    } catch (_) {
      syncFailed = true;
    }
    final displays = await readRepository.loadGroupMemberDisplays(groupId);
    final sorted = displays.toList(growable: false)
      ..sort((left, right) {
        if (left.isLeader != right.isLeader) {
          return left.isLeader ? -1 : 1;
        }
        return left.member.joinSequence.compareTo(right.member.joinSequence);
      });
    return GroupMemberDisplayLoadResult(
      members: sorted,
      syncFailed: syncFailed,
    );
  }

  Future<void> _refreshMyDisplaySnapshotIfNeeded({
    required String groupId,
    required String playerId,
    required Map<String, GroupMemberDisplaySnapshot> localDisplays,
  }) async {
    final member = await readRepository.loadGroupMember(
      groupId: groupId,
      playerId: playerId,
    );
    if (member == null) return;

    final localDisplay = localDisplays[member.displayCharacterIdSnapshot];
    // 활동에서 빠진 Character는 보강 후보가 아니다. 기존 Snapshot은 유지한다.
    if (localDisplay == null) return;
    if (localDisplay.matchesStored(
      storedClassName: member.displayClassNameSnapshot,
      storedItemLevel: member.itemLevelSnapshot,
      storedCombatPower: member.combatPowerSnapshot,
      storedGemValidation: member.gemValidationSnapshot,
    )) {
      return;
    }

    await commandRepository.refreshMyDisplaySnapshot(
      GroupMemberDisplaySnapshotRefreshCommand(
        groupId: groupId,
        snapshot: localDisplay,
      ),
    );
  }

  Future<List<GroupRequestCharacter>> loadPlayerCharacters(
    String ownerPlayerId,
  ) => loadActivityDisplayCharacters(
    searchRepository: characterSearchRepository,
    ownerPlayerId: ownerPlayerId,
    activityRepository: activityCharactersRepository,
  );

  Future<List<GroupCharacterOption>> loadAuthenticatedCharacters() =>
      GroupCharacterOptionLoader(
        accountRepository: accountRepository,
        activityCharactersRepository: activityCharactersRepository,
        playerId: playerId,
      ).load();

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

  Future<GroupJoinCommandResult> leave({required String groupId}) =>
      commandRepository.leave(GroupLeaveCommand(groupId: groupId));

  Future<GroupJoinCommandResult> transferLeadership({
    required String groupId,
    required String targetPlayerId,
    required int expectedGroupRevision,
  }) => commandRepository.transferLeadership(
    GroupLeaderTransferCommand(
      groupId: groupId,
      targetPlayerId: targetPlayerId,
      expectedGroupRevision: expectedGroupRevision,
    ),
  );

  Future<GroupJoinCommandResult> disband({
    required String groupId,
    required int expectedGroupRevision,
  }) => commandRepository.disband(
    GroupDisbandCommand(
      groupId: groupId,
      expectedGroupRevision: expectedGroupRevision,
    ),
  );
}
