import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/party_application_command.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/policies/minimum_combat_power_policy.dart';
import '../../domain/repositories/party_application_command_repository.dart';
import '../../domain/services/party_application_command_validator.dart';
import '../../domain/services/party_create_occupancy_gate.dart';
import '../mappers/party_application_write_plan.dart';
import '../mappers/party_atomic_application_write_plan.dart';
import '../mappers/party_atomic_document_mapper.dart';
import 'party_raid_state_occupancy_inspector.dart';

/// 새 Aggregate 구조용 신청·재신청·철회 Repository.
///
/// 운영 모집 상세의 신청·재신청·철회 명령에 연결된다.
class FirestorePartyAtomicApplicationCommandRepository
    implements PartyApplicationCommandRepository {
  const FirestorePartyAtomicApplicationCommandRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    this.clock = DateTime.now,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final DateTime Function() clock;
  static const _minimumCombatPowerPolicy = MinimumCombatPowerPolicy();

  @override
  Future<PartyApplicationCommandResult> apply(PartyApplyCommand command) async {
    final invalid = const PartyApplicationCommandValidator().validateApply(
      command,
    );
    if (invalid != null) return PartyApplicationCommandResult.failure(invalid);
    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await _applyOnce(command);
      if (!result.didRollOverHistoricalState) return result;
    }
    return const PartyApplicationCommandResult.failure(
      PartyApplicationFailure.temporarilyUnavailable,
    );
  }

  Future<PartyApplicationCommandResult> _applyOnce(
    PartyApplyCommand command,
  ) => _run((transaction, playerId) async {
      final recruitmentRef = _firestore
          .collection('recruitments')
          .doc(command.recruitmentId);
      final characterRef = _firestore
          .collection('characters')
          .doc(command.characterId);
      final applicationRef = recruitmentRef
          .collection('applications')
          .doc(playerId);
      final recruitment = await transaction.get(recruitmentRef);
      final character = await transaction.get(characterRef);
      final application = await transaction.get(applicationRef);
      final raw = recruitment.data();
      final characterData = character.data();
      if (raw == null) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.notFound,
        );
      }
      if (raw['status'] != 'active' ||
          raw['manualRecruitmentEnabled'] != true) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.recruitmentClosed,
        );
      }
      if ((raw['approvalPolicy'] as Map?)?['mode'] != 'leaderOnly') {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.approvalModeMismatch,
        );
      }
      final aggregate = PartyAtomicDocumentMapper.aggregate(
        Map<String, Object?>.from(raw),
      );
      if (aggregate.memberCount >= _rules(raw).totalMembers) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.capacityFull,
        );
      }
      if (aggregate.partySlots.any((slot) => slot.playerId == playerId)) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.alreadyMember,
        );
      }
      if (command.cycleKey != raw['targetCycleKey']) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.invalidRequest,
        );
      }
      final raidId = raw['raidId'];
      if (raidId is! String || raidId.isEmpty) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.invalidRequest,
        );
      }
      final occupancy = await PartyRaidStateOccupancyInspector.inspect(
        transaction: transaction,
        firestore: _firestore,
        playerId: playerId,
        characterId: command.characterId,
        raidId: raidId,
        requestedCycleKey: command.cycleKey,
        now: clock(),
      );
      switch (occupancy.decision) {
        case ExistingRaidStateOccupancyDecision.currentCompleted:
          return const PartyApplicationCommandResult.failure(
            PartyApplicationFailure.weeklyRaidCompleted,
          );
        case ExistingRaidStateOccupancyDecision.currentActive:
        case ExistingRaidStateOccupancyDecision.participationConflict:
          return const PartyApplicationCommandResult.failure(
            PartyApplicationFailure.participationConflict,
          );
        case ExistingRaidStateOccupancyDecision.currentOrphanActive:
        case ExistingRaidStateOccupancyDecision.historicalOrphanActive:
          return PartyApplicationCommandResult.orphaned(
            occupancy.orphanedParticipation!,
          );
        case ExistingRaidStateOccupancyDecision.historicalCompleted:
          transaction.delete(occupancy.stateRef);
          return const PartyApplicationCommandResult.historicalStateRolledOver();
        case ExistingRaidStateOccupancyDecision.inconsistent:
          return const PartyApplicationCommandResult.failure(
            PartyApplicationFailure.stateInconsistent,
          );
        case null:
          break;
      }
      if (!character.exists || characterData?['status'] != 'active') {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.invalidCharacter,
        );
      }
      if (characterData?['ownerPlayerId'] != playerId) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.ownershipLost,
        );
      }
      final itemLevel = _parseItemLevel(characterData?['itemAvgLevel']);
      final name = characterData?['characterName'];
      final className = characterData?['characterClassName'];
      if (itemLevel == null ||
          itemLevel < (raw['minItemLevel'] as num? ?? double.infinity) ||
          name is! String ||
          className is! String) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.invalidCharacter,
        );
      }
      if (!_minimumCombatPowerPolicy
          .evaluate(
            minimum: raw['minCombatPower'] as num?,
            actual: command.combatPower,
          )
          .isAllowed) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.minimumCombatPowerNotMet,
        );
      }

      var applicantIsGroupMember = true;
      final groupId = aggregate.groupId;
      if (groupId != null) {
        final groupMember = await transaction.get(
          _firestore
              .collection('groups')
              .doc(groupId)
              .collection('members')
              .doc(playerId),
        );
        applicantIsGroupMember = groupMember.exists;
      }

      final now = FieldValue.serverTimestamp();
      final existing = application.data();
      if (!application.exists) {
        final plan = PartyAtomicApplicationWritePlan.apply(
          application: PartyApplicationWritePlan.create(
            command: command,
            playerId: playerId,
            characterName: name,
            className: className,
            itemLevel: itemLevel,
            serverTimestamp: now,
          ),
          aggregate: aggregate,
          applicantPlayerId: playerId,
          applicantIsGroupMember: applicantIsGroupMember,
          serverTimestamp: now,
        );
        transaction.set(applicationRef, plan.application);
        transaction.update(recruitmentRef, plan.recruitmentPatch);
        transaction.set(
          _firestore
              .collection('partyEvents')
              .doc(plan.event['eventId']! as String),
          plan.event,
        );
        return const PartyApplicationCommandResult.success();
      }

      final status = existing?['status'];
      if (status == 'pending') {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.applicationAlreadyExists,
        );
      }
      if (status != 'rejected' &&
          status != 'withdrawn' &&
          status != 'superseded' &&
          status != 'approved') {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.invalidRequest,
        );
      }
      final revision = existing?['revision'];
      if (revision is! int) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.invalidRequest,
        );
      }
      final plan = PartyAtomicApplicationWritePlan.apply(
        application: PartyApplicationWritePlan.reapply(
          command: command,
          characterName: name,
          className: className,
          itemLevel: itemLevel,
          nextRevision: revision + 1,
          serverTimestamp: now,
        ),
        aggregate: aggregate,
        applicantPlayerId: playerId,
        applicantIsGroupMember: applicantIsGroupMember,
        serverTimestamp: now,
      );
      transaction.update(applicationRef, plan.application);
      transaction.update(recruitmentRef, plan.recruitmentPatch);
      transaction.set(
        _firestore
            .collection('partyEvents')
            .doc(plan.event['eventId']! as String),
        plan.event,
      );
      return const PartyApplicationCommandResult.success();
    });

  @override
  Future<PartyApplicationCommandResult> withdraw(
    PartyWithdrawApplicationCommand command,
  ) async {
    final invalid = const PartyApplicationCommandValidator().validateWithdraw(
      command,
    );
    if (invalid != null) return PartyApplicationCommandResult.failure(invalid);
    return _run((transaction, playerId) async {
      final recruitmentRef = _firestore
          .collection('recruitments')
          .doc(command.recruitmentId);
      final applicationRef = recruitmentRef
          .collection('applications')
          .doc(playerId);
      final recruitment = await transaction.get(recruitmentRef);
      final application = await transaction.get(applicationRef);
      final raw = recruitment.data();
      final data = application.data();
      if (raw == null || data == null) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.notFound,
        );
      }
      if (data['status'] != 'pending') {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.applicationNotPending,
        );
      }
      if (data['revision'] != command.expectedRevision) {
        return const PartyApplicationCommandResult.failure(
          PartyApplicationFailure.revisionConflict,
        );
      }
      final aggregate = PartyAtomicDocumentMapper.aggregate(
        Map<String, Object?>.from(raw),
      );
      final now = FieldValue.serverTimestamp();
      final plan = PartyAtomicApplicationWritePlan.withdraw(
        application: Map<String, Object?>.from(data),
        aggregate: aggregate,
        applicantPlayerId: playerId,
        serverTimestamp: now,
      );
      transaction.update(
        applicationRef,
        PartyApplicationWritePlan.withdraw(
          nextRevision: command.expectedRevision + 1,
          serverTimestamp: now,
        ),
      );
      transaction.update(recruitmentRef, plan.recruitmentPatch);
      transaction.set(
        _firestore
            .collection('partyEvents')
            .doc(plan.event['eventId']! as String),
        plan.event,
      );
      return const PartyApplicationCommandResult.success();
    });
  }

  Future<PartyApplicationCommandResult> _run(
    Future<PartyApplicationCommandResult> Function(Transaction, String) action,
  ) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      return const PartyApplicationCommandResult.failure(
        PartyApplicationFailure.unauthenticated,
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
          return const PartyApplicationCommandResult.failure(
            PartyApplicationFailure.playerBindingMissing,
          );
        }
        return action(transaction, playerId);
      });
    } on FirebaseException catch (error) {
      assert(() {
        // ignore: avoid_print
        print(
          'PartyAtomicApplication FirebaseException: ${error.code} ${error.message}',
        );
        return true;
      }());
      return PartyApplicationCommandResult.failure(switch (error.code) {
        'permission-denied' => PartyApplicationFailure.permissionDenied,
        'unavailable' ||
        'deadline-exceeded' ||
        'aborted' => PartyApplicationFailure.temporarilyUnavailable,
        _ => PartyApplicationFailure.unknown,
      });
    } on FormatException {
      return const PartyApplicationCommandResult.failure(
        PartyApplicationFailure.invalidRequest,
      );
    } on StateError {
      return const PartyApplicationCommandResult.failure(
        PartyApplicationFailure.invalidRequest,
      );
    } catch (error, stackTrace) {
      assert(() {
        // ignore: avoid_print
        print(
          'PartyAtomicApplication unexpected ${error.runtimeType}: $error\n$stackTrace',
        );
        return true;
      }());
      return const PartyApplicationCommandResult.failure(
        PartyApplicationFailure.unknown,
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

  double? _parseItemLevel(Object? value) => value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value.replaceAll(',', '').trim())
      : null;
}
