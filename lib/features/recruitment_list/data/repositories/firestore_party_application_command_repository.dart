import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/party_application_command.dart';
import '../../domain/repositories/party_application_command_repository.dart';
import '../../domain/services/party_application_command_validator.dart';
import '../mappers/party_application_write_plan.dart';

class FirestorePartyApplicationCommandRepository implements PartyApplicationCommandRepository {
  const FirestorePartyApplicationCommandRepository({required FirebaseFirestore firestore, required FirebaseAuth firebaseAuth}) : _firestore = firestore, _firebaseAuth = firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<PartyApplicationCommandResult> apply(PartyApplyCommand command) async {
    const validator = PartyApplicationCommandValidator();
    final invalid = validator.validateApply(command);
    if (invalid != null) return PartyApplicationCommandResult.failure(invalid);
    return _run((transaction, playerId) async {
      final recruitmentRef = _firestore.collection('recruitments').doc(command.recruitmentId);
      final characterRef = _firestore.collection('characters').doc(command.characterId);
      final applicationRef = recruitmentRef.collection('applications').doc(playerId);
      final recruitment = await transaction.get(recruitmentRef);
      final character = await transaction.get(characterRef);
      final application = await transaction.get(applicationRef);
      final r = recruitment.data();
      final c = character.data();
      if (!recruitment.exists) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.notFound);
      if (r?['status'] != 'active' || r?['manualRecruitmentEnabled'] != true) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.recruitmentClosed);
      if ((r?['approvalPolicy'] as Map?)?['mode'] != 'leaderOnly') return const PartyApplicationCommandResult.failure(PartyApplicationFailure.approvalModeMismatch);
      if (r?['hasAvailableSlot'] != true) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.capacityFull);
      if ((r?['memberPlayerIds'] as List?)?.contains(playerId) == true) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.alreadyMember);
      if (application.exists) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.applicationAlreadyExists);
      if (command.cycleKey != r?['targetCycleKey']) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.invalidRequest);
      if (!character.exists || c?['status'] != 'active') return const PartyApplicationCommandResult.failure(PartyApplicationFailure.invalidCharacter);
      if (c?['ownerPlayerId'] != playerId) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.ownershipLost);
      final itemLevel = _parseItemLevel(c?['itemAvgLevel']);
      if (itemLevel == null || itemLevel < (r?['minItemLevel'] as num? ?? double.infinity)) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.invalidCharacter);
      final name = c?['characterName'];
      final className = c?['characterClassName'];
      if (name is! String || className is! String) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.invalidCharacter);
      transaction.set(applicationRef, PartyApplicationWritePlan.create(command: command, playerId: playerId, characterName: name, className: className, itemLevel: itemLevel, serverTimestamp: FieldValue.serverTimestamp()));
      return const PartyApplicationCommandResult.success();
    });
  }

  @override
  Future<PartyApplicationCommandResult> withdraw(PartyWithdrawApplicationCommand command) async {
    const validator = PartyApplicationCommandValidator();
    final invalid = validator.validateWithdraw(command);
    if (invalid != null) return PartyApplicationCommandResult.failure(invalid);
    return _run((transaction, playerId) async {
      final ref = _firestore.collection('recruitments').doc(command.recruitmentId).collection('applications').doc(playerId);
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (!snapshot.exists) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.notFound);
      if (data?['status'] != 'pending') return const PartyApplicationCommandResult.failure(PartyApplicationFailure.applicationNotPending);
      if (data?['revision'] != command.expectedRevision) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.revisionConflict);
      transaction.update(ref, PartyApplicationWritePlan.withdraw(nextRevision: command.expectedRevision + 1, serverTimestamp: FieldValue.serverTimestamp()));
      return const PartyApplicationCommandResult.success();
    });
  }

  Future<PartyApplicationCommandResult> _run(Future<PartyApplicationCommandResult> Function(Transaction, String) action) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.unauthenticated);
    try {
      return await _firestore.runTransaction((transaction) async {
        final binding = await transaction.get(_firestore.collection('authBindings').doc(uid));
        final data = binding.data();
        final playerId = data?['playerId'];
        if (data?['status'] != 'active' || playerId is! String || playerId.isEmpty) return const PartyApplicationCommandResult.failure(PartyApplicationFailure.playerBindingMissing);
        return action(transaction, playerId);
      });
    } on FirebaseException catch (error) {
      assert(() {
        // ignore: avoid_print
        print('PartyApplication apply/withdraw FirebaseException: ${error.code} ${error.message}');
        return true;
      }());
      return PartyApplicationCommandResult.failure(switch (error.code) {
        'permission-denied' => PartyApplicationFailure.permissionDenied,
        'unavailable' || 'deadline-exceeded' || 'aborted' => PartyApplicationFailure.temporarilyUnavailable,
        _ => PartyApplicationFailure.unknown,
      });
    } catch (_) { return const PartyApplicationCommandResult.failure(PartyApplicationFailure.unknown); }
  }
}

double? _parseItemLevel(Object? value) => value is num ? value.toDouble() : value is String ? double.tryParse(value.replaceAll(',', '').trim()) : null;
