import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_gem_validation_snapshot.dart';
import '../../domain/entities/party_join_command.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/policies/minimum_combat_power_policy.dart';
import '../../domain/repositories/party_join_command_repository.dart';
import '../../domain/services/party_join_command_validator.dart';
import '../../domain/services/party_create_occupancy_gate.dart';
import '../mappers/party_atomic_application_write_plan.dart';
import '../mappers/party_atomic_document_mapper.dart';
import '../mappers/party_atomic_membership_write_plan.dart';
import '../mappers/party_join_write_plan.dart';
import 'party_raid_state_occupancy_inspector.dart';
import 'party_character_ownership_reader.dart';

/// 새 Aggregate·raidState 구조용 즉시 가입·승인·거절 Repository.
///
/// 전원 membership 재조회와 개인 event fan-out을 쓰지 않으며 운영 모집 상세의
/// 즉시 가입·승인·거절 명령에 연결된다.
class FirestorePartyAtomicJoinCommandRepository
    implements PartyJoinCommandRepository {
  const FirestorePartyAtomicJoinCommandRepository({
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
  Future<PartyJoinResult> joinDirectly(PartyDirectJoinCommand command) async {
    final invalid = const PartyJoinCommandValidator().validateDirectJoin(
      command,
    );
    if (invalid != null) return PartyJoinResult.failure(invalid);
    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await _join(
        recruitmentId: command.recruitmentId,
        expectedRecruitmentRevision: command.expectedRecruitmentRevision,
        expectedApplicationRevision: null,
        requestedCharacterId: command.characterId,
        requestedRole: command.role,
        requestedCycleKey: command.cycleKey,
        combatPower: command.combatPower,
        gemValidation: command.gemValidation,
        buildIntegrity: command.buildIntegrity,
        requiresDirectJoin: true,
      );
      if (!result.didRollOverHistoricalState) return result;
    }
    return const PartyJoinResult.failure(
      PartyJoinFailure.temporarilyUnavailable,
    );
  }

  @override
  Future<PartyJoinResult> approve(PartyDecideApplicationCommand command) async {
    final invalid = const PartyJoinCommandValidator().validateDecision(command);
    if (invalid != null) return PartyJoinResult.failure(invalid);
    return _join(
      recruitmentId: command.recruitmentId,
      expectedRecruitmentRevision: command.expectedRecruitmentRevision,
      expectedApplicationRevision: command.expectedApplicationRevision,
      applicantPlayerId: command.applicantPlayerId,
      requiresDirectJoin: false,
    );
  }

  @override
  Future<PartyJoinResult> reject(PartyDecideApplicationCommand command) async {
    final invalid = const PartyJoinCommandValidator().validateDecision(command);
    if (invalid != null) return PartyJoinResult.failure(invalid);
    return _run((transaction, actorPlayerId) async {
      final recruitmentRef = _firestore
          .collection('recruitments')
          .doc(command.recruitmentId);
      final applicationRef = recruitmentRef
          .collection('applications')
          .doc(command.applicantPlayerId);
      final recruitment = await transaction.get(recruitmentRef);
      final application = await transaction.get(applicationRef);
      final raw = recruitment.data();
      final applicationData = application.data();
      if (raw == null || applicationData == null) {
        return const PartyJoinResult.failure(PartyJoinFailure.notFound);
      }
      if (raw['revision'] != command.expectedRecruitmentRevision ||
          applicationData['revision'] != command.expectedApplicationRevision) {
        return const PartyJoinResult.failure(PartyJoinFailure.revisionConflict);
      }
      if (applicationData['status'] != 'pending') {
        return const PartyJoinResult.failure(
          PartyJoinFailure.applicationNotPending,
        );
      }
      final aggregate = PartyAtomicDocumentMapper.aggregate(
        Map<String, Object?>.from(raw),
      );
      if (!await _canApprove(
        transaction,
        command.recruitmentId,
        aggregate,
        actorPlayerId,
      )) {
        return const PartyJoinResult.failure(PartyJoinFailure.unauthorized);
      }
      final now = FieldValue.serverTimestamp();
      final plan = PartyAtomicApplicationRejectWritePlan(
        application: Map<String, Object?>.from(applicationData),
        aggregate: aggregate,
        applicantPlayerId: command.applicantPlayerId,
        actorPlayerId: actorPlayerId,
        applicationRevision: command.expectedApplicationRevision,
        serverTimestamp: now,
      );
      transaction.update(applicationRef, plan.applicationPatch);
      transaction.update(recruitmentRef, plan.recruitmentPatch);
      transaction.set(
        _firestore
            .collection('partyEvents')
            .doc(plan.event['eventId']! as String),
        plan.event,
      );
      return const PartyJoinResult.success();
    });
  }

  Future<PartyJoinResult> _join({
    required String recruitmentId,
    required int expectedRecruitmentRevision,
    required int? expectedApplicationRevision,
    required bool requiresDirectJoin,
    String? applicantPlayerId,
    String? requestedCharacterId,
    PartyRole? requestedRole,
    String? requestedCycleKey,
    double? combatPower,
    PartyGemValidationSnapshot? gemValidation,
    BuildIntegritySnapshot? buildIntegrity,
  }) {
    return _run((transaction, actorPlayerId) async {
      final recruitmentRef = _firestore
          .collection('recruitments')
          .doc(recruitmentId);
      final recruitment = await transaction.get(recruitmentRef);
      final raw = recruitment.data();
      if (raw == null) {
        return const PartyJoinResult.failure(PartyJoinFailure.notFound);
      }
      if (raw['revision'] != expectedRecruitmentRevision) {
        return const PartyJoinResult.failure(PartyJoinFailure.revisionConflict);
      }
      if (raw['status'] != 'active' ||
          raw['manualRecruitmentEnabled'] != true) {
        return const PartyJoinResult.failure(
          PartyJoinFailure.recruitmentClosed,
        );
      }
      final aggregate = PartyAtomicDocumentMapper.aggregate(
        Map<String, Object?>.from(raw),
      );
      final rules = _rules(raw);
      if (aggregate.memberCount >= rules.totalMembers) {
        return const PartyJoinResult.failure(PartyJoinFailure.capacityFull);
      }

      final playerId = applicantPlayerId ?? actorPlayerId;
      Map<String, dynamic>? applicationData;
      DocumentReference<Map<String, dynamic>>? applicationRef;
      Map<String, Object?>? gemValidationFields = gemValidation?.toFields();
      Map<String, Object?>? buildIntegrityFields = buildIntegrity?.toFields();
      if (requiresDirectJoin) {
        if ((raw['approvalPolicy'] as Map?)?['mode'] != 'directJoin') {
          return const PartyJoinResult.failure(
            PartyJoinFailure.approvalModeMismatch,
          );
        }
      } else {
        if (!await _canApprove(
          transaction,
          recruitmentId,
          aggregate,
          actorPlayerId,
        )) {
          return const PartyJoinResult.failure(PartyJoinFailure.unauthorized);
        }
        applicationRef = recruitmentRef
            .collection('applications')
            .doc(playerId);
        final application = await transaction.get(applicationRef);
        applicationData = application.data();
        if (!application.exists || applicationData == null) {
          return const PartyJoinResult.failure(PartyJoinFailure.notFound);
        }
        if (applicationData['status'] != 'pending') {
          return const PartyJoinResult.failure(
            PartyJoinFailure.applicationNotPending,
          );
        }
        if (applicationData['revision'] != expectedApplicationRevision) {
          return const PartyJoinResult.failure(
            PartyJoinFailure.revisionConflict,
          );
        }
        requestedCharacterId = applicationData['characterId'] as String?;
        requestedRole = _role(applicationData['requestedRole']);
        requestedCycleKey = applicationData['cycleKey'] as String?;
        final submitted = applicationData['submittedBuildSnapshot'];
        if (submitted is Map) {
          combatPower = (submitted['combatPower'] as num?)?.toDouble();
          gemValidationFields = PartyGemValidationSnapshot.copyFieldsIfComplete(
            Map<Object?, Object?>.from(submitted),
          );
          buildIntegrityFields =
              PartyJoinWritePlan.copyBuildIntegrityFieldsIfComplete(
                submitted['buildIntegritySnapshot'],
                parseDate: _snapshotDate,
              );
        }
      }
      if (aggregate.partySlots.any((slot) => slot.playerId == playerId)) {
        return const PartyJoinResult.failure(PartyJoinFailure.alreadyMember);
      }
      if (requestedCharacterId == null ||
          requestedRole == null ||
          requestedCycleKey != raw['targetCycleKey']) {
        return const PartyJoinResult.failure(PartyJoinFailure.invalidRequest);
      }
      final characterId = requestedCharacterId!;
      final role = requestedRole!;
      final cycleKey = requestedCycleKey!;
      final raidId = raw['raidId'];
      final difficultyId = raw['difficultyId'];
      if (raidId is! String ||
          raidId.isEmpty ||
          difficultyId is! String ||
          difficultyId.isEmpty) {
        return const PartyJoinResult.failure(PartyJoinFailure.invalidRequest);
      }

      final characterRef = _firestore.collection('characters').doc(characterId);
      final raidStateRef = _firestore
          .collection('players')
          .doc(playerId)
          .collection('raidStates')
          .doc(
            PartyRaidState.documentIdFor(
              characterId: characterId,
              raidId: raidId,
            ),
          );
      final character = await transaction.get(characterRef);
      final ownership = await PartyCharacterOwnershipReader.read(
        transaction: transaction,
        firestore: _firestore,
        playerId: playerId,
        character: character.data(),
      );
      if (ownership.condition != GameAccountOwnershipCondition.current) {
        return PartyJoinResult.failure(
          ownership.condition == GameAccountOwnershipCondition.ownershipChanged
              ? PartyJoinFailure.ownershipLost
              : PartyJoinFailure.stateInconsistent,
        );
      }
      if (applicationData != null) {
        final condition = ownership.classifyParticipation(applicationData);
        if (condition != GameAccountOwnershipCondition.current) {
          return PartyJoinResult.failure(
            condition == GameAccountOwnershipCondition.ownershipChanged
                ? PartyJoinFailure.ownershipLost
                : PartyJoinFailure.stateInconsistent,
          );
        }
      }
      // 승인자는 신청자 소유 raidState를 읽을 수 없다. 새 state 쓰기는
      // Rules create/update와 weekly Claim 검사에서 최종 충돌을 판정한다.
      final occupancy = playerId == actorPlayerId
          ? await PartyRaidStateOccupancyInspector.inspect(
              transaction: transaction,
              firestore: _firestore,
              playerId: playerId,
              characterId: characterId,
              raidId: raidId,
              requestedCycleKey: cycleKey,
              now: clock(),
              ownership: ownership,
            )
          : null;
      final characterData = character.data();
      if (!character.exists || characterData?['status'] != 'active') {
        return const PartyJoinResult.failure(PartyJoinFailure.invalidCharacter);
      }
      if (characterData?['ownerPlayerId'] != playerId) {
        return const PartyJoinResult.failure(PartyJoinFailure.ownershipLost);
      }
      if (occupancy != null) {
        switch (occupancy.decision) {
          case ExistingRaidStateOccupancyDecision.currentCompleted:
            return const PartyJoinResult.failure(
              PartyJoinFailure.weeklyRaidCompleted,
            );
          case ExistingRaidStateOccupancyDecision.currentActive:
          case ExistingRaidStateOccupancyDecision.participationConflict:
            return const PartyJoinResult.failure(
              PartyJoinFailure.participationConflict,
            );
          case ExistingRaidStateOccupancyDecision.currentOrphanActive:
          case ExistingRaidStateOccupancyDecision.historicalOrphanActive:
            return PartyJoinResult.orphaned(occupancy.orphanedParticipation!);
          case ExistingRaidStateOccupancyDecision.historicalCompleted:
            transaction.delete(occupancy.stateRef);
            return const PartyJoinResult.historicalStateRolledOver();
          case ExistingRaidStateOccupancyDecision.inconsistent:
            return const PartyJoinResult.failure(
              PartyJoinFailure.stateInconsistent,
            );
          case null:
            break;
        }
      }

      final itemLevel = _parseItemLevel(characterData?['itemAvgLevel']);
      final name = characterData?['characterName'];
      final className = characterData?['characterClassName'];
      if (itemLevel == null ||
          itemLevel < (raw['minItemLevel'] as num? ?? double.infinity) ||
          name is! String ||
          className is! String) {
        return const PartyJoinResult.failure(PartyJoinFailure.invalidCharacter);
      }
      if (!_minimumCombatPowerPolicy
          .evaluate(minimum: raw['minCombatPower'] as num?, actual: combatPower)
          .isAllowed) {
        return const PartyJoinResult.failure(
          PartyJoinFailure.minimumCombatPowerNotMet,
        );
      }

      var joiningIsGroupMember = true;
      final groupId = aggregate.groupId;
      if (groupId != null) {
        final groupMember = await transaction.get(
          _firestore
              .collection('groups')
              .doc(groupId)
              .collection('members')
              .doc(playerId),
        );
        joiningIsGroupMember = groupMember.exists;
      }

      final existing = [
        for (final slot in aggregate.partySlots)
          OccupiedPartyMember(
            id: slot.playerId,
            className: slot.classKey,
            role: slot.role,
            partyIndex: slot.partyIndex,
            slotIndex: slot.slotIndex,
            isLeader: slot.playerId == aggregate.leaderPlayerId,
          ),
      ];
      final placement = PartyCompositionPolicy(rules).assignEmptySlot(
        joining: OccupiedPartyMember(
          id: playerId,
          className: className,
          role: role,
          partyIndex: 0,
        ),
        existing: existing,
      );
      if (!placement.canJoin || placement.slot == null) {
        return PartyJoinResult.failure(_placementFailure(placement.failure));
      }

      final now = FieldValue.serverTimestamp();
      final base = PartyJoinWritePlan.create(
        recruitmentId: recruitmentId,
        playerId: playerId,
        characterId: characterId,
        characterName: name,
        className: className,
        itemLevel: itemLevel,
        combatPower: combatPower,
        gemValidationFields: gemValidationFields,
        buildIntegrityFields: buildIntegrityFields,
        role: role,
        partyIndex: placement.slot!.partyIndex,
        slotIndex: placement.slot!.slotIndex,
        joinedBy: actorPlayerId,
        raidId: raidId,
        cycleKey: cycleKey,
        memberCount: aggregate.memberCount,
        memberPlayerIds: [
          for (final slot in aggregate.partySlots) slot.playerId,
        ],
        maxMemberCount: rules.totalMembers,
        dealerCount: aggregate.dealerCount,
        supportCount: aggregate.supporterCount,
        revision: expectedRecruitmentRevision,
        serverTimestamp: now,
      );
      final joinPlan = PartyAtomicJoinWritePlan.fromBase(
        base: base,
        aggregate: aggregate,
        rules: rules,
        classKey: className,
        raidId: raidId,
        difficultyId: difficultyId,
        joiningIsGroupMember: joiningIsGroupMember,
        ownershipRevision: ownership.revision!,
        serverTimestamp: now,
      );

      if (applicationRef != null) {
        final countedAsNonGroup =
            applicationData?['countedAsNonGroupApplicant'] == true;
        final currentApprovalCount =
            (applicationData?['approvalCount'] as num?)?.toInt() ?? 0;
        final approvalPlan = PartyAtomicApprovalWritePlan(
          join: joinPlan,
          aggregate: aggregate,
          applicantCountedAsNonGroup: countedAsNonGroup,
          applicationRevision: expectedApplicationRevision!,
          currentApprovalCount: currentApprovalCount,
          serverTimestamp: now,
        );
        transaction.update(recruitmentRef, approvalPlan.recruitmentPatch);
        transaction.update(applicationRef, approvalPlan.applicationPatch);
        transaction.set(
          recruitmentRef.collection('members').doc(playerId),
          approvalPlan.membership,
        );
        transaction.set(raidStateRef, approvalPlan.raidState);

        transaction.set(
          _firestore
              .collection('partyEvents')
              .doc(approvalPlan.event['eventId']! as String),
          approvalPlan.event,
        );
        return const PartyJoinResult.success();
      }

      transaction.update(recruitmentRef, joinPlan.recruitmentPatch);
      transaction.set(
        recruitmentRef.collection('members').doc(playerId),
        joinPlan.membership,
      );
      transaction.set(raidStateRef, joinPlan.raidState);

      transaction.set(
        _firestore
            .collection('partyEvents')
            .doc(joinPlan.event['eventId']! as String),
        joinPlan.event,
      );
      return const PartyJoinResult.success();
    });
  }

  Future<PartyJoinResult> _run(
    Future<PartyJoinResult> Function(Transaction, String) action,
  ) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      return const PartyJoinResult.failure(PartyJoinFailure.unauthenticated);
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
          return const PartyJoinResult.failure(
            PartyJoinFailure.playerBindingMissing,
          );
        }
        return action(transaction, playerId);
      });
    } on FirebaseException catch (error, stack) {
      if (kDebugMode) {
        debugPrint(
          'PartyAtomicJoin FirebaseException code=${error.code} message=${error.message}',
        );
        debugPrintStack(stackTrace: stack);
      }
      return PartyJoinResult.failure(switch (error.code) {
        'permission-denied' => PartyJoinFailure.permissionDenied,
        'unavailable' ||
        'deadline-exceeded' ||
        'aborted' => PartyJoinFailure.temporarilyUnavailable,
        _ => PartyJoinFailure.unknown,
      });
    } on FormatException {
      return const PartyJoinResult.failure(PartyJoinFailure.invalidRequest);
    } on StateError {
      return const PartyJoinResult.failure(PartyJoinFailure.invalidRequest);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('PartyAtomicJoin unexpected $error');
        debugPrintStack(stackTrace: stack);
      }
      return const PartyJoinResult.failure(PartyJoinFailure.unknown);
    }
  }

  Future<bool> _canApprove(
    Transaction transaction,
    String recruitmentId,
    PartyCommandAggregate aggregate,
    String playerId,
  ) async {
    if (aggregate.leaderPlayerId == playerId) return true;
    final member = await transaction.get(
      _firestore
          .collection('recruitments')
          .doc(recruitmentId)
          .collection('members')
          .doc(playerId),
    );
    return member.data()?['canApproveApplications'] == true;
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

  DateTime? _snapshotDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  double? _parseItemLevel(Object? value) => value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value.replaceAll(',', '').trim())
      : null;

  PartyJoinFailure _placementFailure(PartyCompositionFailure failure) =>
      switch (failure) {
        PartyCompositionFailure.partyFull => PartyJoinFailure.capacityFull,
        PartyCompositionFailure.dealerSlotsFull ||
        PartyCompositionFailure.supportSlotsFull =>
          PartyJoinFailure.roleCapacityFull,
        PartyCompositionFailure.duplicateDealerClass =>
          PartyJoinFailure.duplicateDealerClass,
        _ => PartyJoinFailure.invalidRequest,
      };
}
