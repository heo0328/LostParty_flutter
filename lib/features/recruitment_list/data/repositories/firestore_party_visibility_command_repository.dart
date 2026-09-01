import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/party_create_command.dart';
import '../../domain/entities/party_visibility_command.dart';
import '../../domain/repositories/party_visibility_command_repository.dart';
import '../mappers/party_visibility_write_plan.dart';

class FirestorePartyVisibilityCommandRepository
    implements PartyVisibilityCommandRepository {
  const FirestorePartyVisibilityCommandRepository({
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

    final recruitmentRef = _firestore
        .collection('recruitments')
        .doc(command.recruitmentId);
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pending = const [];
    try {
      pending = (await recruitmentRef
              .collection('applications')
              .where('status', isEqualTo: 'pending')
              .limit(20)
              .get())
          .docs;
    } on FirebaseException catch (error) {
      return PartyVisibilityResult.failure(_map(error.code));
    }

    return _run((transaction, playerId) async {
      final recruitment = await transaction.get(recruitmentRef);
      final data = recruitment.data();
      if (data == null) {
        return const PartyVisibilityResult.failure(
          PartyVisibilityFailure.notFound,
        );
      }
      if (data['revision'] != command.expectedRecruitmentRevision) {
        return const PartyVisibilityResult.failure(
          PartyVisibilityFailure.revisionConflict,
        );
      }
      if (data['status'] != 'active') {
        return const PartyVisibilityResult.failure(
          PartyVisibilityFailure.recruitmentClosed,
        );
      }
      if (data['leaderPlayerId'] != playerId) {
        return const PartyVisibilityResult.failure(
          PartyVisibilityFailure.unauthorized,
        );
      }
      final groupId = data['groupId'];
      if (groupId is! String || groupId.isEmpty) {
        return const PartyVisibilityResult.failure(
          PartyVisibilityFailure.notGroupLinked,
        );
      }
      final currentVisibility = data['visibility'];
      if (currentVisibility == command.visibility) {
        return const PartyVisibilityResult.success();
      }
      if (!RecruitmentVisibility.isValid('$currentVisibility')) {
        return const PartyVisibilityResult.failure(
          PartyVisibilityFailure.invalidRequest,
        );
      }

      if (command.visibility == RecruitmentVisibility.group) {
        final leaderMember = await transaction.get(
          _groupMember(groupId, playerId),
        );
        if (!leaderMember.exists) {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.notGroupMember,
          );
        }
        final memberIds = [
          for (final id in (data['memberPlayerIds'] as List?) ?? const [])
            if (id is String && id.isNotEmpty) id,
        ];
        for (final memberId in memberIds) {
          final member = await transaction.get(_groupMember(groupId, memberId));
          if (!member.exists) {
            return const PartyVisibilityResult.failure(
              PartyVisibilityFailure.nonGroupParticipants,
            );
          }
        }
        for (final application in pending) {
          final applicantId = application.id;
          final member = await transaction.get(
            _groupMember(groupId, applicantId),
          );
          if (!member.exists) {
            return const PartyVisibilityResult.failure(
              PartyVisibilityFailure.pendingNonGroupApplications,
            );
          }
        }
      }

      final listingRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('raidListings')
          .doc(command.recruitmentId);
      final listing = await transaction.get(listingRef);
      final plan = PartyVisibilityWritePlan.change(
        visibility: command.visibility,
        recruitmentRevision: command.expectedRecruitmentRevision,
        serverTimestamp: FieldValue.serverTimestamp(),
        currentRecruitment: Map<String, Object?>.from(data),
      );
      transaction.update(recruitmentRef, plan.recruitmentPatch);
      if (plan.listingDocument != null) {
        transaction.set(listingRef, plan.listingDocument!);
      }
      if (plan.deleteListing && listing.exists) {
        transaction.delete(listingRef);
      }
      return const PartyVisibilityResult.success();
    });
  }

  DocumentReference<Map<String, dynamic>> _groupMember(
    String groupId,
    String playerId,
  ) => _firestore
      .collection('groups')
      .doc(groupId)
      .collection('members')
      .doc(playerId);

  Future<PartyVisibilityResult> _run(
    Future<PartyVisibilityResult> Function(Transaction, String) action,
  ) async {
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
        final data = binding.data();
        final playerId = data?['playerId'];
        if (data?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty) {
          return const PartyVisibilityResult.failure(
            PartyVisibilityFailure.playerBindingMissing,
          );
        }
        return action(transaction, playerId);
      });
    } on FirebaseException catch (error) {
      return PartyVisibilityResult.failure(_map(error.code));
    } catch (_) {
      return const PartyVisibilityResult.failure(PartyVisibilityFailure.unknown);
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
