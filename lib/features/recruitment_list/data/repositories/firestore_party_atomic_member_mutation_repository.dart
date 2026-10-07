import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_membership_command.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/policies/minimum_combat_power_policy.dart';
import '../../domain/repositories/party_atomic_member_mutation_repository.dart';
import '../../domain/services/party_create_occupancy_gate.dart';
import '../../domain/services/party_membership_command_validator.dart';
import '../../domain/services/party_ownership_record_policy.dart';
import '../mappers/party_atomic_document_mapper.dart';
import '../mappers/party_atomic_member_mutation_write_plan.dart';
import '../mappers/party_membership_write_plan.dart';
import '../mappers/party_raid_listing_sync.dart';
import 'party_raid_state_occupancy_inspector.dart';
import 'party_character_ownership_reader.dart';

/// 새 Aggregate·raidState 구조용 캐릭터 변경·자리 이동 Repository.
///
/// 운영 Router에서 사용하며 전원 membership 재조회와 개인 event fan-out을 쓰지 않는다.
class FirestorePartyAtomicMemberMutationRepository
    implements PartyAtomicMemberMutationRepository {
  const FirestorePartyAtomicMemberMutationRepository({
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
  Future<PartyMembershipResult> changeCharacter(
    PartyChangeCharacterCommand command,
  ) async {
    final invalid = const PartyMembershipCommandValidator().validateChange(
      command,
    );
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    final diagnosticId =
        'characterChanged_${command.recruitmentId}_${command.expectedRecruitmentRevision}';
    return _run((transaction, playerId) async {
      final recruitmentRef = _firestore
          .collection('recruitments')
          .doc(command.recruitmentId);
      final memberRef = recruitmentRef.collection('members').doc(playerId);
      final recruitment = await transaction.get(recruitmentRef);
      final member = await transaction.get(memberRef);
      final raw = recruitment.data();
      final memberData = member.data();
      if (raw == null || memberData == null) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.notFound,
        );
      }
      if (raw['revision'] != command.expectedRecruitmentRevision) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.revisionConflict,
        );
      }
      final aggregate = PartyAtomicDocumentMapper.aggregate(
        Map<String, Object?>.from(raw),
      );
      final nextWeekPrep =
          aggregate.status == PartyRecruitmentStatus.active &&
          aggregate.continueTogether &&
          aggregate.currentCycleStatus == PartyRaidStateStatus.completed;
      if (aggregate.status != PartyRecruitmentStatus.active ||
          (!nextWeekPrep &&
              aggregate.currentCycleStatus != PartyRaidStateStatus.active)) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.recruitmentClosed,
        );
      }
      final oldCharacterId = memberData['characterId'];
      final oldRole = _role(memberData['role']);
      if (oldCharacterId is! String || oldRole == null) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidRequest,
        );
      }
      if (oldCharacterId == command.newCharacterId &&
          oldRole == command.newRole) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.alreadyCurrentCharacter,
        );
      }
      final raidId = raw['raidId'];
      final difficultyId = raw['difficultyId'];
      if (raidId is! String ||
          raidId.isEmpty ||
          difficultyId is! String ||
          difficultyId.isEmpty) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidRequest,
        );
      }

      final characterRef = _firestore
          .collection('characters')
          .doc(command.newCharacterId);
      final previousRaidStateRef = _firestore
          .collection('players')
          .doc(playerId)
          .collection('raidStates')
          .doc(
            PartyRaidState.documentIdFor(
              characterId: oldCharacterId,
              raidId: raidId,
            ),
          );
      final character = await transaction.get(characterRef);
      final previousCharacter = await transaction.get(
        _firestore.collection('characters').doc(oldCharacterId),
      );
      final previousOwnership = await PartyCharacterOwnershipReader.read(
        transaction: transaction,
        firestore: _firestore,
        playerId: playerId,
        character: previousCharacter.data(),
      );
      final previousMemberCondition = previousOwnership.classifyParticipation(
        memberData,
      );
      if (previousMemberCondition != GameAccountOwnershipCondition.current) {
        return PartyMembershipResult.failure(
          previousMemberCondition ==
                  GameAccountOwnershipCondition.ownershipChanged
              ? PartyMembershipFailure.ownershipLost
              : PartyMembershipFailure.stateInconsistent,
        );
      }
      final ownership = await PartyCharacterOwnershipReader.read(
        transaction: transaction,
        firestore: _firestore,
        playerId: playerId,
        character: character.data(),
      );
      if (ownership.condition != GameAccountOwnershipCondition.current) {
        return PartyMembershipResult.failure(
          ownership.condition == GameAccountOwnershipCondition.ownershipChanged
              ? PartyMembershipFailure.ownershipLost
              : PartyMembershipFailure.stateInconsistent,
        );
      }
      final previousRaidState = await transaction.get(previousRaidStateRef);
      final previousStateData = previousRaidState.data();
      if (previousStateData != null &&
          PartyOwnershipRecordPolicy.classify(
                ownership: previousOwnership,
                data: previousStateData,
                playerId: playerId,
                characterId: oldCharacterId,
                raidId: raidId,
                isRaidState: true,
              ) !=
              GameAccountOwnershipCondition.current) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.stateInconsistent,
        );
      }
      final occupancy = await PartyRaidStateOccupancyInspector.inspect(
        transaction: transaction,
        firestore: _firestore,
        playerId: playerId,
        characterId: command.newCharacterId,
        raidId: raidId,
        requestedCycleKey: aggregate.currentCycleKey,
        now: clock(),
        ownership: ownership,
        ignoreCompletedClaim: nextWeekPrep,
      );
      final nextRaidStateRef = occupancy.stateRef;
      final characterData = character.data();
      if (!character.exists || characterData?['status'] != 'active') {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidCharacter,
        );
      }
      if (characterData?['ownerPlayerId'] != playerId) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.ownershipLost,
        );
      }
      if (!nextWeekPrep &&
          (!previousRaidState.exists ||
              previousRaidState.data()?['recruitmentId'] !=
                  command.recruitmentId ||
              previousRaidState.data()?['status'] != 'active')) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.notFound,
        );
      }
      switch (occupancy.decision) {
        case ExistingRaidStateOccupancyDecision.currentCompleted:
          if (nextWeekPrep) break;
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.weeklyRaidCompleted,
          );
        case ExistingRaidStateOccupancyDecision.historicalCompleted:
          if (nextWeekPrep) break;
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.participationConflict,
          );
        case ExistingRaidStateOccupancyDecision.currentActive:
        case ExistingRaidStateOccupancyDecision.participationConflict:
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.participationConflict,
          );
        case ExistingRaidStateOccupancyDecision.currentOrphanActive:
        case ExistingRaidStateOccupancyDecision.historicalOrphanActive:
          return PartyMembershipResult.orphaned(
            occupancy.orphanedParticipation!,
          );
        case ExistingRaidStateOccupancyDecision.inconsistent:
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.stateInconsistent,
          );
        case null:
          break;
      }
      final itemLevel = _parseItemLevel(characterData?['itemAvgLevel']);
      final name = characterData?['characterName'];
      final className = characterData?['characterClassName'];
      if (itemLevel == null ||
          itemLevel < (raw['minItemLevel'] as num? ?? double.infinity) ||
          name is! String ||
          className is! String) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidCharacter,
        );
      }
      if (!_minimumCombatPowerPolicy
          .evaluate(
            minimum: raw['minCombatPower'] as num?,
            actual: command.combatPower,
          )
          .isAllowed) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.minimumCombatPowerNotMet,
        );
      }

      PartyRaidListingTx listing = PartyRaidListingTx.empty;
      if (aggregate.visibility == 'group' && aggregate.groupId != null) {
        final groupMember = await transaction.get(
          _firestore
              .collection('groups')
              .doc(aggregate.groupId!)
              .collection('members')
              .doc(playerId),
        );
        if (groupMember.exists) {
          listing = await PartyRaidListingTx.read(
            transaction: transaction,
            firestore: _firestore,
            groupId: aggregate.groupId,
            recruitmentId: command.recruitmentId,
          );
        }
      }

      if (nextWeekPrep &&
          aggregate.visibility == 'group' &&
          aggregate.groupId != null &&
          listing.snapshot?.exists != true) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.stateInconsistent,
        );
      }
      final now = FieldValue.serverTimestamp();
      final membershipPatch = PartyMembershipWritePlan.changeCharacter(
        characterId: command.newCharacterId,
        characterName: name,
        className: className,
        role: command.newRole.name,
        itemLevel: itemLevel,
        combatPower: command.combatPower,
        gemValidation: command.gemValidation,
        buildIntegrity: command.buildIntegrity,
        serverTimestamp: now,
      );
      if (nextWeekPrep) {
        final plan = PartyAtomicNextWeekCharacterChangeWritePlan(
          ownershipRevision: ownership.revision!,
          aggregate: aggregate,
          rules: _rules(raw),
          playerId: playerId,
          newCharacterId: command.newCharacterId,
          newClassKey: className,
          newRole: command.newRole,
          raidId: raidId,
          difficultyId: difficultyId,
          membershipPatch: membershipPatch,
          serverTimestamp: now,
        );
        transaction.update(recruitmentRef, plan.recruitmentPatch);
        transaction.update(memberRef, plan.membershipPatch);
        listing.write(
          transaction: transaction,
          currentRecruitment: partyRecruitmentMap(raw),
          recruitmentPatch: plan.recruitmentPatch,
        );
        transaction.set(
          _firestore
              .collection('partyEvents')
              .doc(plan.event['eventId']! as String),
          plan.event,
        );
        if (kDebugMode) {
          debugPrint(
            'PartyAtomicMemberMutation id=$diagnosticId mode=nextWeekPrep '
            'cycle=${aggregate.currentCycleKey} revision=${aggregate.revision} '
            'old=$oldCharacterId new=${command.newCharacterId} stateWrites=0 commit=pending',
          );
        }
        return const PartyMembershipResult.success();
      }
      final plan = PartyAtomicCharacterChangeWritePlan(
        ownershipRevision: ownership.revision!,
        aggregate: aggregate,
        rules: _rules(raw),
        playerId: playerId,
        newCharacterId: command.newCharacterId,
        newClassKey: className,
        newRole: command.newRole,
        raidId: raidId,
        difficultyId: difficultyId,
        membershipPatch: membershipPatch,
        serverTimestamp: now,
      );
      transaction.update(recruitmentRef, plan.recruitmentPatch);
      transaction.update(memberRef, plan.membershipPatch);
      transaction.delete(previousRaidStateRef);
      if (kDebugMode) {
        debugPrint(
          'PartyAtomicMemberMutation id=$diagnosticId phase=character-change-plan '
          'room=${command.recruitmentId} player=$playerId '
          'old=$oldCharacterId/$oldRole new=${command.newCharacterId}/${command.newRole} '
          'state=${nextRaidStateRef.path} role=${plan.nextRaidState['role']} '
          'keys=${plan.nextRaidState.keys.join(',')} commit=pending',
        );
      }
      transaction.set(nextRaidStateRef, plan.nextRaidState);
      listing.write(
        transaction: transaction,
        currentRecruitment: partyRecruitmentMap(raw),
        recruitmentPatch: plan.recruitmentPatch,
      );
      transaction.set(
        _firestore
            .collection('partyEvents')
            .doc(plan.event['eventId']! as String),
        plan.event,
      );
      return const PartyMembershipResult.success();
    }, diagnosticId: diagnosticId);
  }

  @override
  Future<PartyMembershipResult> repositionMembers(
    PartyRepositionMembersCommand command,
  ) async {
    final invalid = const PartyMembershipCommandValidator().validateReposition(
      command,
    );
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    return _run((transaction, actorPlayerId) async {
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
      if (raw['revision'] != command.expectedRecruitmentRevision) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.revisionConflict,
        );
      }
      final aggregate = PartyAtomicDocumentMapper.aggregate(
        Map<String, Object?>.from(raw),
      );
      if (aggregate.leaderPlayerId != actorPlayerId) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.unauthorized,
        );
      }
      PartyRaidListingTx listing = PartyRaidListingTx.empty;
      if (aggregate.visibility == 'group' && aggregate.groupId != null) {
        listing = await PartyRaidListingTx.read(
          transaction: transaction,
          firestore: _firestore,
          groupId: aggregate.groupId,
          recruitmentId: command.recruitmentId,
        );
      }
      final now = FieldValue.serverTimestamp();
      final plan = PartyAtomicRepositionWritePlan(
        aggregate: aggregate,
        rules: _rules(raw),
        sourcePlayerId: command.sourcePlayerId,
        destinationPartyIndex: command.destinationPartyIndex,
        destinationSlotIndex: command.destinationSlotIndex,
        actorPlayerId: actorPlayerId,
        serverTimestamp: now,
      );
      for (final entry in plan.membershipPatches.entries) {
        final memberRef = recruitmentRef.collection('members').doc(entry.key);
        final member = await transaction.get(memberRef);
        if (!member.exists) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.notFound,
          );
        }
      }
      transaction.update(recruitmentRef, plan.recruitmentPatch);
      for (final entry in plan.membershipPatches.entries) {
        transaction.update(
          recruitmentRef.collection('members').doc(entry.key),
          entry.value,
        );
      }
      listing.write(
        transaction: transaction,
        currentRecruitment: partyRecruitmentMap(raw),
        recruitmentPatch: plan.recruitmentPatch,
      );
      transaction.set(
        _firestore
            .collection('partyEvents')
            .doc(plan.event['eventId']! as String),
        plan.event,
      );
      return const PartyMembershipResult.success();
    });
  }

  Future<PartyMembershipResult> _run(
    Future<PartyMembershipResult> Function(Transaction, String) action, {
    String? diagnosticId,
  }) async {
    var attempt = 0;
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.unauthenticated,
      );
    }
    try {
      final result = await _firestore.runTransaction((transaction) async {
        attempt++;
        if (kDebugMode) {
          debugPrint(
            'PartyAtomicMemberMutation id=$diagnosticId attempt=$attempt phase=binding-read',
          );
        }
        final binding = await transaction.get(
          _firestore.collection('authBindings').doc(uid),
        );
        final data = binding.data();
        final playerId = data?['playerId'];
        if (data?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.playerBindingMissing,
          );
        }
        return action(transaction, playerId);
      });
      if (kDebugMode) {
        debugPrint(
          'PartyAtomicMemberMutation id=$diagnosticId attempt=$attempt phase=${result.isSuccess ? 'committed' : 'rejected'} failure=${result.failure}',
        );
      }
      return result;
    } on FirebaseException catch (error, stackTrace) {
      assert(() {
        debugPrint(
          'PartyAtomicMemberMutation id=$diagnosticId attempt=$attempt ${error.code} ${error.message}: $stackTrace',
        );
        return true;
      }());
      return PartyMembershipResult.failure(switch (error.code) {
        'permission-denied' => PartyMembershipFailure.permissionDenied,
        'unavailable' ||
        'deadline-exceeded' ||
        'aborted' => PartyMembershipFailure.temporarilyUnavailable,
        _ => PartyMembershipFailure.unknown,
      });
    } on FormatException {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.invalidRequest,
      );
    } on StateError {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.invalidComposition,
      );
    } on ArgumentError {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.invalidRequest,
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

  PartyRole? _role(Object? value) => switch (value) {
    'dealer' => PartyRole.dealer,
    'support' => PartyRole.support,
    _ => null,
  };

  double? _parseItemLevel(Object? value) => value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value.replaceAll(',', '').trim())
      : null;
}
