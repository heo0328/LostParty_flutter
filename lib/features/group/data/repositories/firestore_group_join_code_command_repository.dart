import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/group_join_code.dart';
import '../../domain/entities/group_join_code_command.dart';
import '../../domain/entities/group_join_command.dart';
import '../../domain/entities/group_join_relation.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_request_character.dart';
import '../../domain/entities/group_member_display_snapshot.dart';
import '../../domain/entities/group_summary.dart';
import '../../domain/repositories/group_join_code_command_repository.dart';
import '../../domain/services/group_join_command_validator.dart';
import '../../domain/services/group_local_member_display_lookup.dart';
import '../mappers/group_create_write_plan.dart';
import '../mappers/group_document_mapper.dart';
import '../mappers/group_join_code_write_plan.dart';
import 'firestore_group_character_search_repository.dart';
import 'group_command_runner.dart';

/// 계약 §7·§8.7. 초대코드 생성·폐기·표시·즉시 가입을 한 Transaction으로 실행한다.
///
/// 코드 원문은 그룹 문서에 쓰지 않는다. 생성 직후 결과로만 반환하며, 폐기는
/// 클라이언트가 보관한 정확한 코드 문자열을 다시 받아야 한다.
class FirestoreGroupJoinCodeCommandRepository
    implements GroupJoinCodeCommandRepository {
  FirestoreGroupJoinCodeCommandRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    GroupLocalMemberDisplayLookup? localMemberDisplayLookup,
    DateTime Function() clock = DateTime.now,
    GroupJoinCode Function()? codeGenerator,
  }) : _firestore = firestore,
       _runner = GroupCommandRunner(
         firestore: firestore,
         firebaseAuth: firebaseAuth,
       ),
       _localMemberDisplayLookup = localMemberDisplayLookup,
       _clock = clock,
       _codeGenerator = codeGenerator ?? GroupJoinCode.generate;

  static const _validator = GroupJoinCommandValidator();
  static final _mapper = groupFirestoreMapper;

  final FirebaseFirestore _firestore;
  final GroupCommandRunner _runner;
  final GroupLocalMemberDisplayLookup? _localMemberDisplayLookup;
  final DateTime Function() _clock;
  final GroupJoinCode Function() _codeGenerator;

  @override
  Future<GroupJoinCodeCommandResult> createCode(
    GroupJoinCodeCreateCommand command,
  ) async {
    final invalid = _validator.validateJoinCodeCreate(command);
    if (invalid != null) return GroupJoinCodeCommandResult.failure(invalid);
    return _run((transaction, playerId) async {
      final groupRef = _groupRef(command.groupId);
      final context = await _leaderContext(transaction, groupRef, playerId);
      if (context.failure != null) {
        return GroupJoinCodeCommandResult.failure(context.failure!);
      }
      final group = context.group!;
      if (group.hasActiveJoinCode) {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.joinCodeActive,
        );
      }

      // 충돌 시 Transaction이 재시도하므로 매 시도마다 새 코드를 뽑는다.
      final code = _codeGenerator();
      final codeRef = _codeRef(code.value);
      if ((await transaction.get(codeRef)).exists) {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.temporarilyUnavailable,
        );
      }

      final plan = GroupJoinCodeWritePlan.created(
        groupId: command.groupId,
        code: code,
        createdByPlayerId: playerId,
        groupRevision: group.revision,
        serverTimestamp: FieldValue.serverTimestamp(),
      );
      transaction.set(codeRef, plan.joinCodeDocument!);
      transaction.update(groupRef, plan.groupPatch);
      return GroupJoinCodeCommandResult.success(code: code);
    });
  }

  @override
  Future<GroupJoinCodeCommandResult> revokeCode(
    GroupJoinCodeRevokeCommand command,
  ) async {
    final invalid = _validator.validateJoinCodeRevoke(command);
    if (invalid != null) return GroupJoinCodeCommandResult.failure(invalid);
    final code = GroupJoinCode.tryParse(command.code)!;
    return _run((transaction, playerId) async {
      final groupRef = _groupRef(command.groupId);
      final context = await _leaderContext(transaction, groupRef, playerId);
      if (context.failure != null) {
        return GroupJoinCodeCommandResult.failure(context.failure!);
      }
      final group = context.group!;
      if (!group.hasActiveJoinCode) {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.joinCodeMissing,
        );
      }

      final codeRef = _codeRef(code.value);
      final codeSnap = await transaction.get(codeRef);
      final codeData = codeSnap.data();
      if (!codeSnap.exists ||
          codeData == null ||
          codeData['groupId'] != command.groupId ||
          codeData['status'] != 'active') {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.joinCodeMissing,
        );
      }

      final plan = GroupJoinCodeWritePlan.revoked(
        groupRevision: group.revision,
        serverTimestamp: FieldValue.serverTimestamp(),
      );
      transaction.delete(codeRef);
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCodeCommandResult.success();
    });
  }

  @override
  Future<GroupJoinCodeCommandResult> setVisibility(
    GroupJoinCodeVisibilityCommand command,
  ) async {
    final invalid = _validator.validateJoinCodeVisibility(command);
    if (invalid != null) return GroupJoinCodeCommandResult.failure(invalid);
    return _run((transaction, playerId) async {
      final groupRef = _groupRef(command.groupId);
      final context = await _leaderContext(transaction, groupRef, playerId);
      if (context.failure != null) {
        return GroupJoinCodeCommandResult.failure(context.failure!);
      }
      final group = context.group!;
      if (group.joinCodeVisibleToMembers == command.visibleToMembers) {
        return GroupJoinCodeCommandResult.success(
          visibleToMembers: command.visibleToMembers,
        );
      }

      final plan = GroupJoinCodeWritePlan.visibility(
        visibleToMembers: command.visibleToMembers,
        groupRevision: group.revision,
        serverTimestamp: FieldValue.serverTimestamp(),
      );
      transaction.update(groupRef, plan.groupPatch);
      return GroupJoinCodeCommandResult.success(
        visibleToMembers: command.visibleToMembers,
      );
    });
  }

  @override
  Future<GroupJoinCodeCommandResult> joinByCode(
    GroupJoinByCodeCommand command,
  ) async {
    final invalid = _validator.validateJoinByCode(command);
    if (invalid != null) return GroupJoinCodeCommandResult.failure(invalid);
    final code = GroupJoinCode.tryParse(command.code)!;
    final localDisplayByCharacterId = _localMemberDisplayLookup == null
        ? const <String, GroupMemberDisplaySnapshot>{}
        : await _localMemberDisplayLookup.loadByServerCharacterId();
    return _run((transaction, playerId) async {
      final codeRef = _codeRef(code.value);
      final codeSnap = await transaction.get(codeRef);
      final codeData = codeSnap.data();
      if (!codeSnap.exists ||
          codeData == null ||
          codeData['status'] != 'active') {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.joinCodeMissing,
        );
      }
      final groupId = codeData['groupId'];
      if (groupId is! String || groupId.isEmpty) {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.unknown,
        );
      }

      final groupRef = _groupRef(groupId);
      final group = _group(await transaction.get(groupRef));
      if (group == null) {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.groupNotFound,
        );
      }
      if (group.status != GroupStatus.active) {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.groupClosed,
        );
      }

      final membershipState = _mapper.toMembershipState(
        playerId: playerId,
        data: _data(await transaction.get(_membershipStateRef(playerId))),
      );
      if (membershipState.contains(groupId)) {
        // 기존 멤버의 재시도는 membership을 다시 만들지 않는다.
        return const GroupJoinCodeCommandResult.success();
      }
      if (membershipState.isAtLimit) {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.activeGroupLimitReached,
        );
      }
      if (group.memberCount >= GroupMember.maxMemberCount) {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.groupCapacityFull,
        );
      }

      final character = _character(
        await transaction.get(
          _firestore.collection('characters').doc(command.characterId),
        ),
        localDisplayByCharacterId: localDisplayByCharacterId,
      );
      if (character == null) {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.invalidCharacter,
        );
      }
      if (character.ownerPlayerId != playerId) {
        return const GroupJoinCodeCommandResult.failure(
          GroupJoinFailure.ownershipLost,
        );
      }

      final relationRef = groupRef.collection('joinRelations').doc(playerId);
      final existing = _joinRelation(await transaction.get(relationRef));
      final playerRelationRef = _playerRelationRef(playerId, groupId);
      final existingPlayerRelation = await transaction.get(playerRelationRef);

      final plan = GroupJoinCodeWritePlan.joined(
        groupId: groupId,
        playerId: playerId,
        character: character,
        groupName: group.name,
        groupRevision: group.revision,
        groupMemberCount: group.memberCount,
        membershipState: membershipState,
        existingRelation: existing,
        serverTimestamp: FieldValue.serverTimestamp(),
        now: _clock(),
        playerRelationCreatedAt: existingPlayerRelation.data()?['createdAt'],
      );

      if (plan.joinRelationPatch != null) {
        transaction.update(relationRef, plan.joinRelationPatch!);
      }
      transaction.set(groupRef.collection('members').doc(playerId), plan.member!);
      transaction.set(_membershipStateRef(playerId), plan.membershipState!);
      transaction.set(playerRelationRef, plan.playerRelation!);
      transaction.update(groupRef, plan.groupPatch);
      return const GroupJoinCodeCommandResult.success();
    });
  }

  Future<GroupJoinCodeCommandResult> _run(
    Future<GroupJoinCodeCommandResult> Function(Transaction, String) action,
  ) => _runner.runMapped(
    onAuthFailure: GroupJoinCodeCommandResult.failure,
    onContractFailure: () =>
        const GroupJoinCodeCommandResult.failure(GroupJoinFailure.unknown),
    onInvalidRequest: () => const GroupJoinCodeCommandResult.failure(
      GroupJoinFailure.invalidRequest,
    ),
    onFirebaseFailure: (code) =>
        GroupJoinCodeCommandResult.failure(groupFirebaseFailure(code)),
    onUnknownFailure: () =>
        const GroupJoinCodeCommandResult.failure(GroupJoinFailure.unknown),
    action: action,
  );

  Future<_LeaderContext> _leaderContext(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> groupRef,
    String playerId,
  ) async {
    final group = _group(await transaction.get(groupRef));
    if (group == null) {
      return const _LeaderContext(
        failure: GroupJoinFailure.groupNotFound,
      );
    }
    if (group.status != GroupStatus.active) {
      return const _LeaderContext(failure: GroupJoinFailure.groupClosed);
    }
    final memberSnap = await transaction.get(
      groupRef.collection('members').doc(playerId),
    );
    if (!memberSnap.exists) {
      return const _LeaderContext(failure: GroupJoinFailure.notGroupMember);
    }
    final member = _mapper.toMember(
      GroupDocumentDto(
        id: memberSnap.id,
        data: Map<String, Object?>.from(memberSnap.data() ?? const {}),
      ),
    );
    if (!member.isLeader) {
      return const _LeaderContext(failure: GroupJoinFailure.notGroupLeader);
    }
    return _LeaderContext(group: group);
  }

  DocumentReference<Map<String, dynamic>> _groupRef(String groupId) =>
      _firestore.collection('groups').doc(groupId);

  DocumentReference<Map<String, dynamic>> _codeRef(String code) =>
      _firestore.collection('groupJoinCodes').doc(code);

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
          localDisplay?.itemLevel ??
          parseCharacterItemLevel(data['itemAvgLevel']),
      combatPower:
          localDisplay?.combatPower ??
          parseCharacterItemLevel(data['combatPower']),
    );
  }

  Map<String, Object?>? _data(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists) return null;
    return Map<String, Object?>.from(snapshot.data() ?? const {});
  }
}

class _LeaderContext {
  const _LeaderContext({this.group, this.failure});

  final GroupPublicSummary? group;
  final GroupJoinFailure? failure;
}
