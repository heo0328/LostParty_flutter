import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/group_join_command.dart';
import '../../domain/entities/group_join_relation.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_summary.dart';
import '../../domain/repositories/group_application_command_repository.dart';
import '../../domain/services/group_join_command_validator.dart';
import '../mappers/group_application_write_plan.dart';
import '../mappers/group_create_write_plan.dart';
import '../mappers/group_document_mapper.dart';
import 'group_command_runner.dart';

/// 계약 §8.6. 그룹장 신청 처리 명령을 한 Transaction으로 실행한다.
///
/// 그룹장은 대상 Player의 `groupMembershipState`와 `groupRelations`를 읽을 수
/// 없으므로 승인 쓰기는 배열 합집합·증가 병합으로 보내고 Player별 50개 한도는
/// Rules가 최종 판정한다. 거절 결과는 `이 그룹에 가입할 수 없습니다` 수준으로만
/// 사용자에게 전달한다.
class FirestoreGroupApplicationCommandRepository
    implements GroupApplicationCommandRepository {
  FirestoreGroupApplicationCommandRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    DateTime Function() clock = DateTime.now,
  }) : _firestore = firestore,
       _runner = GroupCommandRunner(
         firestore: firestore,
         firebaseAuth: firebaseAuth,
       ),
       _clock = clock;

  static const _validator = GroupJoinCommandValidator();
  static final _mapper = groupFirestoreMapper;

  final FirebaseFirestore _firestore;
  final GroupCommandRunner _runner;
  final DateTime Function() _clock;

  @override
  Future<GroupJoinCommandResult> approveApplication(
    GroupApplicationDecisionCommand command,
  ) async {
    final invalid = _validator.validateApplicationDecision(command);
    if (invalid != null) return GroupJoinCommandResult.failure(invalid);
    return _runner.run((transaction, playerId) async {
      final groupRef = _groupRef(command.groupId);
      final context = await _leaderContext(transaction, groupRef, playerId);
      if (context.failure != null) {
        return GroupJoinCommandResult.failure(context.failure!);
      }
      final group = context.group!;

      final relationRef = groupRef
          .collection('joinRelations')
          .doc(command.targetPlayerId);
      final relation = _joinRelation(await transaction.get(relationRef));
      final guard = _applicationGuard(relation, command);
      if (guard != null) return guard;
      if (relation!.status == GroupRequestStatus.accepted) {
        // 두 기기의 동일 승인 재시도는 membership을 한 번만 만든다.
        return const GroupJoinCommandResult.success(
          GroupRequestStatus.accepted,
        );
      }
      if (relation.status != GroupRequestStatus.pending) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.requestNotPending,
        );
      }
      if (relation.isExpiredAt(_clock())) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.requestExpired,
        );
      }

      final memberRef = groupRef
          .collection('members')
          .doc(command.targetPlayerId);
      if ((await transaction.get(memberRef)).exists) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.alreadyMember,
        );
      }
      if (group.memberCount >= GroupMember.maxMemberCount) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupCapacityFull,
        );
      }

      final serverTimestamp = FieldValue.serverTimestamp();
      final plan = GroupApplicationWritePlan.approved(
        relation: relation,
        groupName: group.name,
        groupRevision: group.revision,
        groupMemberCount: group.memberCount,
        serverTimestamp: serverTimestamp,
        addedGroupIdUnion: FieldValue.arrayUnion([command.groupId]),
        incrementByOne: FieldValue.increment(1),
        now: _clock(),
      );
      transaction.update(relationRef, plan.joinRelationPatch!);
      transaction.set(memberRef, plan.member!);
      transaction.set(
        _membershipStateRef(command.targetPlayerId),
        plan.membershipStatePatch!,
        SetOptions(merge: true),
      );
      transaction.set(
        _playerRelationRef(command.targetPlayerId, command.groupId),
        plan.playerRelationPatch!,
        SetOptions(merge: true),
      );
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCommandResult.success(GroupRequestStatus.accepted);
    });
  }

  @override
  Future<GroupJoinCommandResult> rejectApplication(
    GroupApplicationDecisionCommand command,
  ) async {
    final invalid = _validator.validateApplicationDecision(command);
    if (invalid != null) return GroupJoinCommandResult.failure(invalid);
    return _runner.run((transaction, playerId) async {
      final groupRef = _groupRef(command.groupId);
      final context = await _leaderContext(transaction, groupRef, playerId);
      if (context.failure != null) {
        return GroupJoinCommandResult.failure(context.failure!);
      }
      final group = context.group!;

      final relationRef = groupRef
          .collection('joinRelations')
          .doc(command.targetPlayerId);
      final relation = _joinRelation(await transaction.get(relationRef));
      final guard = _applicationGuard(relation, command);
      if (guard != null) return guard;
      if (relation!.status != GroupRequestStatus.pending) {
        // 이미 최종 상태면 역방향 변경 없이 현재 결과를 반환한다.
        return GroupJoinCommandResult.success(relation.status);
      }

      final plan = GroupApplicationWritePlan.rejected(
        relation: relation,
        groupName: group.name,
        groupRevision: group.revision,
        serverTimestamp: FieldValue.serverTimestamp(),
      );
      transaction.update(relationRef, plan.joinRelationPatch!);
      transaction.set(
        _playerRelationRef(command.targetPlayerId, command.groupId),
        plan.playerRelationPatch!,
        SetOptions(merge: true),
      );
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCommandResult.success(GroupRequestStatus.rejected);
    });
  }

  @override
  Future<GroupJoinCommandResult> blockApplicant(
    GroupApplicationDecisionCommand command,
  ) async {
    final invalid = _validator.validateApplicationDecision(command);
    if (invalid != null) return GroupJoinCommandResult.failure(invalid);
    return _runner.run((transaction, playerId) async {
      final groupRef = _groupRef(command.groupId);
      final context = await _leaderContext(transaction, groupRef, playerId);
      if (context.failure != null) {
        return GroupJoinCommandResult.failure(context.failure!);
      }
      final group = context.group!;

      final relationRef = groupRef
          .collection('joinRelations')
          .doc(command.targetPlayerId);
      final relation = _joinRelation(await transaction.get(relationRef));
      final guard = _applicationGuard(relation, command);
      if (guard != null) return guard;

      final statsRef = groupRef
          .collection('applicantStats')
          .doc(command.targetPlayerId);
      final stats = _mapper.toApplicantStats(
        groupId: command.groupId,
        playerId: command.targetPlayerId,
        data: _data(await transaction.get(statsRef)),
      );
      final blockRef = _blockRef(command.groupId, command.targetPlayerId);
      final alreadyBlocked = (await transaction.get(blockRef)).exists;

      final plan = GroupApplicationWritePlan.blocked(
        relation: relation!,
        groupName: group.name,
        groupRevision: group.revision,
        blockedByPlayerId: playerId,
        applicationCount: stats.applicationCount,
        serverTimestamp: FieldValue.serverTimestamp(),
        now: _clock(),
      );
      final relationPatch = plan.joinRelationPatch;
      if (relationPatch != null) {
        transaction.update(relationRef, relationPatch);
        transaction.set(
          _playerRelationRef(command.targetPlayerId, command.groupId),
          plan.playerRelationPatch!,
          SetOptions(merge: true),
        );
      }
      // block 문서는 수정할 수 없다. 이미 금지된 Player는 다시 만들지 않는다.
      if (!alreadyBlocked) {
        transaction.set(blockRef, plan.blockDocument!);
      } else if (relationPatch == null) {
        return const GroupJoinCommandResult.success(GroupRequestStatus.blocked);
      }
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCommandResult.success(GroupRequestStatus.blocked);
    });
  }

  @override
  Future<GroupJoinCommandResult> releaseBlock(
    GroupBlockReleaseCommand command,
  ) async {
    final invalid = _validator.validateBlockRelease(command);
    if (invalid != null) return GroupJoinCommandResult.failure(invalid);
    return _runner.run((transaction, playerId) async {
      final groupRef = _groupRef(command.groupId);
      final context = await _leaderContext(transaction, groupRef, playerId);
      if (context.failure != null) {
        return GroupJoinCommandResult.failure(context.failure!);
      }

      final blockRef = _blockRef(command.groupId, command.targetPlayerId);
      if (!(await transaction.get(blockRef)).exists) {
        return const GroupJoinCommandResult.completed();
      }

      // 계약 §6.2. 해제는 이전 relation을 pending·accepted로 복원하지 않는다.
      final plan = GroupApplicationWritePlan.blockReleased(
        groupRevision: context.group!.revision,
        serverTimestamp: FieldValue.serverTimestamp(),
      );
      transaction.delete(blockRef);
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCommandResult.completed();
    });
  }

  /// 그룹 상태와 호출자의 그룹장 자격을 먼저 확정한다.
  Future<_GroupLeaderContext> _leaderContext(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> groupRef,
    String playerId,
  ) async {
    final group = _group(await transaction.get(groupRef));
    if (group == null) {
      return const _GroupLeaderContext.failed(GroupJoinFailure.groupNotFound);
    }
    if (group.status != GroupStatus.active) {
      return const _GroupLeaderContext.failed(GroupJoinFailure.groupClosed);
    }
    final callerMember = await transaction.get(
      groupRef.collection('members').doc(playerId),
    );
    if (!callerMember.exists) {
      return const _GroupLeaderContext.failed(GroupJoinFailure.notGroupMember);
    }
    if (callerMember.data()?['role'] != GroupMemberRole.leader.name) {
      return const _GroupLeaderContext.failed(GroupJoinFailure.notGroupLeader);
    }
    return _GroupLeaderContext(group);
  }

  GroupJoinCommandResult? _applicationGuard(
    GroupJoinRelation? relation,
    GroupApplicationDecisionCommand command,
  ) {
    if (relation == null) {
      return const GroupJoinCommandResult.failure(
        GroupJoinFailure.requestNotFound,
      );
    }
    if (relation.kind != GroupJoinRelationKind.application) {
      return const GroupJoinCommandResult.failure(
        GroupJoinFailure.invalidRequest,
      );
    }
    if (relation.revision != command.expectedRelationRevision) {
      return const GroupJoinCommandResult.failure(
        GroupJoinFailure.revisionConflict,
      );
    }
    return null;
  }

  DocumentReference<Map<String, dynamic>> _groupRef(String groupId) =>
      _firestore.collection('groups').doc(groupId);

  DocumentReference<Map<String, dynamic>> _blockRef(
    String groupId,
    String playerId,
  ) => _groupRef(groupId).collection('blockedPlayers').doc(playerId);

  DocumentReference<Map<String, dynamic>> _membershipStateRef(
    String playerId,
  ) => _firestore
      .collection('players')
      .doc(playerId)
      .collection('groupMembershipState')
      .doc(GroupCreateWritePlan.membershipStateDocumentId);

  DocumentReference<Map<String, dynamic>> _playerRelationRef(
    String playerId,
    String groupId,
  ) => _firestore
      .collection('players')
      .doc(playerId)
      .collection('groupRelations')
      .doc(groupId);

  GroupPublicSummary? _group(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists) return null;
    return _mapper.toPublicSummary(
      GroupDocumentDto(
        id: snapshot.id,
        data: Map<String, Object?>.from(snapshot.data() ?? const {}),
      ),
    );
  }

  GroupJoinRelation? _joinRelation(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) return null;
    return _mapper.toJoinRelation(
      GroupDocumentDto(
        id: snapshot.id,
        data: Map<String, Object?>.from(snapshot.data() ?? const {}),
      ),
    );
  }

  Map<String, Object?>? _data(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.exists
      ? Map<String, Object?>.from(snapshot.data() ?? const {})
      : null;
}

class _GroupLeaderContext {
  const _GroupLeaderContext(this.group) : failure = null;

  const _GroupLeaderContext.failed(this.failure) : group = null;

  final GroupPublicSummary? group;
  final GroupJoinFailure? failure;
}
