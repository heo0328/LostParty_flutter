import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/party_cycle_command.dart';
import '../../domain/repositories/party_cycle_command_repository.dart';
import '../../domain/services/lazy_cycle_reconciler.dart';

class FirestoreLazyCycleReconciliationGateway
    implements LazyCycleReconciliationGateway {
  const FirestoreLazyCycleReconciliationGateway({
    required FirebaseFirestore firestore,
    required PartyCycleCommandRepository cycleRepository,
  }) : _firestore = firestore,
       _cycleRepository = cycleRepository;

  final FirebaseFirestore _firestore;
  final PartyCycleCommandRepository _cycleRepository;

  @override
  Future<LazyCycleReconciliationResult> reconcile({
    required String recruitmentId,
    required String targetCycleKey,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('recruitments')
          .doc(recruitmentId)
          .get();
      final data = snapshot.data();
      if (data == null || data['status'] != 'active') {
        return const LazyCycleReconciliationResult.noChange();
      }
      final currentCycleKey = data['currentCycleKey'];
      final revision = data['revision'];
      if (currentCycleKey == targetCycleKey) {
        return const LazyCycleReconciliationResult.noChange();
      }
      if (currentCycleKey is! String ||
          currentCycleKey.isEmpty ||
          revision is! num) {
        return const LazyCycleReconciliationResult.failed(
          LazyCycleReconciliationFailure.invalidData,
        );
      }

      final result = await _cycleRepository.advance(
        PartyAdvanceCycleCommand(
          recruitmentId: recruitmentId,
          expectedCycleKey: currentCycleKey,
          nextCycleKey: targetCycleKey,
          expectedRecruitmentRevision: revision.toInt(),
        ),
      );
      if (result.isSuccess) {
        return const LazyCycleReconciliationResult.changed();
      }
      if (result.failure == PartyCycleFailure.cycleMismatch ||
          result.failure == PartyCycleFailure.revisionConflict ||
          result.failure == PartyCycleFailure.recruitmentClosed) {
        return _resolveConcurrentOutcome(
          recruitmentId: recruitmentId,
          targetCycleKey: targetCycleKey,
        );
      }
      return LazyCycleReconciliationResult.failed(
        switch (result.failure!) {
          PartyCycleFailure.permissionDenied ||
          PartyCycleFailure.unauthenticated ||
          PartyCycleFailure.playerBindingMissing ||
          PartyCycleFailure.unauthorized =>
            LazyCycleReconciliationFailure.permissionDenied,
          PartyCycleFailure.temporarilyUnavailable =>
            LazyCycleReconciliationFailure.temporarilyUnavailable,
          PartyCycleFailure.invalidRequest || PartyCycleFailure.notFound =>
            LazyCycleReconciliationFailure.invalidData,
          _ => LazyCycleReconciliationFailure.unknown,
        },
      );
    } on FirebaseException catch (error) {
      return LazyCycleReconciliationResult.failed(switch (error.code) {
        'permission-denied' => LazyCycleReconciliationFailure.permissionDenied,
        'unavailable' || 'deadline-exceeded' || 'aborted' =>
          LazyCycleReconciliationFailure.temporarilyUnavailable,
        _ => LazyCycleReconciliationFailure.unknown,
      });
    } catch (_) {
      return const LazyCycleReconciliationResult.failed(
        LazyCycleReconciliationFailure.unknown,
      );
    }
  }

  Future<LazyCycleReconciliationResult> _resolveConcurrentOutcome({
    required String recruitmentId,
    required String targetCycleKey,
  }) async {
    final latest = await _firestore
        .collection('recruitments')
        .doc(recruitmentId)
        .get();
    final data = latest.data();
    if (data == null || data['status'] != 'active') {
      return const LazyCycleReconciliationResult.noChange();
    }
    if (data['currentCycleKey'] == targetCycleKey) {
      return const LazyCycleReconciliationResult.noChange();
    }
    return const LazyCycleReconciliationResult.failed(
      LazyCycleReconciliationFailure.temporarilyUnavailable,
    );
  }
}
