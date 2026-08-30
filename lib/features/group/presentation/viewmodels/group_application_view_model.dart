import '../../domain/entities/group_blocked_player.dart';
import '../../domain/entities/group_join_command.dart';
import '../../domain/entities/group_join_relation.dart';
import '../../domain/repositories/group_application_command_repository.dart';
import '../../domain/repositories/group_read_repository.dart';

/// 그룹장 신청 관리 화면이 한 번에 읽는 목록이다. 만료된 pending 신청은
/// 계약 §11에 따라 쓰기 없이 화면에서만 만료로 구분한다.
class GroupApplicationsSnapshot {
  const GroupApplicationsSnapshot({
    required this.applications,
    required this.blockedPlayers,
  });

  final List<GroupJoinRelation> applications;
  final List<GroupBlockedPlayer> blockedPlayers;

  List<GroupJoinRelation> actionableAt(DateTime now) => applications
      .where((relation) => relation.isPendingAt(now))
      .toList(growable: false);

  List<GroupJoinRelation> expiredAt(DateTime now) => applications
      .where((relation) => !relation.isPendingAt(now))
      .toList(growable: false);
}

/// 계약 §8.6 그룹장 신청 관리. 승인·거절·금지·해제는 모두 그룹장만 실행하며
/// 화면에서 버튼을 감추는 것은 보안 경계가 아니다.
class GroupApplicationsViewModel {
  const GroupApplicationsViewModel({
    required this.readRepository,
    required this.commandRepository,
  });

  final GroupReadRepository readRepository;
  final GroupApplicationCommandRepository commandRepository;

  Future<bool> isLeader({
    required String groupId,
    required String playerId,
  }) async {
    final member = await readRepository.loadGroupMember(
      groupId: groupId,
      playerId: playerId,
    );
    return member?.isLeader ?? false;
  }

  Future<GroupApplicationsSnapshot> load(String groupId) async {
    final applications = await readRepository.loadGroupJoinRelations(
      groupId: groupId,
      kind: GroupJoinRelationKind.application,
    );
    final blockedPlayers = await readRepository.loadBlockedPlayers(
      groupId: groupId,
    );
    return GroupApplicationsSnapshot(
      applications: applications,
      blockedPlayers: blockedPlayers,
    );
  }

  Future<GroupJoinCommandResult> approve(GroupJoinRelation relation) =>
      commandRepository.approveApplication(_decisionFor(relation));

  Future<GroupJoinCommandResult> reject(GroupJoinRelation relation) =>
      commandRepository.rejectApplication(_decisionFor(relation));

  Future<GroupJoinCommandResult> block(GroupJoinRelation relation) =>
      commandRepository.blockApplicant(_decisionFor(relation));

  Future<GroupJoinCommandResult> releaseBlock(GroupBlockedPlayer blocked) =>
      commandRepository.releaseBlock(
        GroupBlockReleaseCommand(
          groupId: blocked.groupId,
          targetPlayerId: blocked.playerId,
        ),
      );

  GroupApplicationDecisionCommand _decisionFor(GroupJoinRelation relation) =>
      GroupApplicationDecisionCommand(
        groupId: relation.groupId,
        targetPlayerId: relation.targetPlayerId,
        expectedRelationRevision: relation.revision,
      );
}
