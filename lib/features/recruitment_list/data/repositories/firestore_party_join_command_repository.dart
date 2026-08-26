import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/party_join_command.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/repositories/party_join_command_repository.dart';
import '../../domain/services/party_join_command_validator.dart';
import '../mappers/party_join_write_plan.dart';

class FirestorePartyJoinCommandRepository
    implements PartyJoinCommandRepository {
  const FirestorePartyJoinCommandRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<PartyJoinResult> joinDirectly(PartyDirectJoinCommand command) async {
    final invalid = const PartyJoinCommandValidator().validateDirectJoin(command);
    if (invalid != null) return PartyJoinResult.failure(invalid);
    return _join(
      recruitmentId: command.recruitmentId,
      expectedRecruitmentRevision: command.expectedRecruitmentRevision,
      expectedApplicationRevision: null,
      requestedCharacterId: command.characterId,
      requestedRole: command.role,
      requestedCycleKey: command.cycleKey,
      combatPower: command.combatPower,
      requiresDirectJoin: true,
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
      final recruitmentRef = _firestore.collection('recruitments').doc(command.recruitmentId);
      final applicationRef = recruitmentRef.collection('applications').doc(command.applicantPlayerId);
      final recruitment = await transaction.get(recruitmentRef);
      final application = await transaction.get(applicationRef);
      final r = recruitment.data();
      final a = application.data();
      if (!recruitment.exists || !application.exists) return const PartyJoinResult.failure(PartyJoinFailure.notFound);
      if (!await _canApprove(transaction, command.recruitmentId, r, actorPlayerId)) return const PartyJoinResult.failure(PartyJoinFailure.unauthorized);
      if (r?['revision'] != command.expectedRecruitmentRevision || a?['revision'] != command.expectedApplicationRevision) return const PartyJoinResult.failure(PartyJoinFailure.revisionConflict);
      if (a?['status'] != 'pending') return const PartyJoinResult.failure(PartyJoinFailure.applicationNotPending);
      final now = FieldValue.serverTimestamp();
      transaction.update(applicationRef, {
        'status': 'rejected',
        'resolutionReason': 'rejectedByApprover',
        'rejectionCount': (a?['rejectionCount'] as int? ?? 0) + 1,
        'revision': command.expectedApplicationRevision + 1,
        'decidedAt': now,
        'updatedAt': now,
      });
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
  }) async {
    if (_firebaseAuth.currentUser == null) {
      return const PartyJoinResult.failure(PartyJoinFailure.unauthenticated);
    }
    final recruitmentRef = _firestore.collection('recruitments').doc(recruitmentId);
    late final QuerySnapshot<Map<String, dynamic>> knownMembers;
    try {
      knownMembers = await recruitmentRef.collection('members').get();
    } on FirebaseException catch (error) {
      return PartyJoinResult.failure(_firebaseFailure(error.code));
    }
    return _run((transaction, actorPlayerId) async {
      final recruitment = await transaction.get(recruitmentRef);
      final r = recruitment.data();
      if (!recruitment.exists) return const PartyJoinResult.failure(PartyJoinFailure.notFound);
      if (r?['revision'] != expectedRecruitmentRevision) return const PartyJoinResult.failure(PartyJoinFailure.revisionConflict);
      if (r?['status'] != 'active' || r?['manualRecruitmentEnabled'] != true) return const PartyJoinResult.failure(PartyJoinFailure.recruitmentClosed);
      if (r?['hasAvailableSlot'] != true) return const PartyJoinResult.failure(PartyJoinFailure.capacityFull);

      final playerId = applicantPlayerId ?? actorPlayerId;
      Map<String, dynamic>? applicationData;
      DocumentReference<Map<String, dynamic>>? applicationRef;
      if (requiresDirectJoin) {
        if ((r?['approvalPolicy'] as Map?)?['mode'] != 'directJoin') return const PartyJoinResult.failure(PartyJoinFailure.approvalModeMismatch);
      } else {
        if (!await _canApprove(transaction, recruitmentId, r, actorPlayerId)) return const PartyJoinResult.failure(PartyJoinFailure.unauthorized);
        applicationRef = recruitmentRef.collection('applications').doc(playerId);
        final application = await transaction.get(applicationRef);
        applicationData = application.data();
        if (!application.exists) return const PartyJoinResult.failure(PartyJoinFailure.notFound);
        if (applicationData?['status'] != 'pending') return const PartyJoinResult.failure(PartyJoinFailure.applicationNotPending);
        if (applicationData?['revision'] != expectedApplicationRevision) return const PartyJoinResult.failure(PartyJoinFailure.revisionConflict);
        requestedCharacterId = applicationData?['characterId'] as String?;
        requestedRole = _role(applicationData?['requestedRole']);
        requestedCycleKey = applicationData?['cycleKey'] as String?;
        combatPower = ((applicationData?['submittedBuildSnapshot'] as Map?)?['combatPower'] as num?)?.toDouble();
      }
      if ((r?['memberPlayerIds'] as List?)?.contains(playerId) == true) return const PartyJoinResult.failure(PartyJoinFailure.alreadyMember);
      if (requestedCharacterId == null || requestedRole == null || requestedCycleKey != r?['targetCycleKey']) return const PartyJoinResult.failure(PartyJoinFailure.invalidRequest);
      final characterId = requestedCharacterId!;
      final role = requestedRole!;
      final cycleKey = requestedCycleKey!;

      final characterRef = _firestore.collection('characters').doc(characterId);
      final assignmentRef = _firestore.collection('players').doc(playerId).collection('activeRaidAssignments').doc('${characterId}_${r?['raidId']}');
      final character = await transaction.get(characterRef);
      final assignment = await transaction.get(assignmentRef);
      final c = character.data();
      if (!character.exists || c?['status'] != 'active') return const PartyJoinResult.failure(PartyJoinFailure.invalidCharacter);
      if (c?['ownerPlayerId'] != playerId) return const PartyJoinResult.failure(PartyJoinFailure.ownershipLost);
      if (assignment.exists) return const PartyJoinResult.failure(PartyJoinFailure.participationConflict);
      final itemLevel = _parseItemLevel(c?['itemAvgLevel']);
      final name = c?['characterName'];
      final className = c?['characterClassName'];
      if (itemLevel == null || itemLevel < (r?['minItemLevel'] as num? ?? double.infinity) || name is! String || className is! String) return const PartyJoinResult.failure(PartyJoinFailure.invalidCharacter);

      final existing = <OccupiedPartyMember>[];
      for (final known in knownMembers.docs) {
        final current = await transaction.get(known.reference);
        if (!current.exists) continue;
        final occupied = _occupiedMember(
          playerId: known.id,
          data: current.data(),
          leaderPlayerId: r?['leaderPlayerId'] as String?,
        );
        if (occupied == null) {
          return const PartyJoinResult.failure(PartyJoinFailure.invalidRequest);
        }
        existing.add(occupied);
      }
      final partyCount = _asInt(r?['partyCount']);
      final membersPerParty = _asInt(r?['membersPerParty']);
      final supportsPerParty = _asInt(r?['supportsPerParty']);
      final maxDealersPerClassPerParty = _asInt(r?['maxDealersPerClassPerParty']);
      final memberCount = _asInt(r?['memberCount']);
      final maxMemberCount = _asInt(r?['maxMemberCount']);
      final dealerCount = _asInt(r?['dealerCount']);
      final supportCount = _asInt(r?['supportCount']);
      final raidId = r?['raidId'];
      final memberPlayerIds = r?['memberPlayerIds'];
      if (partyCount == null ||
          membersPerParty == null ||
          supportsPerParty == null ||
          maxDealersPerClassPerParty == null ||
          memberCount == null ||
          maxMemberCount == null ||
          dealerCount == null ||
          supportCount == null ||
          raidId is! String ||
          memberPlayerIds is! List) {
        return const PartyJoinResult.failure(PartyJoinFailure.invalidRequest);
      }
      final rules = RecruitmentPartyRules(
        partyCount: partyCount,
        membersPerParty: membersPerParty,
        supportsPerParty: supportsPerParty,
        maxDealersPerClassPerParty: maxDealersPerClassPerParty,
      );
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
      final plan = PartyJoinWritePlan.create(
        recruitmentId: recruitmentId, playerId: playerId, characterId: characterId,
        characterName: name, className: className, itemLevel: itemLevel, combatPower: combatPower,
        role: role, partyIndex: placement.slot!.partyIndex, slotIndex: placement.slot!.slotIndex,
        joinedBy: actorPlayerId,
        raidId: raidId, cycleKey: cycleKey, memberCount: memberCount,
        memberPlayerIds: List<String>.from(memberPlayerIds),
        maxMemberCount: maxMemberCount, dealerCount: dealerCount,
        supportCount: supportCount, revision: expectedRecruitmentRevision, serverTimestamp: now,
      );
      final memberRef = recruitmentRef.collection('members').doc(playerId);
      transaction.update(recruitmentRef, plan.recruitmentUpdate);
      transaction.set(memberRef, plan.membership);
      transaction.set(assignmentRef, plan.assignment);
      if (applicationRef != null) {
        transaction.update(applicationRef, {
          'status': 'approved', 'resolutionReason': 'approvedByApprover',
          'approvalCount': (applicationData?['approvalCount'] as int? ?? 0) + 1,
          'revision': expectedApplicationRevision! + 1, 'decidedAt': now, 'updatedAt': now,
        });
      }
      return const PartyJoinResult.success();
    });
  }

  Future<PartyJoinResult> _run(Future<PartyJoinResult> Function(Transaction, String) action) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return const PartyJoinResult.failure(PartyJoinFailure.unauthenticated);
    try {
      return await _firestore.runTransaction((transaction) async {
        final binding = await transaction.get(_firestore.collection('authBindings').doc(uid));
        final data = binding.data();
        final playerId = data?['playerId'];
        if (data?['status'] != 'active' || playerId is! String || playerId.isEmpty) return const PartyJoinResult.failure(PartyJoinFailure.playerBindingMissing);
        return action(transaction, playerId);
      });
    } on FirebaseException catch (error) {
      return PartyJoinResult.failure(_firebaseFailure(error.code));
    } catch (_) {
      return const PartyJoinResult.failure(PartyJoinFailure.unknown);
    }
  }

  Future<bool> _canApprove(
    Transaction transaction,
    String recruitmentId,
    Map<String, dynamic>? recruitment,
    String playerId,
  ) async {
    if (recruitment?['leaderPlayerId'] == playerId) return true;
    final member = await transaction.get(
      _firestore
          .collection('recruitments')
          .doc(recruitmentId)
          .collection('members')
          .doc(playerId),
    );
    return member.data()?['canApproveApplications'] == true;
  }
}

PartyRole? _role(Object? value) => switch (value) {
  'dealer' => PartyRole.dealer,
  'support' => PartyRole.support,
  _ => null,
};

OccupiedPartyMember? _occupiedMember({
  required String playerId,
  required Map<String, dynamic>? data,
  required String? leaderPlayerId,
}) {
  final role = _role(data?['role']);
  final memberClass = data?['classNameSnapshot'];
  final partyIndex = _asInt(data?['partyIndex']);
  final slotIndex = _asInt(data?['slotIndex']);
  if (role == null || memberClass is! String || partyIndex == null) return null;
  return OccupiedPartyMember(
    id: playerId,
    className: memberClass,
    role: role,
    partyIndex: partyIndex,
    slotIndex: slotIndex,
    joinedAt: _joinedAt(data?['joinedAt']),
    isLeader: playerId == leaderPlayerId,
  );
}

DateTime? _joinedAt(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

double? _parseItemLevel(Object? value) => value is num ? value.toDouble() : value is String ? double.tryParse(value.replaceAll(',', '').trim()) : null;

PartyJoinFailure _placementFailure(PartyCompositionFailure failure) => switch (failure) {
  PartyCompositionFailure.partyFull => PartyJoinFailure.capacityFull,
  PartyCompositionFailure.dealerSlotsFull || PartyCompositionFailure.supportSlotsFull => PartyJoinFailure.roleCapacityFull,
  PartyCompositionFailure.duplicateDealerClass => PartyJoinFailure.duplicateDealerClass,
  _ => PartyJoinFailure.invalidRequest,
};

PartyJoinFailure _firebaseFailure(String code) => switch (code) {
  'permission-denied' => PartyJoinFailure.permissionDenied,
  'unavailable' || 'deadline-exceeded' || 'aborted' =>
    PartyJoinFailure.temporarilyUnavailable,
  _ => PartyJoinFailure.unknown,
};
