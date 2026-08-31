import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/group_join_command.dart';
import '../../domain/entities/group_leave_command.dart';
import '../../domain/entities/group_member_display_snapshot_refresh_command.dart';
import '../../domain/entities/group_member_display_snapshot.dart';
import '../../domain/entities/group_join_relation.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_request_character.dart';
import '../../domain/entities/group_summary.dart';
import '../../domain/repositories/group_join_command_repository.dart';
import '../../domain/services/group_join_command_validator.dart';
import '../../domain/services/group_local_member_display_lookup.dart';
import '../mappers/group_create_write_plan.dart';
import '../mappers/group_document_mapper.dart';
import '../mappers/group_join_write_plan.dart';
import '../mappers/group_leave_write_plan.dart';
import '../mappers/group_member_snapshot_write_plan.dart';
import 'firestore_group_character_search_repository.dart';
import 'group_command_runner.dart';

/// 계약 §8.3~8.5. 모든 명령은 authBinding부터 읽고 검증 읽기를 끝낸 뒤에만 쓴다.
///
/// `blockedPlayers`는 당사자와 일반 그룹원이 읽을 수 없으므로 Transaction에서
/// 읽지 않는다. 금지 여부는 Rules의 `exists()`가 최종 판정하고 클라이언트는
/// `permission-denied`를 가입 불가 안내로 바꿔 보여 준다.
class FirestoreGroupJoinCommandRepository implements GroupJoinCommandRepository {
  FirestoreGroupJoinCommandRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    GroupLocalMemberDisplayLookup? localMemberDisplayLookup,
    DateTime Function() clock = DateTime.now,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth,
       _localMemberDisplayLookup = localMemberDisplayLookup,
       _clock = clock;

  static const _validator = GroupJoinCommandValidator();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final GroupLocalMemberDisplayLookup? _localMemberDisplayLookup;
  final DateTime Function() _clock;

  @override
  Future<GroupJoinCommandResult> invite(GroupInviteCommand command) async {
    final invalid = _validator.validateInvite(command);
    if (invalid != null) return GroupJoinCommandResult.failure(invalid);
    return _run((transaction, playerId, localDisplayByCharacterId) async {
      final groupRef = _groupRef(command.groupId);
      final group = _group(await transaction.get(groupRef));
      if (group == null) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupNotFound,
        );
      }
      if (group.status != GroupStatus.active) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupClosed,
        );
      }

      final callerMember = await transaction.get(
        groupRef.collection('members').doc(playerId),
      );
      if (!callerMember.exists) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.notGroupMember,
        );
      }

      final character = _character(
        await transaction.get(
          _firestore.collection('characters').doc(command.targetCharacterId),
        ),
        localDisplayByCharacterId: localDisplayByCharacterId,
      );
      if (character == null) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.invalidCharacter,
        );
      }
      if (character.ownerPlayerId == playerId) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.invalidRequest,
        );
      }

      final targetPlayerId = character.ownerPlayerId;
      final targetMember = await transaction.get(
        groupRef.collection('members').doc(targetPlayerId),
      );
      if (targetMember.exists) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.alreadyMember,
        );
      }

      final relationRef = groupRef
          .collection('joinRelations')
          .doc(targetPlayerId);
      final existing = _joinRelation(await transaction.get(relationRef));
      final now = _clock();
      if (existing != null && existing.isPendingAt(now)) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.requestAlreadyPending,
        );
      }

      final plan = GroupJoinWritePlan.invitation(
        groupId: command.groupId,
        requestedByPlayerId: playerId,
        character: character,
        groupName: group.name,
        groupRevision: group.revision,
        existingRelation: existing,
        serverTimestamp: FieldValue.serverTimestamp(),
        now: now,
      );
      transaction.set(relationRef, plan.joinRelationDocument!);
      transaction.set(
        _playerRelationRef(targetPlayerId, command.groupId),
        plan.playerRelation,
      );
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCommandResult.success(GroupRequestStatus.pending);
    });
  }

  @override
  Future<GroupJoinCommandResult> apply(GroupApplyCommand command) async {
    final invalid = _validator.validateApply(command);
    if (invalid != null) return GroupJoinCommandResult.failure(invalid);
    return _run((transaction, playerId, localDisplayByCharacterId) async {
      final groupRef = _groupRef(command.groupId);
      final group = _group(await transaction.get(groupRef));
      if (group == null) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupNotFound,
        );
      }
      if (group.status != GroupStatus.active) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupClosed,
        );
      }

      // 비회원은 members 하위를 읽을 수 없으므로 본인 요약으로 가입 여부를 본다.
      final membershipState = _mapper.toMembershipState(
        playerId: playerId,
        data: _data(await transaction.get(_membershipStateRef(playerId))),
      );
      if (membershipState.contains(command.groupId)) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.alreadyMember,
        );
      }

      final character = _character(
        await transaction.get(
          _firestore.collection('characters').doc(command.characterId),
        ),
        localDisplayByCharacterId: localDisplayByCharacterId,
      );
      if (character == null) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.invalidCharacter,
        );
      }
      if (character.ownerPlayerId != playerId) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.ownershipLost,
        );
      }

      final relationRef = groupRef.collection('joinRelations').doc(playerId);
      final existing = _joinRelation(await transaction.get(relationRef));
      final now = _clock();
      if (existing != null && existing.isPendingAt(now)) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.requestAlreadyPending,
        );
      }

      final statsRef = groupRef.collection('applicantStats').doc(playerId);
      final statsSnapshot = await transaction.get(statsRef);
      final statsData = _data(statsSnapshot);
      final stats = _mapper.toApplicantStats(
        groupId: command.groupId,
        playerId: playerId,
        data: statsData,
      );

      final plan = GroupJoinWritePlan.application(
        groupId: command.groupId,
        character: character,
        groupName: group.name,
        groupRevision: group.revision,
        existingRelation: existing,
        stats: stats,
        serverTimestamp: FieldValue.serverTimestamp(),
        now: now,
        statsCreatedAt: statsData?['createdAt'],
      );
      transaction.set(relationRef, plan.joinRelationDocument!);
      transaction.set(statsRef, plan.applicantStats!);
      transaction.set(
        _playerRelationRef(playerId, command.groupId),
        plan.playerRelation,
      );
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCommandResult.success(GroupRequestStatus.pending);
    });
  }

  @override
  Future<GroupJoinCommandResult> acceptInvitation(
    GroupInvitationDecisionCommand command,
  ) async {
    final invalid = _validator.validateDecision(command);
    if (invalid != null) return GroupJoinCommandResult.failure(invalid);
    return _run((transaction, playerId, localDisplayByCharacterId) async {
      final groupRef = _groupRef(command.groupId);
      final group = _group(await transaction.get(groupRef));
      if (group == null) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupNotFound,
        );
      }
      if (group.status != GroupStatus.active) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupClosed,
        );
      }

      final membershipState = _mapper.toMembershipState(
        playerId: playerId,
        data: _data(await transaction.get(_membershipStateRef(playerId))),
      );
      if (membershipState.contains(command.groupId)) {
        // 재시도가 membership을 한 번 더 만들지 않도록 현재 결과를 반환한다.
        return const GroupJoinCommandResult.success(
          GroupRequestStatus.accepted,
        );
      }
      if (membershipState.isAtLimit) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.activeGroupLimitReached,
        );
      }
      if (group.memberCount >= GroupMember.maxMemberCount) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupCapacityFull,
        );
      }

      final relationRef = groupRef.collection('joinRelations').doc(playerId);
      final relation = _joinRelation(await transaction.get(relationRef));
      final guard = _invitationGuard(
        relation,
        command.expectedRelationRevision,
        requirePending: true,
      );
      if (guard != null) return guard;

      final playerRelationRef = _playerRelationRef(playerId, command.groupId);
      final playerRelationCreatedAt = _data(
        await transaction.get(playerRelationRef),
      )?['createdAt'];

      final plan = GroupJoinWritePlan.invitationAccepted(
        relation: relation!,
        groupName: group.name,
        groupRevision: group.revision,
        groupMemberCount: group.memberCount,
        membershipState: membershipState,
        serverTimestamp: FieldValue.serverTimestamp(),
        playerRelationCreatedAt: playerRelationCreatedAt,
      );
      transaction.update(relationRef, plan.joinRelationPatch!);
      transaction.set(
        groupRef.collection('members').doc(playerId),
        plan.member!,
      );
      transaction.set(_membershipStateRef(playerId), plan.membershipState!);
      transaction.set(playerRelationRef, plan.playerRelation);
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCommandResult.success(GroupRequestStatus.accepted);
    });
  }

  @override
  Future<GroupJoinCommandResult> rejectInvitation(
    GroupInvitationDecisionCommand command,
  ) async {
    final invalid = _validator.validateDecision(command);
    if (invalid != null) return GroupJoinCommandResult.failure(invalid);
    return _run((transaction, playerId, localDisplayByCharacterId) async {
      final groupRef = _groupRef(command.groupId);
      final group = _group(await transaction.get(groupRef));
      if (group == null) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupNotFound,
        );
      }
      if (group.status != GroupStatus.active) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupClosed,
        );
      }

      final relationRef = groupRef.collection('joinRelations').doc(playerId);
      final relation = _joinRelation(await transaction.get(relationRef));
      final guard = _invitationGuard(
        relation,
        command.expectedRelationRevision,
        requirePending: false,
      );
      if (guard != null) return guard;
      if (relation!.status != GroupRequestStatus.pending) {
        // 이미 최종 상태면 역방향 변경 없이 현재 결과를 반환한다.
        return GroupJoinCommandResult.success(relation.status);
      }

      final playerRelationRef = _playerRelationRef(playerId, command.groupId);
      final playerRelationCreatedAt = _data(
        await transaction.get(playerRelationRef),
      )?['createdAt'];

      final plan = GroupJoinWritePlan.decision(
        relation: relation,
        status: GroupRequestStatus.rejected,
        groupName: group.name,
        groupRevision: group.revision,
        serverTimestamp: FieldValue.serverTimestamp(),
        playerRelationCreatedAt: playerRelationCreatedAt,
      );
      transaction.update(relationRef, plan.joinRelationPatch!);
      transaction.set(playerRelationRef, plan.playerRelation);
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCommandResult.success(GroupRequestStatus.rejected);
    });
  }

  @override
  Future<GroupJoinCommandResult> cancelInvitation(
    GroupInvitationCancelCommand command,
  ) async {
    final invalid = _validator.validateCancel(command);
    if (invalid != null) return GroupJoinCommandResult.failure(invalid);
    return _run((transaction, playerId, localDisplayByCharacterId) async {
      final groupRef = _groupRef(command.groupId);
      final group = _group(await transaction.get(groupRef));
      if (group == null) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupNotFound,
        );
      }
      if (group.status != GroupStatus.active) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupClosed,
        );
      }

      final callerMember = await transaction.get(
        groupRef.collection('members').doc(playerId),
      );
      if (!callerMember.exists) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.notGroupMember,
        );
      }

      final relationRef = groupRef
          .collection('joinRelations')
          .doc(command.targetPlayerId);
      final relation = _joinRelation(await transaction.get(relationRef));
      final guard = _invitationGuard(
        relation,
        command.expectedRelationRevision,
        requirePending: false,
      );
      if (guard != null) return guard;
      if (relation!.status != GroupRequestStatus.pending) {
        return GroupJoinCommandResult.success(relation.status);
      }
      // 발신자는 자기가 만든 초대만, 그룹장은 모든 초대를 취소한다.
      final isLeader =
          callerMember.data()?['role'] == GroupMemberRole.leader.name;
      if (relation.requestedByPlayerId != playerId && !isLeader) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.permissionDenied,
        );
      }

      final plan = GroupJoinWritePlan.decision(
        relation: relation,
        status: GroupRequestStatus.cancelled,
        groupName: group.name,
        groupRevision: group.revision,
        serverTimestamp: FieldValue.serverTimestamp(),
      );
      transaction.update(relationRef, plan.joinRelationPatch!);
      transaction.set(
        _playerRelationRef(command.targetPlayerId, command.groupId),
        plan.playerRelation,
      );
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCommandResult.success(GroupRequestStatus.cancelled);
    });
  }

  @override
  Future<GroupJoinCommandResult> leave(GroupLeaveCommand command) async {
    final invalid = _validator.validateLeave(command);
    if (invalid != null) return GroupJoinCommandResult.failure(invalid);
    return _run((transaction, playerId, localDisplayByCharacterId) async {
      final groupRef = _groupRef(command.groupId);
      final group = _group(await transaction.get(groupRef));
      if (group == null) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupNotFound,
        );
      }
      if (group.status != GroupStatus.active) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.groupClosed,
        );
      }

      final memberRef = groupRef.collection('members').doc(playerId);
      final memberSnapshot = await transaction.get(memberRef);
      if (!memberSnapshot.exists) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.notGroupMember,
        );
      }
      final memberData = memberSnapshot.data();
      if (memberData?['role'] == GroupMemberRole.leader.name) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.leaderCannotLeave,
        );
      }

      final membershipState = _mapper.toMembershipState(
        playerId: playerId,
        data: _data(await transaction.get(_membershipStateRef(playerId))),
      );
      if (!membershipState.contains(command.groupId)) {
        return const GroupJoinCommandResult.failure(
          GroupJoinFailure.invalidRequest,
        );
      }

      final plan = GroupLeaveWritePlan.regularMember(
        groupId: command.groupId,
        groupRevision: group.revision,
        groupMemberCount: group.memberCount,
        membershipState: membershipState,
        serverTimestamp: FieldValue.serverTimestamp(),
      );
      transaction.delete(memberRef);
      transaction.update(groupRef, plan.groupPatch);
      transaction.update(_membershipStateRef(playerId), plan.membershipState);
      transaction.delete(_playerRelationRef(playerId, command.groupId));
      return const GroupJoinCommandResult.completed();
    });
  }

  GroupJoinCommandResult? _invitationGuard(
    GroupJoinRelation? relation,
    int expectedRevision, {
    required bool requirePending,
  }) {
    if (relation == null) {
      return const GroupJoinCommandResult.failure(
        GroupJoinFailure.requestNotFound,
      );
    }
    if (relation.kind != GroupJoinRelationKind.invitation) {
      return const GroupJoinCommandResult.failure(
        GroupJoinFailure.invalidRequest,
      );
    }
    if (relation.revision != expectedRevision) {
      return const GroupJoinCommandResult.failure(
        GroupJoinFailure.revisionConflict,
      );
    }
    if (!requirePending) return null;
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
    return null;
  }

  @override
  Future<void> refreshMyDisplaySnapshot(
    GroupMemberDisplaySnapshotRefreshCommand command,
  ) async {
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null) throw StateError('Signed-in user required.');

    try {
      await _firestore.runTransaction((transaction) async {
        final bindingRef = _firestore.collection('authBindings').doc(authUid);
        final binding = await transaction.get(bindingRef);
        final bindingData = binding.data();
        final playerId = bindingData?['playerId'];
        if (bindingData?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty) {
          throw StateError('Active player binding required.');
        }

        final memberRef = _groupRef(
          command.groupId,
        ).collection('members').doc(playerId);
        final memberSnapshot = await transaction.get(memberRef);
        if (!memberSnapshot.exists) throw StateError('Membership required.');

        final memberData = memberSnapshot.data();
        final characterId = memberData?['displayCharacterIdSnapshot'];
        if (characterId is! String || characterId.isEmpty) {
          throw StateError('Display character required.');
        }

        final characterSnapshot = await transaction.get(
          _firestore.collection('characters').doc(characterId),
        );
        final characterData = characterSnapshot.data();
        if (!characterSnapshot.exists ||
            characterData?['status'] != 'active' ||
            characterData?['ownerPlayerId'] != playerId) {
          throw StateError('Active character ownership required.');
        }

        transaction.update(
          memberRef,
          GroupMemberSnapshotWritePlan.selfRefresh(
            className: command.snapshot.className,
            itemLevel: command.snapshot.itemLevel,
            combatPower: command.snapshot.combatPower,
            storedItemLevel: parseCharacterItemLevel(memberData?['itemLevelSnapshot']),
            storedCombatPower: parseCharacterItemLevel(memberData?['combatPowerSnapshot']),
            serverTimestamp: FieldValue.serverTimestamp(),
          ),
        );
      });
    } on Object {
      // 실패는 ViewModel이 안내하고, 저장된 목록 조회는 계속한다.
      rethrow;
    }
  }

  Future<GroupJoinCommandResult> _run(
    Future<GroupJoinCommandResult> Function(
      Transaction transaction,
      String playerId,
      Map<String, GroupMemberDisplaySnapshot> localDisplayByCharacterId,
    )
    action,
  ) async {
    final localDisplayByCharacterId = _localMemberDisplayLookup == null
        ? const <String, GroupMemberDisplaySnapshot>{}
        : await _localMemberDisplayLookup.loadByServerCharacterId();
    return GroupCommandRunner(
      firestore: _firestore,
      firebaseAuth: _firebaseAuth,
    ).run(
      (transaction, playerId) =>
          action(transaction, playerId, localDisplayByCharacterId),
    );
  }

  DocumentReference<Map<String, dynamic>> _groupRef(String groupId) =>
      _firestore.collection('groups').doc(groupId);

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

  GroupRequestCharacter? _character(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    Map<String, GroupMemberDisplaySnapshot> localDisplayByCharacterId =
        const {},
  }) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    final ownerPlayerId = data['ownerPlayerId'];
    final name = data['characterName'];
    final serverName = data['serverName'];
    final className = data['characterClassName'];
    if (data['status'] != 'active' ||
        ownerPlayerId is! String ||
        ownerPlayerId.isEmpty ||
        name is! String ||
        name.isEmpty ||
        serverName is! String ||
        serverName.isEmpty ||
        className is! String ||
        className.isEmpty) {
      return null;
    }
    final localDisplay = localDisplayByCharacterId[snapshot.id];
    return GroupRequestCharacter(
      characterId: snapshot.id,
      ownerPlayerId: ownerPlayerId,
      characterName: name,
      serverName: serverName,
      characterClassName: className,
      itemLevel:
          parseCharacterItemLevel(data['itemAvgLevel']) ??
          localDisplay?.itemLevel,
      combatPower:
          parseCharacterItemLevel(data['combatPower']) ??
          localDisplay?.combatPower,
    );
  }

  Map<String, Object?>? _data(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.exists
      ? Map<String, Object?>.from(snapshot.data() ?? const {})
      : null;

  static final _mapper = groupFirestoreMapper;
}
