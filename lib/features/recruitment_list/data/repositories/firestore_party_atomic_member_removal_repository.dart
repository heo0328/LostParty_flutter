import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_membership_command.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/repositories/party_atomic_member_removal_repository.dart';
import '../mappers/party_atomic_document_mapper.dart';
import '../mappers/party_atomic_member_removal_write_plan.dart';

/// 새 Aggregate 구조용 탈퇴·추방 Repository.
///
/// 전체 파티원 또는 개인 이벤트를 순회하지 않으며 운영 Router에 연결된다.
class FirestorePartyAtomicMemberRemovalRepository
    implements PartyAtomicMemberRemovalRepository {
  const FirestorePartyAtomicMemberRemovalRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<PartyMembershipResult> remove(
    PartyRemoveMemberCommand command,
    PartyAtomicMemberRemovalType type,
  ) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.unauthenticated,
      );
    }
    try {
      return await _firestore.runTransaction((transaction) async {
        final binding = await transaction.get(
          _firestore.collection('authBindings').doc(uid),
        );
        final bindingData = binding.data();
        final actorPlayerId = bindingData?['playerId'];
        if (bindingData?['status'] != 'active' ||
            actorPlayerId is! String ||
            actorPlayerId.isEmpty) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.playerBindingMissing,
          );
        }

        final recruitmentRef = _firestore
            .collection('recruitments')
            .doc(command.recruitmentId);
        final recruitment = await transaction.get(recruitmentRef);
        final raw = recruitment.data();
        if (raw == null) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.notFound,
          );
        }
        final aggregate = PartyAtomicDocumentMapper.aggregate(
          Map<String, Object?>.from(raw),
        );
        if (aggregate.revision != command.expectedRecruitmentRevision) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.revisionConflict,
          );
        }

        final targetSlot = aggregate.partySlots
            .where((slot) => slot.playerId == command.targetPlayerId)
            .firstOrNull;
        if (targetSlot == null) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.notFound,
          );
        }
        final targetMembershipRef = recruitmentRef
            .collection('members')
            .doc(command.targetPlayerId);
        final targetMembership = await transaction.get(targetMembershipRef);
        if (!targetMembership.exists) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.notFound,
          );
        }

        PartyLeaderSuccessorSnapshot? successorSnapshot;
        DocumentReference<Map<String, dynamic>>? successorMembershipRef;
        if (command.targetPlayerId == aggregate.leaderPlayerId &&
            aggregate.partySlots.length > 1) {
          final successor = aggregate.partySlots
              .where((slot) => slot.playerId != command.targetPlayerId)
              .first;
          successorMembershipRef = recruitmentRef
              .collection('members')
              .doc(successor.playerId);
          final snapshot = await transaction.get(successorMembershipRef);
          final data = snapshot.data();
          final characterName = data?['characterNameSnapshot'];
          final className = data?['classNameSnapshot'];
          if (characterName is! String || className is! String) {
            return const PartyMembershipResult.failure(
              PartyMembershipFailure.invalidRequest,
            );
          }
          successorSnapshot = PartyLeaderSuccessorSnapshot(
            playerId: successor.playerId,
            characterName: characterName,
            className: className,
          );
        }

        var canResolveLostQualification = false;
        if (type == PartyAtomicMemberRemovalType.lostGroupQualification) {
          final groupId = aggregate.groupId;
          if (groupId == null ||
              !aggregate.partySlots.any(
                (slot) => slot.playerId == actorPlayerId,
              )) {
            return const PartyMembershipResult.failure(
              PartyMembershipFailure.unauthorized,
            );
          }
          final groupRef = _firestore.collection('groups').doc(groupId);
          final actorGroupMember = await transaction.get(
            groupRef.collection('members').doc(actorPlayerId),
          );
          final targetGroupMember = await transaction.get(
            groupRef.collection('members').doc(command.targetPlayerId),
          );
          canResolveLostQualification =
              actorGroupMember.exists && !targetGroupMember.exists;
        }

        final raidId = raw['raidId'];
        if (raidId is! String || raidId.isEmpty) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.invalidRequest,
          );
        }
        final raidStateRef = _firestore
            .collection('players')
            .doc(command.targetPlayerId)
            .collection('raidStates')
            .doc(
              PartyRaidState.documentIdFor(
                characterId: targetSlot.characterId,
                raidId: raidId,
              ),
            );
        // A leader cannot read another player's private raidState. Its delete
        // is validated against the post-command aggregate by Firestore Rules.
        if (command.targetPlayerId == actorPlayerId) {
          final raidState = await transaction.get(raidStateRef);
          if (!raidState.exists ||
              raidState.data()?['recruitmentId'] != command.recruitmentId ||
              raidState.data()?['status'] != 'active') {
            return const PartyMembershipResult.failure(
              PartyMembershipFailure.participationConflict,
            );
          }
        }

        final now = FieldValue.serverTimestamp();
        final plan = PartyAtomicMemberRemovalWritePlan(
          aggregate: aggregate,
          rules: _rules(raw),
          targetPlayerId: command.targetPlayerId,
          actorPlayerId: actorPlayerId,
          type: type,
          raidId: raidId,
          serverTimestamp: now,
          successorSnapshot: successorSnapshot,
          actorCanResolveLostGroupQualification: canResolveLostQualification,
        );
        transaction.update(recruitmentRef, plan.recruitmentPatch);
        transaction.delete(targetMembershipRef);
        transaction.delete(raidStateRef);
        if (successorMembershipRef != null &&
            plan.successorMembershipPatch != null) {
          transaction.update(
            successorMembershipRef,
            plan.successorMembershipPatch!,
          );
        }
        transaction.set(
          _firestore
              .collection('partyEvents')
              .doc(plan.event['eventId']! as String),
          plan.event,
        );
        return const PartyMembershipResult.success();
      });
    } on FirebaseException catch (error, stackTrace) {
      assert(() {
        debugPrint('PartyAtomicMemberRemoval ${error.code}: $stackTrace');
        return true;
      }());
      return PartyMembershipResult.failure(_firebaseFailure(error.code));
    } on ArgumentError {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.invalidRequest,
      );
    } on FormatException {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.invalidRequest,
      );
    } on StateError {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.unauthorized,
      );
    } catch (_) {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.unknown,
      );
    }
  }

  RecruitmentPartyRules _rules(Map<String, dynamic> data) =>
      RecruitmentPartyRules(
        partyCount: _positiveInt(data, 'partyCount'),
        membersPerParty: _positiveInt(data, 'membersPerParty'),
        supportsPerParty: _nonNegativeInt(data, 'supportsPerParty'),
        maxDealersPerClassPerParty: _positiveInt(
          data,
          'maxDealersPerClassPerParty',
        ),
      );

  int _positiveInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int && value > 0) return value;
    throw FormatException('$key 값이 올바르지 않습니다.');
  }

  int _nonNegativeInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int && value >= 0) return value;
    throw FormatException('$key 값이 올바르지 않습니다.');
  }

  PartyMembershipFailure _firebaseFailure(String code) => switch (code) {
    'permission-denied' => PartyMembershipFailure.permissionDenied,
    'aborted' => PartyMembershipFailure.revisionConflict,
    'unavailable' ||
    'deadline-exceeded' ||
    'failed-precondition' => PartyMembershipFailure.temporarilyUnavailable,
    _ => PartyMembershipFailure.unknown,
  };
}
