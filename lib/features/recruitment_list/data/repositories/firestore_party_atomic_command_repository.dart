import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/party_atomic_command.dart';
import '../../domain/repositories/party_atomic_command_repository.dart';
import '../mappers/party_atomic_document_mapper.dart';
import '../mappers/party_atomic_write_plan.dart';

class FirestorePartyAtomicCommandRepository
    implements PartyAtomicCommandRepository {
  const FirestorePartyAtomicCommandRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<PartyAtomicCommandResult> execute(PartyCommandEnvelope command) async {
    var attempt = 0;
    var stage = 'authentication';
    void trace(String phase, [String details = '']) {
      stage = phase;
      if (kDebugMode) {
        debugPrint(
          'PartyAtomicLifecycle id=${command.commandId} '
          'room=${command.recruitmentId} attempt=$attempt phase=$phase '
          'cycle=${command.expectedCycleKey} expected=${command.expectedRevision} $details',
        );
      }
    }

    trace(stage);
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const PartyAtomicCommandResult.failure(
        PartyAtomicCommandFailure.unauthenticated,
      );
    }
    try {
      if (command.type == PartyAtomicCommandType.advanceCycle) {
        trace('availability-certification');
        final preflight = await _certifyAdvance(command, uid);
        if (preflight != null) return preflight;
      }
      final result = await _firestore.runTransaction((transaction) async {
        attempt++;
        trace('binding-read');
        final binding = await transaction.get(
          _firestore.collection('authBindings').doc(uid),
        );
        final bindingData = binding.data();
        final playerId = bindingData?['playerId'];
        if (bindingData?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty) {
          return const PartyAtomicCommandResult.failure(
            PartyAtomicCommandFailure.playerBindingMissing,
          );
        }
        if (playerId != command.actorPlayerId) {
          return const PartyAtomicCommandResult.failure(
            PartyAtomicCommandFailure.unauthorized,
          );
        }

        final recruitmentRef = _firestore
            .collection('recruitments')
            .doc(command.recruitmentId);
        trace('recruitment-read');
        final recruitmentSnapshot = await transaction.get(recruitmentRef);
        final raw = recruitmentSnapshot.data();
        if (raw == null) {
          return const PartyAtomicCommandResult.failure(
            PartyAtomicCommandFailure.notFound,
          );
        }
        final aggregate = PartyAtomicDocumentMapper.aggregate(
          Map<String, Object?>.from(raw),
        );
        trace('validate', 'actual=${aggregate.revision}');
        if (aggregate.lastCommandId == command.commandId &&
            aggregate.revision == command.expectedRevision + 1) {
          return PartyAtomicCommandResult.applied(revision: aggregate.revision);
        }
        if (aggregate.revision != command.expectedRevision) {
          return const PartyAtomicCommandResult.failure(
            PartyAtomicCommandFailure.revisionConflict,
          );
        }
        final actorAllowed =
            aggregate.leaderPlayerId == playerId ||
            (command.type == PartyAtomicCommandType.incompleteEnd &&
                aggregate.partySlots.any((slot) => slot.playerId == playerId));
        if (!actorAllowed) {
          return const PartyAtomicCommandResult.failure(
            PartyAtomicCommandFailure.unauthorized,
          );
        }

        final plan = PartyAtomicWritePlan(
          command: command,
          aggregate: aggregate,
          serverTimestamp: FieldValue.serverTimestamp(),
          incrementOne: FieldValue.increment(1),
        );
        trace(
          'write-plan',
          'roles=${aggregate.partySlots.map((s) => '${s.playerId}/${s.characterId}:${s.role.name}').join(',')} '
              'targets=${command.targets.map((t) => t.pathKey).join(',')} '
              'targetServerStatesRead=false',
        );
        final stateRefs = <String, DocumentReference<Map<String, dynamic>>>{};
        for (final target in command.targets) {
          final ref = _firestore
              .collection('players')
              .doc(target.playerId)
              .collection('raidStates')
              .doc(target.raidStateId);
          stateRefs[target.pathKey] = ref;
        }

        final recruitmentPatch = Map<String, Object?>.from(
          plan.recruitmentPatch,
        );
        if (command.type == PartyAtomicCommandType.advanceCycle) {
          recruitmentPatch['cycleStartedAt'] = Timestamp.fromDate(
            command.nextCycleStartedAt!.toUtc(),
          );
          recruitmentPatch['cycleEndsAt'] = Timestamp.fromDate(
            command.nextCycleEndsAt!.toUtc(),
          );
        }
        final groupId = aggregate.groupId;
        if (groupId != null) {
          if (plan.closesActiveGroupRecruitment) {
            final groupRef = _firestore.collection('groups').doc(groupId);
            final group = await transaction.get(groupRef);
            final count = group.data()?['activeRecruitmentCount'];
            if (count is! int || count <= 0) {
              return const PartyAtomicCommandResult.failure(
                PartyAtomicCommandFailure.revisionConflict,
              );
            }
            final nextCount = count - 1;
            recruitmentPatch['groupActiveRecruitmentCountAfter'] = nextCount;
            transaction.update(groupRef, {
              'activeRecruitmentCount': nextCount,
              'lastRecruitmentId': command.recruitmentId,
              'revision': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          final listingRef = _firestore
              .collection('groups')
              .doc(groupId)
              .collection('raidListings')
              .doc(command.recruitmentId);
          if (plan.groupListingAction == PartyGroupListingWriteAction.delete) {
            transaction.delete(listingRef);
          } else if (plan.groupListingAction ==
              PartyGroupListingWriteAction.update) {
            transaction.update(
              listingRef,
              plan.listingPatchAfterRecruitmentChange(
                currentRecruitment: raw,
                appliedRecruitmentPatch: recruitmentPatch,
              ),
            );
          }
        }

        trace(
          'enqueue-writes',
          'recruitmentKeys=${recruitmentPatch.keys.join(',')}',
        );
        transaction.update(recruitmentRef, recruitmentPatch);
        for (final write in plan.raidStateWrites) {
          final ref = stateRefs[write.target.pathKey]!;
          if (write.action == PartyRaidStateWriteAction.delete) {
            transaction.delete(ref);
          } else if (write.action == PartyRaidStateWriteAction.upsert) {
            transaction.set(ref, {
              ...write.patch!,
              if (write.removeCompletedAt) 'completedAt': FieldValue.delete(),
            }, SetOptions(merge: true));
          } else {
            transaction.update(ref, write.patch!);
          }
        }
        transaction.set(
          _firestore.collection('partyEvents').doc(command.commandId),
          plan.eventDocument,
        );
        trace('commit-pending');
        return PartyAtomicCommandResult.applied(
          revision: command.expectedRevision + 1,
        );
      });
      trace(
        result.isApplied ? 'committed' : 'rejected',
        'failure=${result.failure}',
      );
      return result;
    } on FirebaseException catch (error, stackTrace) {
      assert(() {
        debugPrint(
          'PartyAtomicLifecycle id=${command.commandId} attempt=$attempt '
          'failedPhase=$stage code=${error.code} message=${error.message}: $stackTrace',
        );
        return true;
      }());
      return PartyAtomicCommandResult.failure(_mapFirebase(error.code));
    } on FormatException {
      return const PartyAtomicCommandResult.failure(
        PartyAtomicCommandFailure.invalidRequest,
      );
    } on ArgumentError {
      return const PartyAtomicCommandResult.failure(
        PartyAtomicCommandFailure.invalidRequest,
      );
    } on StateError {
      return const PartyAtomicCommandResult.failure(
        PartyAtomicCommandFailure.revisionConflict,
      );
    } catch (_) {
      return const PartyAtomicCommandResult.failure(
        PartyAtomicCommandFailure.unknown,
      );
    }
  }

  @override
  Future<PartyCommandAggregate?> findAggregate(String recruitmentId) async {
    if (recruitmentId.isEmpty) return null;
    try {
      final data =
          (await _firestore.collection('recruitments').doc(recruitmentId).get())
              .data();
      if (data == null) return null;
      return PartyAtomicDocumentMapper.aggregate(
        Map<String, Object?>.from(data),
      );
    } on FirebaseException {
      return null;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  Future<PartyAtomicCommandResult?> _certifyAdvance(
    PartyCommandEnvelope command,
    String uid,
  ) async {
    // Each transaction audits one target. No private peer state is read by the
    // leader. A failed audit cannot change the room or any participation state.
    for (var index = 0; index < command.targets.length; index++) {
      final rejected = await _firestore.runTransaction<PartyAtomicCommandResult?>((
        tx,
      ) async {
        final binding = (await tx.get(
          _firestore.collection('authBindings').doc(uid),
        )).data();
        if (binding?['status'] != 'active' ||
            binding?['playerId'] != command.actorPlayerId) {
          return const PartyAtomicCommandResult.failure(
            PartyAtomicCommandFailure.unauthorized,
          );
        }
        final raw = (await tx.get(
          _firestore.collection('recruitments').doc(command.recruitmentId),
        )).data();
        if (raw == null)
          return const PartyAtomicCommandResult.failure(
            PartyAtomicCommandFailure.notFound,
          );
        final aggregate = PartyAtomicDocumentMapper.aggregate(raw);
        if (aggregate.lastCommandId == command.commandId &&
            aggregate.revision == command.expectedRevision + 1) {
          return PartyAtomicCommandResult.applied(revision: aggregate.revision);
        }
        if (aggregate.revision != command.expectedRevision) {
          return const PartyAtomicCommandResult.failure(
            PartyAtomicCommandFailure.revisionConflict,
          );
        }
        if (aggregate.leaderPlayerId != command.actorPlayerId) {
          return const PartyAtomicCommandResult.failure(
            PartyAtomicCommandFailure.unauthorized,
          );
        }
        // Validate the unchanged public command contract before the first write.
        PartyAtomicWritePlan(
          command: command,
          aggregate: aggregate,
          serverTimestamp: FieldValue.serverTimestamp(),
          incrementOne: FieldValue.increment(1),
        );
        final slot = aggregate.partySlots[index];
        final stateId = PartyRaidState.documentIdFor(
          characterId: slot.characterId,
          raidId: aggregate.raidId,
        );
        tx.set(
          _firestore
              .collection('players')
              .doc(slot.playerId)
              .collection('raidStates')
              .doc(stateId),
          {
            'playerId': slot.playerId,
            'characterId': slot.characterId,
            'raidId': aggregate.raidId,
            'ownershipRevision': slot.ownershipRevision ?? 0,
            'guardSchemaVersion': 1,
            'guardRecruitmentId': command.recruitmentId,
            'guardRoomRevision': command.expectedRevision,
            'guardCycleKey': command.nextCycleKey,
            'guardCycleStartedAt': Timestamp.fromDate(
              command.nextCycleStartedAt!.toUtc(),
            ),
            'guardCycleEndsAt': Timestamp.fromDate(
              command.nextCycleEndsAt!.toUtc(),
            ),
            'guardSlotIndex': index,
            'guardCheckedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return null;
      });
      if (rejected != null) return rejected;
    }
    return null;
  }

  PartyAtomicCommandFailure _mapFirebase(String code) => switch (code) {
    'permission-denied' => PartyAtomicCommandFailure.permissionDenied,
    'aborted' => PartyAtomicCommandFailure.revisionConflict,
    'unavailable' ||
    'deadline-exceeded' ||
    'failed-precondition' => PartyAtomicCommandFailure.temporarilyUnavailable,
    _ => PartyAtomicCommandFailure.unknown,
  };
}
