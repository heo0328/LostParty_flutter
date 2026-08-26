import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/party_cycle_command.dart';
import '../../domain/entities/party_event.dart';
import '../../domain/policies/party_cycle_policy.dart';
import '../../domain/repositories/party_cycle_command_repository.dart';
import '../../domain/services/party_cycle_command_validator.dart';
import '../mappers/party_cycle_write_plan.dart';
import '../mappers/party_event_write_plan.dart';
import '../mappers/party_lifecycle_event_writer.dart';

class FirestorePartyCycleCommandRepository implements PartyCycleCommandRepository {
  const FirestorePartyCycleCommandRepository({required FirebaseFirestore firestore, required FirebaseAuth firebaseAuth, DateTime Function()? now}) : _firestore = firestore, _firebaseAuth = firebaseAuth, _now = now;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final DateTime Function()? _now;

  @override
  Future<PartyCycleResult> complete(PartyCompleteCycleCommand command) async {
    final invalid = const PartyCycleCommandValidator().validateComplete(command);
    if (invalid != null) return PartyCycleResult.failure(invalid);
    final members = await _loadMembers(command.recruitmentId);
    if (members == null) return const PartyCycleResult.failure(PartyCycleFailure.temporarilyUnavailable);
    return _run((transaction, playerId) async {
      final recruitmentRef = _recruitment(command.recruitmentId);
      final cycleRef = recruitmentRef.collection('cycles').doc(command.cycleKey);
      final recruitment = await transaction.get(recruitmentRef);
      final cycle = await transaction.get(cycleRef);
      final r = recruitment.data();
      final failure = _validateCurrent(r, command.cycleKey, command.expectedRecruitmentRevision);
      if (failure != null) return PartyCycleResult.failure(failure);
      if (!(r?['memberPlayerIds'] as List).contains(playerId)) return const PartyCycleResult.failure(PartyCycleFailure.unauthorized);
      if (r?['currentCycleStatus'] != 'active' || (cycle.exists && cycle.data()?['status'] != 'completionCancelled')) return const PartyCycleResult.failure(PartyCycleFailure.alreadyCompleted);
      final snapshot = await _memberSnapshot(transaction, members);
      if (snapshot == null || snapshot.length != r?['memberCount']) return const PartyCycleResult.failure(PartyCycleFailure.revisionConflict);
      final now = FieldValue.serverTimestamp();
      if (cycle.exists) {
        transaction.update(cycleRef, PartyCycleWritePlan.recompleteCycle(completedByPlayerId: playerId, completionRevision: cycle.data()?['completionRevision'] as int, memberSnapshot: snapshot, serverTimestamp: now));
      } else {
        transaction.set(cycleRef, PartyCycleWritePlan.completedCycle(recruitmentId: command.recruitmentId, cycleKey: command.cycleKey, completedByPlayerId: playerId, memberSnapshot: snapshot, serverTimestamp: now));
      }
      _writeEvents(transaction, command.recruitmentId, snapshot, r!, type: 'partyCompleted', eventRevision: cycle.exists ? (cycle.data()?['completionRevision'] as int) + 1 : 1, serverTimestamp: now);
      transaction.update(recruitmentRef, PartyCycleWritePlan.completeRecruitment(continueTogether: r['continueTogether'] == true, completedByPlayerId: playerId, revision: command.expectedRecruitmentRevision, serverTimestamp: now));
      return const PartyCycleResult.success();
    });
  }

  @override
  Future<PartyCycleResult> cancelCompletion(PartyCancelCompletionCommand command) async {
    final invalid = const PartyCycleCommandValidator().validateCancel(command);
    if (invalid != null) return PartyCycleResult.failure(invalid);
    return _run((transaction, playerId) async {
      final recruitmentRef = _recruitment(command.recruitmentId);
      final cycleRef = recruitmentRef.collection('cycles').doc(command.cycleKey);
      final recruitment = await transaction.get(recruitmentRef);
      final cycle = await transaction.get(cycleRef);
      final r = recruitment.data();
      final c = cycle.data();
      final failure = _validateCurrent(r, command.cycleKey, command.expectedRecruitmentRevision);
      if (failure != null) return PartyCycleResult.failure(failure);
      if (r?['leaderPlayerId'] != playerId) return const PartyCycleResult.failure(PartyCycleFailure.unauthorized);
      if (r?['continueTogether'] != true || r?['currentCycleStatus'] != 'completed' || c?['status'] != 'completed') return const PartyCycleResult.failure(PartyCycleFailure.notCompleted);
      if (c?['completionRevision'] != command.expectedCompletionRevision) return const PartyCycleResult.failure(PartyCycleFailure.revisionConflict);
      final window = const PartyCyclePolicy().fromKey(command.cycleKey)!;
      if (!(_now ?? DateTime.now)().toUtc().isBefore(window.completionCancelDeadline)) return const PartyCycleResult.failure(PartyCycleFailure.completionCancelExpired);
      final now = FieldValue.serverTimestamp();
      transaction.update(cycleRef, PartyCycleWritePlan.cancelCycle(completionRevision: command.expectedCompletionRevision, serverTimestamp: now));
      _writeEvents(transaction, command.recruitmentId, List<Map<String, Object?>>.from((c?['completedMemberSnapshot'] as List).map((item) => Map<String, Object?>.from(item as Map))), r!, type: 'partyCompletionCancelled', eventRevision: command.expectedCompletionRevision + 1, serverTimestamp: now);
      transaction.update(recruitmentRef, PartyCycleWritePlan.cancelRecruitment(revision: command.expectedRecruitmentRevision, hasAvailableSlot: (r['memberCount'] as int) < (r['maxMemberCount'] as int), serverTimestamp: now));
      return const PartyCycleResult.success();
    });
  }

  @override
  Future<PartyCycleResult> setRecurrence(PartySetRecurrenceCommand command) async {
    final invalid = const PartyCycleCommandValidator().validateRecurrence(command);
    if (invalid != null) return PartyCycleResult.failure(invalid);
    return _run((transaction, playerId) async {
      final ref = _recruitment(command.recruitmentId);
      final recruitment = await transaction.get(ref);
      final r = recruitment.data();
      if (r == null) return const PartyCycleResult.failure(PartyCycleFailure.notFound);
      if (r['revision'] != command.expectedRecruitmentRevision) return const PartyCycleResult.failure(PartyCycleFailure.revisionConflict);
      if (r['leaderPlayerId'] != playerId) return const PartyCycleResult.failure(PartyCycleFailure.unauthorized);
      if (r['status'] != 'active') {
        return const PartyCycleResult.failure(PartyCycleFailure.recruitmentClosed);
      }
      final cycleStatus = r['currentCycleStatus'];
      if (cycleStatus != 'active' && cycleStatus != 'completed') {
        return const PartyCycleResult.failure(PartyCycleFailure.recruitmentClosed);
      }
      transaction.update(ref, PartyCycleWritePlan.recurrence(continueTogether: command.continueTogether, revision: command.expectedRecruitmentRevision, serverTimestamp: FieldValue.serverTimestamp()));
      return const PartyCycleResult.success();
    });
  }

  @override
  Future<PartyCycleResult> advance(PartyAdvanceCycleCommand command) async {
    final invalid = const PartyCycleCommandValidator().validateAdvance(command);
    if (invalid != null) return PartyCycleResult.failure(invalid);
    final members = await _loadMembers(command.recruitmentId);
    if (members == null) return const PartyCycleResult.failure(PartyCycleFailure.temporarilyUnavailable);
    return _run((transaction, playerId) async {
      final recruitmentRef = _recruitment(command.recruitmentId);
      final cycleRef = recruitmentRef.collection('cycles').doc(command.expectedCycleKey);
      final recruitment = await transaction.get(recruitmentRef);
      final cycle = await transaction.get(cycleRef);
      final r = recruitment.data();
      final failure = _validateCurrent(r, command.expectedCycleKey, command.expectedRecruitmentRevision);
      if (failure != null) return PartyCycleResult.failure(failure);
      if (!(r?['memberPlayerIds'] as List).contains(playerId)) return const PartyCycleResult.failure(PartyCycleFailure.unauthorized);
      final currentWindow = const PartyCyclePolicy().fromKey(command.expectedCycleKey)!;
      final nextWindow = const PartyCyclePolicy().fromKey(command.nextCycleKey)!;
      if (nextWindow.startedAt != currentWindow.endsAt || (_now ?? DateTime.now)().toUtc().isBefore(currentWindow.endsAt)) return const PartyCycleResult.failure(PartyCycleFailure.notReadyForAdvance);
      final snapshot = await _memberSnapshot(transaction, members);
      if (snapshot == null || snapshot.length != r?['memberCount']) return const PartyCycleResult.failure(PartyCycleFailure.revisionConflict);
      final now = FieldValue.serverTimestamp();
      if (!cycle.exists) {
        transaction.set(cycleRef, PartyCycleWritePlan.incompleteCycle(recruitmentId: command.recruitmentId, cycleKey: command.expectedCycleKey, memberSnapshot: snapshot, serverTimestamp: now));
        _writeEvents(transaction, command.recruitmentId, snapshot, r!, type: 'partyIncompleteEnded', eventRevision: 1, serverTimestamp: now);
      } else if (cycle.data()?['status'] == 'completionCancelled') {
        transaction.update(cycleRef, PartyCycleWritePlan.endCancelledCycle(completionRevision: cycle.data()?['completionRevision'] as int, memberSnapshot: snapshot, serverTimestamp: now));
        _writeEvents(transaction, command.recruitmentId, snapshot, r!, type: 'partyIncompleteEnded', eventRevision: (cycle.data()?['completionRevision'] as int) + 1, serverTimestamp: now);
      }
      transaction.update(recruitmentRef, PartyCycleWritePlan.advanceRecruitment(continueTogether: r?['continueTogether'] == true, nextCycleKey: command.nextCycleKey, nextStartedAt: nextWindow.startedAt, nextEndsAt: nextWindow.endsAt, revision: command.expectedRecruitmentRevision, hasAvailableSlot: (r?['memberCount'] as int) < (r?['maxMemberCount'] as int), serverTimestamp: now, timestamp: (date) => Timestamp.fromDate(date)));
      return const PartyCycleResult.success();
    });
  }

  @override
  Future<PartyCycleResult> disband(PartyDisbandCommand command) async {
    final invalid = const PartyCycleCommandValidator().validateDisband(command);
    if (invalid != null) return PartyCycleResult.failure(invalid);
    final members = await _loadMembers(command.recruitmentId);
    if (members == null) {
      return const PartyCycleResult.failure(
        PartyCycleFailure.temporarilyUnavailable,
      );
    }
    final applications = await _loadApplications(command.recruitmentId);
    if (applications == null) {
      return const PartyCycleResult.failure(
        PartyCycleFailure.temporarilyUnavailable,
      );
    }
    return _run((transaction, playerId) async {
      final recruitmentRef = _recruitment(command.recruitmentId);
      final recruitment = await transaction.get(recruitmentRef);
      final r = recruitment.data();
      if (r == null) {
        return const PartyCycleResult.failure(PartyCycleFailure.notFound);
      }
      if (r['revision'] != command.expectedRecruitmentRevision) {
        return const PartyCycleResult.failure(PartyCycleFailure.revisionConflict);
      }
      if (r['leaderPlayerId'] != playerId) {
        return const PartyCycleResult.failure(PartyCycleFailure.unauthorized);
      }
      final status = r['status'];
      if (status != 'active' && status != 'completed') {
        return const PartyCycleResult.failure(PartyCycleFailure.recruitmentClosed);
      }
      final raidId = r['raidId'] as String;
      final cycleKey = r['currentCycleKey'];
      if (cycleKey is! String || cycleKey.isEmpty) {
        return const PartyCycleResult.failure(PartyCycleFailure.invalidRequest);
      }
      final now = FieldValue.serverTimestamp();
      final nextRevision = command.expectedRecruitmentRevision + 1;
      final beforeMemberIds = <String>[];
      final characterNames = <String, String?>{};
      for (final member in members.docs) {
        final current = await transaction.get(member.reference);
        if (!current.exists) continue;
        beforeMemberIds.add(member.id);
        final data = current.data()!;
        characterNames[member.id] = data['characterNameSnapshot'] is String
            ? data['characterNameSnapshot'] as String
            : null;
        final characterId = data['characterId'] as String?;
        transaction.delete(member.reference);
        if (characterId != null && characterId.isNotEmpty) {
          transaction.delete(
            _firestore
                .collection('players')
                .doc(member.id)
                .collection('activeRaidAssignments')
                .doc('${characterId}_$raidId'),
          );
        }
      }
      final pendingApplicantIds = <String>[];
      for (final application in applications.docs) {
        final current = await transaction.get(application.reference);
        if (!current.exists) continue;
        final data = current.data();
        if (data?['status'] != 'pending') continue;
        final applicantId = data?['applicantPlayerId'];
        if (applicantId is! String || applicantId.isEmpty) continue;
        pendingApplicantIds.add(applicantId);
        characterNames[applicantId] = data?['characterNameSnapshot'] is String
            ? data!['characterNameSnapshot'] as String
            : characterNames[applicantId];
      }
      transaction.update(
        recruitmentRef,
        PartyCycleWritePlan.disbandRecruitment(
          revision: command.expectedRecruitmentRevision,
          serverTimestamp: now,
        ),
      );
      PartyLifecycleEventWriter.writeToRecipients(
        transaction: transaction,
        firestore: _firestore,
        type: PartyEventType.partyDisbanded,
        recipientPlayerIds: {...beforeMemberIds, ...pendingApplicantIds},
        recruitmentId: command.recruitmentId,
        cycleKey: cycleKey,
        recruitmentRevision: nextRevision,
        actorPlayerId: playerId,
        raidId: raidId,
        difficultyId: r['difficultyId'] is String
            ? r['difficultyId'] as String
            : null,
        characterNameByPlayerId: characterNames,
        endReason: 'disbandedByLeader',
        serverTimestamp: now,
        now: _now,
      );
      return const PartyCycleResult.success();
    });
  }

  Future<List<Map<String, Object?>>?> _memberSnapshot(Transaction transaction, QuerySnapshot<Map<String, dynamic>> known) async {
    final result = <Map<String, Object?>>[];
    for (final member in known.docs) {
      final current = await transaction.get(member.reference);
      if (!current.exists) continue;
      final data = current.data()!;
      result.add({'playerId': member.id, 'characterId': data['characterId'], 'characterNameSnapshot': data['characterNameSnapshot'], 'classNameSnapshot': data['classNameSnapshot'], 'role': data['role'], 'partyIndex': data['partyIndex'], 'itemLevelSnapshot': data['itemLevelSnapshot'], 'combatPowerSnapshot': data['combatPowerSnapshot']});
    }
    return result;
  }

  void _writeEvents(Transaction transaction, String recruitmentId, List<Map<String, Object?>> members, Map<String, dynamic> recruitment, {required String type, required int eventRevision, required Object serverTimestamp}) {
    final expiresAt = Timestamp.fromDate((_now ?? DateTime.now)().toUtc().add(const Duration(days: 28)));
    for (final member in members) {
      final playerId = member['playerId'] as String;
      final eventId = PartyEventWritePlan.id(recruitmentId: recruitmentId, cycleKey: recruitment['currentCycleKey'] as String, eventRevision: eventRevision, type: type);
      final ref = _firestore.collection('players').doc(playerId).collection('events').doc(eventId);
      transaction.set(ref, PartyEventWritePlan.cycle(eventId: eventId, type: type, playerId: playerId, recruitmentId: recruitmentId, cycleKey: recruitment['currentCycleKey'] as String, raidId: recruitment['raidId'] as String, difficultyId: recruitment['difficultyId'] as String, eventRevision: eventRevision, memberSnapshot: member, serverTimestamp: serverTimestamp, expiresAt: expiresAt));
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _loadMembers(String id) async {
    try {
      return await _recruitment(id).collection('members').get();
    } on FirebaseException {
      return null;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _loadApplications(
    String id,
  ) async {
    try {
      return await _recruitment(id).collection('applications').get();
    } on FirebaseException {
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>> _recruitment(String id) =>
      _firestore.collection('recruitments').doc(id);

  Future<PartyCycleResult> _run(Future<PartyCycleResult> Function(Transaction, String) action) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return const PartyCycleResult.failure(PartyCycleFailure.unauthenticated);
    try { return await _firestore.runTransaction((transaction) async { final binding = await transaction.get(_firestore.collection('authBindings').doc(uid)); final data = binding.data(); final playerId = data?['playerId']; if (data?['status'] != 'active' || playerId is! String || playerId.isEmpty) return const PartyCycleResult.failure(PartyCycleFailure.playerBindingMissing); return action(transaction, playerId); }); } on FirebaseException catch (error) { return PartyCycleResult.failure(switch (error.code) { 'permission-denied' => PartyCycleFailure.permissionDenied, 'unavailable' || 'deadline-exceeded' || 'aborted' => PartyCycleFailure.temporarilyUnavailable, _ => PartyCycleFailure.unknown }); } catch (_) { return const PartyCycleResult.failure(PartyCycleFailure.unknown); }
  }
}

PartyCycleFailure? _validateCurrent(Map<String, dynamic>? data, String cycleKey, int revision) {
  if (data == null) return PartyCycleFailure.notFound;
  if (data['revision'] != revision) return PartyCycleFailure.revisionConflict;
  if (data['currentCycleKey'] != cycleKey) return PartyCycleFailure.cycleMismatch;
  if (data['status'] != 'active') return PartyCycleFailure.recruitmentClosed;
  return null;
}
