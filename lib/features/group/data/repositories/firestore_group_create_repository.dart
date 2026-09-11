import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/group_create_command.dart';
import '../../domain/entities/group_create_result.dart';
import '../../domain/repositories/group_create_repository.dart';
import '../../domain/services/group_create_command_validator.dart';
import '../../domain/services/group_local_member_display_lookup.dart';
import '../mappers/group_create_write_plan.dart';
import '../mappers/group_document_mapper.dart';
import 'firestore_group_character_search_repository.dart';

/// 계약 §8.1. authBinding을 먼저 읽고 모든 검증 읽기를 끝낸 뒤에만 네 문서를 쓴다.
class FirestoreGroupCreateRepository implements GroupCreateRepository {
  const FirestoreGroupCreateRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    GroupLocalMemberDisplayLookup? localMemberDisplayLookup,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth,
       _localMemberDisplayLookup = localMemberDisplayLookup;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final GroupLocalMemberDisplayLookup? _localMemberDisplayLookup;

  @override
  Future<GroupCreateResult> create(GroupCreateCommand command) async {
    const validator = GroupCreateCommandValidator();
    final requestFailure = validator.validate(command);
    if (requestFailure != null) return GroupCreateResult.failure(requestFailure);
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null) {
      return const GroupCreateResult.failure(
        GroupCreateFailure.unauthenticated,
      );
    }

    try {
      final localDisplay = await _localMemberDisplayLookup?.forServerCharacterId(
        command.representativeCharacterId,
      );
      return await _firestore.runTransaction((transaction) async {
        final bindingRef = _firestore.collection('authBindings').doc(authUid);
        final binding = await transaction.get(bindingRef);
        final bindingData = binding.data();
        final playerId = bindingData?['playerId'];
        if (bindingData?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty) {
          return const GroupCreateResult.failure(
            GroupCreateFailure.playerBindingMissing,
          );
        }

        final playerRef = _firestore.collection('players').doc(playerId);
        final characterRef = _firestore
            .collection('characters')
            .doc(command.representativeCharacterId);
        final player = await transaction.get(playerRef);
        final character = await transaction.get(characterRef);
        if (player.data()?['status'] != 'active') {
          return const GroupCreateResult.failure(
            GroupCreateFailure.playerBindingMissing,
          );
        }

        final characterData = character.data();
        if (!character.exists) {
          return const GroupCreateResult.failure(
            GroupCreateFailure.serverDataMissing,
          );
        }
        if (characterData?['status'] != 'active') {
          return const GroupCreateResult.failure(
            GroupCreateFailure.invalidCharacter,
          );
        }
        if (characterData?['ownerPlayerId'] != playerId) {
          return const GroupCreateResult.failure(
            GroupCreateFailure.ownershipLost,
          );
        }
        final gameAccountId = characterData?['gameAccountId'];
        if (gameAccountId is! String || gameAccountId.isEmpty) {
          return const GroupCreateResult.failure(
            GroupCreateFailure.invalidCharacter,
          );
        }
        final ownership = await transaction.get(
          _firestore
              .collection('playerGameAccounts')
              .doc('${playerId}_$gameAccountId'),
        );
        if (ownership.data()?['status'] != 'active') {
          return const GroupCreateResult.failure(
            GroupCreateFailure.ownershipLost,
          );
        }

        final characterName = characterData?['characterName'];
        final serverName = characterData?['serverName'];
        final className = characterData?['characterClassName'];
        if (characterName is! String ||
            characterName.isEmpty ||
            serverName is! String ||
            serverName.isEmpty ||
            className is! String ||
            className.isEmpty) {
          return const GroupCreateResult.failure(
            GroupCreateFailure.invalidCharacter,
          );
        }

        final membershipStateRef = _firestore
            .collection('players')
            .doc(playerId)
            .collection('groupMembershipState')
            .doc(GroupCreateWritePlan.membershipStateDocumentId);
        final membershipStateSnapshot = await transaction.get(
          membershipStateRef,
        );
        final membershipState = _mapper.toMembershipState(
          playerId: playerId,
          data: membershipStateSnapshot.exists
              ? Map<String, Object?>.from(membershipStateSnapshot.data() ?? {})
              : null,
        );
        if (membershipState.isAtLimit) {
          return const GroupCreateResult.failure(
            GroupCreateFailure.activeGroupLimitReached,
          );
        }

        final groupRef = _firestore.collection('groups').doc();
        final plan = GroupCreateWritePlan.fromCommand(
          command: command,
          groupId: groupRef.id,
          playerId: playerId,
          serverTimestamp: FieldValue.serverTimestamp(),
          verifiedCharacterName: characterName,
          verifiedServerName: serverName,
          verifiedClassName: className,
          verifiedItemLevel:
              localDisplay?.itemLevel ??
              parseCharacterItemLevel(characterData?['itemAvgLevel']),
          verifiedCombatPower:
              localDisplay?.combatPower ??
              parseCharacterItemLevel(characterData?['combatPower']),
          verifiedGemValidation: localDisplay?.gemValidation,
          membershipState: membershipState,
        );
        transaction.set(groupRef, plan.group);
        transaction.set(
          groupRef.collection('members').doc(playerId),
          plan.leaderMember,
        );
        transaction.set(membershipStateRef, plan.membershipState);
        transaction.set(
          _firestore
              .collection('players')
              .doc(playerId)
              .collection('groupRelations')
              .doc(groupRef.id),
          plan.memberRelation,
        );
        return GroupCreateResult.success(groupRef.id);
      });
    } on GroupContractException {
      return const GroupCreateResult.failure(GroupCreateFailure.unknown);
    } on FirebaseException catch (error) {
      return GroupCreateResult.failure(_firebaseFailure(error.code));
    } catch (_) {
      return const GroupCreateResult.failure(GroupCreateFailure.unknown);
    }
  }

  static final _mapper = GroupDocumentMapper(
    toDateTime: (value) => switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      _ => throw const FormatException('Expected Firestore Timestamp.'),
    },
  );
}

/// 계약 §11. permission-denied와 일시 불가(unavailable/aborted/failed-precondition)를 구분한다.
GroupCreateFailure _firebaseFailure(String code) => switch (code) {
  'permission-denied' => GroupCreateFailure.permissionDenied,
  'unavailable' ||
  'deadline-exceeded' ||
  'aborted' ||
  'failed-precondition' =>
    GroupCreateFailure.temporarilyUnavailable,
  _ => GroupCreateFailure.unknown,
};
