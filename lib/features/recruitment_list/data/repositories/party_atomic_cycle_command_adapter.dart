import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_cycle_command.dart';
import '../../domain/policies/party_cycle_policy.dart';
import '../../domain/repositories/party_atomic_command_repository.dart';
import '../../domain/repositories/party_cycle_command_repository.dart';
import '../../domain/services/party_cycle_command_validator.dart';
import '../mappers/party_atomic_document_mapper.dart';
import '../mappers/party_cycle_write_plan.dart';

/// 기존 cycle 인터페이스를 원자 lifecycle 명령과 잔여 recurrence·purge에 연결한다.
class PartyAtomicCycleCommandAdapter implements PartyCycleCommandRepository {
  const PartyAtomicCycleCommandAdapter({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    required PartyAtomicCommandRepository atomicCommandRepository,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth,
       _atomic = atomicCommandRepository;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final PartyAtomicCommandRepository _atomic;

  @override
  Future<PartyCycleResult> complete(PartyCompleteCycleCommand command) =>
      _executeLifecycle(
        recruitmentId: command.recruitmentId,
        expectedRevision: command.expectedRecruitmentRevision,
        expectedCycleKey: command.cycleKey,
        type: PartyAtomicCommandType.complete,
      );

  @override
  Future<PartyCycleResult> advance(PartyAdvanceCycleCommand command) =>
      _executeLifecycle(
        recruitmentId: command.recruitmentId,
        expectedRevision: command.expectedRecruitmentRevision,
        expectedCycleKey: command.expectedCycleKey,
        nextCycleKey: command.nextCycleKey,
        type: PartyAtomicCommandType.advanceCycle,
      );

  @override
  Future<PartyCycleResult> disband(PartyDisbandCommand command) =>
      _executeLifecycle(
        recruitmentId: command.recruitmentId,
        expectedRevision: command.expectedRecruitmentRevision,
        type: PartyAtomicCommandType.disband,
      );

  @override
  Future<PartyCycleResult> setRecurrence(
    PartySetRecurrenceCommand command,
  ) async {
    final invalid = const PartyCycleCommandValidator().validateRecurrence(
      command,
    );
    if (invalid != null) return PartyCycleResult.failure(invalid);
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null || authUid.isEmpty) {
      return const PartyCycleResult.failure(PartyCycleFailure.unauthenticated);
    }
    try {
      return await _firestore.runTransaction((transaction) async {
        final binding = await transaction.get(
          _firestore.collection('authBindings').doc(authUid),
        );
        final playerId = binding.data()?['playerId'];
        if (binding.data()?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty) {
          return const PartyCycleResult.failure(
            PartyCycleFailure.playerBindingMissing,
          );
        }
        final ref = _firestore
            .collection('recruitments')
            .doc(command.recruitmentId);
        final recruitment = await transaction.get(ref);
        final data = recruitment.data();
        if (data == null) {
          return const PartyCycleResult.failure(PartyCycleFailure.notFound);
        }
        if (data['revision'] != command.expectedRecruitmentRevision) {
          return const PartyCycleResult.failure(
            PartyCycleFailure.revisionConflict,
          );
        }
        if (data['leaderPlayerId'] != playerId) {
          return const PartyCycleResult.failure(PartyCycleFailure.unauthorized);
        }
        if (data['status'] != 'active') {
          return const PartyCycleResult.failure(
            PartyCycleFailure.recruitmentClosed,
          );
        }
        final cycleStatus = data['currentCycleStatus'];
        if (cycleStatus != 'active' && cycleStatus != 'completed') {
          return const PartyCycleResult.failure(
            PartyCycleFailure.recruitmentClosed,
          );
        }
        transaction.update(
          ref,
          PartyCycleWritePlan.recurrence(
            continueTogether: command.continueTogether,
            revision: command.expectedRecruitmentRevision,
            serverTimestamp: FieldValue.serverTimestamp(),
          ),
        );
        return const PartyCycleResult.success();
      });
    } on FirebaseException catch (error) {
      return PartyCycleResult.failure(_firebaseFailure(error.code));
    } catch (_) {
      return const PartyCycleResult.failure(PartyCycleFailure.unknown);
    }
  }

  @override
  Future<PartyCycleResult> purgeStaleOwnAssignment(
    PartyPurgeStaleAssignmentCommand command,
  ) async {
    if (command.recruitmentId.trim().isEmpty ||
        command.characterId.trim().isEmpty ||
        command.raidId.trim().isEmpty) {
      return const PartyCycleResult.failure(PartyCycleFailure.invalidRequest);
    }
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null || authUid.isEmpty) {
      return const PartyCycleResult.failure(PartyCycleFailure.unauthenticated);
    }
    final binding = await _firestore
        .collection('authBindings')
        .doc(authUid)
        .get();
    final playerId = binding.data()?['playerId'];
    if (binding.data()?['status'] != 'active' ||
        playerId is! String ||
        playerId.isEmpty) {
      return const PartyCycleResult.failure(
        PartyCycleFailure.playerBindingMissing,
      );
    }
    final recruitmentSnap = await _firestore
        .collection('recruitments')
        .doc(command.recruitmentId)
        .get();
    if (!recruitmentSnap.exists) {
      return const PartyCycleResult.failure(PartyCycleFailure.notFound);
    }
    final recruitment = recruitmentSnap.data()!;
    final status = recruitment['status'];
    final cycleStatus = recruitment['currentCycleStatus'];
    final raidId = recruitment['raidId'];
    final isStale =
        status == 'completed' ||
        status == 'disbanded' ||
        cycleStatus == 'completed';
    if (!isStale || raidId != command.raidId) {
      return const PartyCycleResult.success();
    }
    final stateId = PartyRaidState.documentIdFor(
      characterId: command.characterId,
      raidId: command.raidId,
    );
    final stateRef = _firestore
        .collection('players')
        .doc(playerId)
        .collection('raidStates')
        .doc(stateId);
    final stateSnap = await stateRef.get();
    if (!stateSnap.exists) {
      return const PartyCycleResult.success();
    }
    final state = stateSnap.data();
    if (state?['recruitmentId'] != command.recruitmentId ||
        state?['raidId'] != command.raidId ||
        state?['status'] != 'active') {
      return const PartyCycleResult.success();
    }
    try {
      await stateRef.delete();
      return const PartyCycleResult.success();
    } on FirebaseException catch (error) {
      return PartyCycleResult.failure(_firebaseFailure(error.code));
    }
  }

  Future<PartyCycleResult> _executeLifecycle({
    required String recruitmentId,
    required int expectedRevision,
    required PartyAtomicCommandType type,
    String? expectedCycleKey,
    String? nextCycleKey,
  }) async {
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null || authUid.isEmpty) {
      return const PartyCycleResult.failure(PartyCycleFailure.unauthenticated);
    }
    try {
      final binding = await _firestore
          .collection('authBindings')
          .doc(authUid)
          .get();
      final playerId = binding.data()?['playerId'];
      if (binding.data()?['status'] != 'active' ||
          playerId is! String ||
          playerId.isEmpty) {
        return const PartyCycleResult.failure(
          PartyCycleFailure.playerBindingMissing,
        );
      }
      final recruitment = await _firestore
          .collection('recruitments')
          .doc(recruitmentId)
          .get();
      final raw = recruitment.data();
      if (raw == null) {
        return const PartyCycleResult.failure(PartyCycleFailure.notFound);
      }
      final aggregate = PartyAtomicDocumentMapper.aggregate(
        Map<String, Object?>.from(raw),
      );
      final raidId = raw['raidId'];
      if (raidId is! String || raidId.isEmpty) {
        return const PartyCycleResult.failure(PartyCycleFailure.invalidRequest);
      }
      final cycleKey = expectedCycleKey ?? aggregate.currentCycleKey;
      final nextCycle = type == PartyAtomicCommandType.advanceCycle
          ? const PartyCyclePolicy().fromKey(nextCycleKey ?? '')
          : null;
      if (type == PartyAtomicCommandType.advanceCycle && nextCycle == null) {
        return const PartyCycleResult.failure(PartyCycleFailure.invalidRequest);
      }
      final completedDisband =
          type == PartyAtomicCommandType.disband &&
          aggregate.currentCycleStatus == PartyRaidStateStatus.completed;
      final targets = completedDisband
          ? const <PartyCommandTarget>[]
          : [
              for (final slot in aggregate.partySlots)
                PartyCommandTarget(
                  playerId: slot.playerId,
                  raidStateId: PartyRaidState.documentIdFor(
                    characterId: slot.characterId,
                    raidId: raidId,
                  ),
                ),
            ];
      final result = await _atomic.execute(
        PartyCommandEnvelope(
          commandId: '${type.name}_${recruitmentId}_$expectedRevision',
          recruitmentId: recruitmentId,
          type: type,
          actorPlayerId: playerId,
          expectedRevision: expectedRevision,
          expectedCycleKey: cycleKey,
          nextCycleKey: nextCycleKey,
          nextCycleStartedAt: nextCycle?.startedAt,
          nextCycleEndsAt: nextCycle?.endsAt,
          targets: targets,
        ),
      );
      if (result.isApplied) {
        return const PartyCycleResult.success();
      }
      return PartyCycleResult.failure(_mapAtomicFailure(result.failure!));
    } on FormatException {
      return const PartyCycleResult.failure(PartyCycleFailure.invalidRequest);
    } on ArgumentError {
      return const PartyCycleResult.failure(PartyCycleFailure.invalidRequest);
    } on StateError {
      return const PartyCycleResult.failure(PartyCycleFailure.invalidRequest);
    } on FirebaseException catch (error) {
      return PartyCycleResult.failure(_firebaseFailure(error.code));
    } catch (_) {
      return const PartyCycleResult.failure(PartyCycleFailure.unknown);
    }
  }

  PartyCycleFailure _mapAtomicFailure(
    PartyAtomicCommandFailure failure,
  ) => switch (failure) {
    PartyAtomicCommandFailure.unauthenticated =>
      PartyCycleFailure.unauthenticated,
    PartyAtomicCommandFailure.playerBindingMissing =>
      PartyCycleFailure.playerBindingMissing,
    PartyAtomicCommandFailure.unauthorized => PartyCycleFailure.unauthorized,
    PartyAtomicCommandFailure.notFound => PartyCycleFailure.notFound,
    PartyAtomicCommandFailure.recruitmentClosed =>
      PartyCycleFailure.recruitmentClosed,
    PartyAtomicCommandFailure.cycleMismatch => PartyCycleFailure.cycleMismatch,
    PartyAtomicCommandFailure.revisionConflict =>
      PartyCycleFailure.revisionConflict,
    PartyAtomicCommandFailure.raidStateConflict =>
      PartyCycleFailure.revisionConflict,
    PartyAtomicCommandFailure.permissionDenied =>
      PartyCycleFailure.permissionDenied,
    PartyAtomicCommandFailure.temporarilyUnavailable =>
      PartyCycleFailure.temporarilyUnavailable,
    PartyAtomicCommandFailure.invalidRequest =>
      PartyCycleFailure.invalidRequest,
    PartyAtomicCommandFailure.unknown => PartyCycleFailure.unknown,
  };

  PartyCycleFailure _firebaseFailure(String code) => switch (code) {
    'permission-denied' => PartyCycleFailure.permissionDenied,
    'unavailable' ||
    'deadline-exceeded' ||
    'aborted' => PartyCycleFailure.temporarilyUnavailable,
    _ => PartyCycleFailure.unknown,
  };
}
