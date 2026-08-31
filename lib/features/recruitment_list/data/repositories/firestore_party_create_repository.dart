import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/party_create_command.dart';
import '../../domain/repositories/party_create_repository.dart';
import '../../domain/services/party_create_command_validator.dart';
import '../../../account/data/mappers/weekly_raid_claim_document_id.dart';
import '../mappers/party_create_write_plan.dart';

class FirestorePartyCreateRepository implements PartyCreateRepository {
  const FirestorePartyCreateRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<PartyCreateResult> create(PartyCreateCommand command) async {
    const validator = PartyCreateCommandValidator();
    final requestFailure = validator.validate(command);
    if (requestFailure != null) return PartyCreateResult.failure(requestFailure);
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null) {
      return const PartyCreateResult.failure(
        PartyCreateFailure.unauthenticated,
      );
    }

    try {
      return await _firestore.runTransaction((transaction) async {
        final bindingRef = _firestore.collection('authBindings').doc(authUid);
        final binding = await transaction.get(bindingRef);
        final bindingData = binding.data();
        final playerId = bindingData?['playerId'];
        if (bindingData?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty) {
          return const PartyCreateResult.failure(
            PartyCreateFailure.playerBindingMissing,
          );
        }

        final characterRef = _firestore
            .collection('characters')
            .doc(command.leaderCharacterId);
        final recruitmentRef = _firestore
            .collection('recruitments')
            .doc(command.recruitmentId);
        final assignmentRef = _firestore
            .collection('players')
            .doc(playerId)
            .collection('activeRaidAssignments')
            .doc('${command.leaderCharacterId}_${command.metadata.raidId}');
        final claimRef = _firestore
            .collection('players')
            .doc(playerId)
            .collection('weeklyRaidClaims')
            .doc(
              WeeklyRaidClaimDocumentId.create(
                cycleKey: command.cycleKey,
                characterId: command.leaderCharacterId,
                raidId: command.metadata.raidId,
              ),
            );

        final character = await transaction.get(characterRef);
        final recruitment = await transaction.get(recruitmentRef);
        final assignment = await transaction.get(assignmentRef);
        final claim = await transaction.get(claimRef);
        final characterData = character.data();

        DocumentSnapshot<Map<String, dynamic>>? group;
        DocumentSnapshot<Map<String, dynamic>>? membership;
        final groupId = command.groupId;
        if (groupId != null) {
          final groupRef = _firestore.collection('groups').doc(groupId);
          final membershipRef = groupRef.collection('members').doc(playerId);
          group = await transaction.get(groupRef);
          membership = await transaction.get(membershipRef);
        }

        if (!character.exists || characterData?['status'] != 'active') {
          return const PartyCreateResult.failure(
            PartyCreateFailure.invalidCharacter,
          );
        }
        if (characterData?['ownerPlayerId'] != playerId) {
          return const PartyCreateResult.failure(
            PartyCreateFailure.ownershipLost,
          );
        }
        if (recruitment.exists) {
          return const PartyCreateResult.failure(
            PartyCreateFailure.idConflict,
          );
        }
        if (assignment.exists) {
          return const PartyCreateResult.failure(
            PartyCreateFailure.participationConflict,
          );
        }
        if (claim.exists) {
          return const PartyCreateResult.failure(
            PartyCreateFailure.weeklyRaidCompleted,
          );
        }
        if (groupId != null &&
            (group?.data()?['status'] != 'active' ||
                membership == null ||
                !membership.exists)) {
          return const PartyCreateResult.failure(
            PartyCreateFailure.notGroupMember,
          );
        }

        final verifiedName = characterData?['characterName'];
        final verifiedClass = characterData?['characterClassName'];
        final verifiedItemLevel = _parseItemLevel(
          characterData?['itemAvgLevel'],
        );
        if (verifiedName is! String ||
            verifiedName.isEmpty ||
            verifiedClass is! String ||
            verifiedClass.isEmpty ||
            verifiedItemLevel == null ||
            verifiedItemLevel < command.metadata.minItemLevel) {
          return const PartyCreateResult.failure(
            PartyCreateFailure.invalidCharacter,
          );
        }

        final now = FieldValue.serverTimestamp();
        final plan = PartyCreateWritePlan.fromCommand(
          command: command,
          playerId: playerId,
          serverTimestamp: now,
          verifiedCharacterName: verifiedName,
          verifiedClassName: verifiedClass,
          verifiedItemLevel: verifiedItemLevel,
        );
        final memberRef = recruitmentRef
            .collection('members')
            .doc(playerId);
        transaction.set(recruitmentRef, plan.recruitment);
        transaction.set(memberRef, plan.leaderMembership);
        transaction.set(assignmentRef, plan.assignment);
        final listing = plan.groupRaidListing;
        if (groupId != null && listing != null) {
          transaction.set(
            _firestore
                .collection('groups')
                .doc(groupId)
                .collection('raidListings')
                .doc(command.recruitmentId),
            listing,
          );
        }
        return PartyCreateResult.success(command.recruitmentId);
      });
    } on FirebaseException catch (error) {
      return PartyCreateResult.failure(_firebaseFailure(error.code));
    } catch (_) {
      return const PartyCreateResult.failure(PartyCreateFailure.unknown);
    }
  }
}

double? _parseItemLevel(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '').trim());
  }
  return null;
}

PartyCreateFailure _firebaseFailure(String code) => switch (code) {
  'permission-denied' => PartyCreateFailure.permissionDenied,
  'unavailable' || 'deadline-exceeded' || 'aborted' =>
    PartyCreateFailure.temporarilyUnavailable,
  _ => PartyCreateFailure.unknown,
};
