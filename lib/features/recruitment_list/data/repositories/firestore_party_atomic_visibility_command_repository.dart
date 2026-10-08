import '../mappers/party_raid_listing_document.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/party_create_command.dart';
import '../../domain/entities/party_visibility_command.dart';
import '../../domain/repositories/party_visibility_command_repository.dart';
import '../mappers/party_atomic_document_mapper.dart';
import '../mappers/party_atomic_visibility_write_plan.dart';

/// 새 Aggregate 집계 기반 공개↔그룹 전환 Repository.
///
/// 멤버·신청자 전원 그룹 membership 순회를 쓰지 않으며 운영 Router에는 아직
/// 연결하지 않는다.
class FirestorePartyAtomicVisibilityCommandRepository
    implements PartyVisibilityCommandRepository {
  const FirestorePartyAtomicVisibilityCommandRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<PartyVisibilityResult> setVisibility(
    PartyVisibilityCommand command,
  ) async {
    final invalid = const PartyVisibilityCommandValidator().validate(command);
    if (invalid != null) return PartyVisibilityResult.failure(invalid);

    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      return const PartyVisibilityResult.failure(
        PartyVisibilityFailure.unauthenticated,
      );
    }

    try {
      return await _firestore.runTransaction((transaction) async {
        final binding = await transaction.get(
          _firestore.collection('authBindings').doc(uid),
        );
        final bindingData = binding.data();
        final playerId = bindingData?['playerId'];
        if (bindingData?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty) {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.playerBindingMissing,
          );
        }

        final recruitmentRef = _firestore
            .collection('recruitments')
            .doc(command.recruitmentId);
        final recruitment = await transaction.get(recruitmentRef);
        final raw = recruitment.data();
        if (raw == null) {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.notFound,
          );
        }
        if (raw['revision'] != command.expectedRecruitmentRevision) {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.revisionConflict,
          );
        }
        if (raw['status'] != 'active') {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.recruitmentClosed,
          );
        }

        final aggregate = PartyAtomicDocumentMapper.aggregate(
          Map<String, Object?>.from(raw),
        );
        if (aggregate.leaderPlayerId != playerId) {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.unauthorized,
          );
        }
        final groupId = aggregate.groupId;
        if (groupId == null) {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.notGroupLinked,
          );
        }
        if (aggregate.visibility == command.visibility) {
          return const PartyVisibilityResult.success();
        }
        if (command.visibility == RecruitmentVisibility.group &&
            !aggregate.canBecomeGroupOnly) {
          if (aggregate.nonGroupMemberCount > 0) {
            return const PartyVisibilityResult.failure(
              PartyVisibilityFailure.nonGroupParticipants,
            );
          }
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.pendingNonGroupApplications,
          );
        }

        final groupRef = _firestore.collection('groups').doc(groupId);
        final group = await transaction.get(groupRef);
        final groupData = group.data();
        if (!group.exists || groupData?['status'] != 'active') {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.notGroupLinked,
          );
        }
        final leaderMember = await transaction.get(
          groupRef.collection('members').doc(playerId),
        );
        // 그룹→공개는 탈퇴한 파티장도 허용(Rules도 membership 불필요).
        // 공개→그룹만 현재 그룹 멤버십을 요구한다.
        if (command.visibility == RecruitmentVisibility.group &&
            !leaderMember.exists) {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.notGroupMember,
          );
        }
        final activeCount = groupData?['activeRecruitmentCount'];
        final groupRevision = groupData?['revision'];
        if (activeCount is! int || groupRevision is! int) {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.invalidRequest,
          );
        }

        final now = FieldValue.serverTimestamp();
        final plan = PartyAtomicVisibilityWritePlan(
          aggregate: aggregate,
          nextVisibility: command.visibility,
          groupActiveRecruitmentCount: activeCount,
          groupRevision: groupRevision,
          serverTimestamp: now,
        );
        final listingRef = groupRef
            .collection('raidListings')
            .doc(command.recruitmentId);
        transaction.update(recruitmentRef, plan.recruitmentPatch);
        transaction.update(groupRef, plan.groupPatch);
        if (plan.deleteListing) {
          transaction.delete(listingRef);
        } else if (plan.listingDocument != null) {
          transaction.set(
            listingRef,
            partyRaidListingDocument(
              currentRecruitment: raw,
              recruitmentPatch: plan.recruitmentPatch,
            ),
          );
        }
        return const PartyVisibilityResult.success();
      });
    } on FirebaseException catch (error) {
      return PartyVisibilityResult.failure(_map(error.code));
    } on FormatException {
      return const PartyVisibilityResult.failure(
        PartyVisibilityFailure.invalidRequest,
      );
    } on StateError {
      return const PartyVisibilityResult.failure(
        PartyVisibilityFailure.invalidRequest,
      );
    } on ArgumentError {
      return const PartyVisibilityResult.failure(
        PartyVisibilityFailure.invalidRequest,
      );
    } catch (_) {
      return const PartyVisibilityResult.failure(
        PartyVisibilityFailure.unknown,
      );
    }
  }

  PartyVisibilityFailure _map(String code) => switch (code) {
    'permission-denied' => PartyVisibilityFailure.permissionDenied,
    'unavailable' ||
    'deadline-exceeded' ||
    'aborted' ||
    'failed-precondition' => PartyVisibilityFailure.temporarilyUnavailable,
    _ => PartyVisibilityFailure.unknown,
  };
}
