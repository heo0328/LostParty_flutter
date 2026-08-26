import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/party_event.dart';
import '../../domain/entities/party_membership_command.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/repositories/party_membership_command_repository.dart';
import '../../domain/services/party_membership_command_validator.dart';
import '../mappers/party_membership_event_writer.dart';
import '../mappers/party_membership_write_plan.dart';

class FirestorePartyMembershipCommandRepository implements PartyMembershipCommandRepository {
  const FirestorePartyMembershipCommandRepository({required FirebaseFirestore firestore, required FirebaseAuth firebaseAuth}) : _firestore = firestore, _firebaseAuth = firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<PartyMembershipResult> changeCharacter(PartyChangeCharacterCommand command) async {
    final invalid = const PartyMembershipCommandValidator().validateChange(command);
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    if (_firebaseAuth.currentUser == null) return const PartyMembershipResult.failure(PartyMembershipFailure.unauthenticated);
    final knownMembers = await _members(command.recruitmentId);
    if (knownMembers == null) return const PartyMembershipResult.failure(PartyMembershipFailure.temporarilyUnavailable);
    return _run((transaction, playerId) async {
      final recruitmentRef = _firestore.collection('recruitments').doc(command.recruitmentId);
      final memberRef = recruitmentRef.collection('members').doc(playerId);
      final recruitment = await transaction.get(recruitmentRef);
      final member = await transaction.get(memberRef);
      final r = recruitment.data();
      final m = member.data();
      final common = _validateActive(r, command.expectedRecruitmentRevision);
      if (common != null) return PartyMembershipResult.failure(common);
      if (!member.exists) return const PartyMembershipResult.failure(PartyMembershipFailure.notFound);
      final oldCharacterId = m?['characterId'];
      final role = _role(m?['role']);
      if (oldCharacterId == command.newCharacterId) return const PartyMembershipResult.failure(PartyMembershipFailure.alreadyCurrentCharacter);
      if (oldCharacterId is! String || role == null) return const PartyMembershipResult.failure(PartyMembershipFailure.unknown);
      final characterRef = _firestore.collection('characters').doc(command.newCharacterId);
      final oldAssignmentRef = _assignment(playerId, oldCharacterId, r?['raidId'] as String);
      final newAssignmentRef = _assignment(playerId, command.newCharacterId, r?['raidId'] as String);
      final character = await transaction.get(characterRef);
      final oldAssignment = await transaction.get(oldAssignmentRef);
      final newAssignment = await transaction.get(newAssignmentRef);
      final c = character.data();
      if (!character.exists || c?['status'] != 'active') return const PartyMembershipResult.failure(PartyMembershipFailure.invalidCharacter);
      if (c?['ownerPlayerId'] != playerId) return const PartyMembershipResult.failure(PartyMembershipFailure.ownershipLost);
      if (!oldAssignment.exists) return const PartyMembershipResult.failure(PartyMembershipFailure.notFound);
      if (newAssignment.exists) return const PartyMembershipResult.failure(PartyMembershipFailure.participationConflict);
      final itemLevel = _itemLevel(c?['itemAvgLevel']);
      final name = c?['characterName'];
      final className = c?['characterClassName'];
      if (itemLevel == null || itemLevel < (r?['minItemLevel'] as num? ?? double.infinity) || name is! String || className is! String) return const PartyMembershipResult.failure(PartyMembershipFailure.invalidCharacter);
      final composition = await _composition(transaction, knownMembers, replacePlayerId: playerId, replacementClassName: className, replacementRole: role, recruitment: r!);
      if (!composition) return const PartyMembershipResult.failure(PartyMembershipFailure.invalidComposition);
      final previousCharacterName = m?['characterNameSnapshot'];
      if (previousCharacterName is! String) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.unknown,
        );
      }
      final now = FieldValue.serverTimestamp();
      final nextRevision = command.expectedRecruitmentRevision + 1;
      final beforeMembers = List<String>.from(r['memberPlayerIds'] as List);
      transaction.update(
        memberRef,
        PartyMembershipWritePlan.changeCharacter(
          characterId: command.newCharacterId,
          characterName: name,
          className: className,
          itemLevel: itemLevel,
          combatPower: command.combatPower,
          serverTimestamp: now,
        ),
      );
      transaction.delete(oldAssignmentRef);
      transaction.set(newAssignmentRef, {
        ...oldAssignment.data()!,
        'characterId': command.newCharacterId,
        'createdAt': now,
        'updatedAt': now,
      });
      if (r['leaderPlayerId'] == playerId) {
        transaction.update(
          recruitmentRef,
          PartyMembershipWritePlan.leaderDisplaySnapshots(
            characterName: name,
            className: className,
            revision: command.expectedRecruitmentRevision,
            serverTimestamp: now,
          ),
        );
      } else {
        transaction.update(recruitmentRef, {
          'revision': nextRevision,
          'updatedAt': now,
        });
      }
      PartyMembershipEventWriter.writeToRecipients(
        transaction: transaction,
        firestore: _firestore,
        type: PartyEventType.memberCharacterChanged,
        recipientPlayerIds: beforeMembers,
        recruitmentId: command.recruitmentId,
        recruitmentRevision: nextRevision,
        actorPlayerId: playerId,
        targetPlayerId: playerId,
        characterNameSnapshot: name,
        classNameSnapshot: className,
        role: role.name,
        previousCharacterNameSnapshot: previousCharacterName,
        raidId: r['raidId'] is String ? r['raidId'] as String : null,
        difficultyId: r['difficultyId'] is String
            ? r['difficultyId'] as String
            : null,
        partyIndex: m?['partyIndex'] is int ? m!['partyIndex'] as int : null,
        slotIndex: m?['slotIndex'] is int ? m!['slotIndex'] as int : null,
        serverTimestamp: now,
      );
      return const PartyMembershipResult.success();
    });
  }

  @override
  Future<PartyMembershipResult> leave(PartyRemoveMemberCommand command) async {
    final invalid = const PartyMembershipCommandValidator().validateRemove(command);
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    return _remove(command, kick: false);
  }

  @override
  Future<PartyMembershipResult> kick(PartyRemoveMemberCommand command) async {
    final invalid = const PartyMembershipCommandValidator().validateRemove(command);
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    return _remove(command, kick: true);
  }

  Future<PartyMembershipResult> _remove(PartyRemoveMemberCommand command, {required bool kick}) async {
    return _run((transaction, actorPlayerId) async {
      final recruitmentRef = _firestore.collection('recruitments').doc(command.recruitmentId);
      final targetRef = recruitmentRef.collection('members').doc(command.targetPlayerId);
      final recruitment = await transaction.get(recruitmentRef);
      final target = await transaction.get(targetRef);
      final r = recruitment.data();
      final m = target.data();
      final common = _validateActive(r, command.expectedRecruitmentRevision);
      if (common != null) return PartyMembershipResult.failure(common);
      if (!target.exists) return const PartyMembershipResult.failure(PartyMembershipFailure.notFound);
      final unauthorized = kick
          ? (r?['leaderPlayerId'] != actorPlayerId ||
              command.targetPlayerId == actorPlayerId)
          : command.targetPlayerId != actorPlayerId;
      if (unauthorized) return const PartyMembershipResult.failure(PartyMembershipFailure.unauthorized);
      final remaining = List<String>.from(r?['memberPlayerIds'] as List)
        ..remove(command.targetPlayerId);
      final oldLeader = r?['leaderPlayerId'] as String;
      final nextLeader = oldLeader == command.targetPlayerId
          ? (remaining.isEmpty ? null : remaining.first)
          : oldLeader;
      final characterId = m?['characterId'] as String;
      final role = m?['role'] as String;
      final characterName = m?['characterNameSnapshot'];
      if (characterName is! String) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.unknown,
        );
      }
      final beforeMembers = List<String>.from(r?['memberPlayerIds'] as List);
      final now = FieldValue.serverTimestamp();
      final nextRevision = command.expectedRecruitmentRevision + 1;
      String? nextLeaderCharacterName;
      String? nextLeaderClassName;
      if (nextLeader != null) {
        final nextLeaderDoc = await transaction.get(
          recruitmentRef.collection('members').doc(nextLeader),
        );
        final leaderData = nextLeaderDoc.data();
        nextLeaderCharacterName =
            leaderData?['characterNameSnapshot'] as String?;
        nextLeaderClassName = leaderData?['classNameSnapshot'] as String?;
      }
      transaction.update(
        recruitmentRef,
        PartyMembershipWritePlan.removeFromRecruitment(
          memberPlayerIds: List<String>.from(r?['memberPlayerIds'] as List),
          targetPlayerId: command.targetPlayerId,
          memberCount: r?['memberCount'] as int,
          dealerCount: r?['dealerCount'] as int,
          supportCount: r?['supportCount'] as int,
          targetRole: role,
          maxMemberCount: r?['maxMemberCount'] as int,
          revision: command.expectedRecruitmentRevision,
          nextLeaderPlayerId: nextLeader,
          nextLeaderCharacterName: nextLeaderCharacterName,
          nextLeaderClassName: nextLeaderClassName,
          serverTimestamp: now,
        ),
      );
      transaction.delete(targetRef);
      transaction.delete(
        _assignment(command.targetPlayerId, characterId, r?['raidId'] as String),
      );
      if (nextLeader != null && nextLeader != oldLeader) {
        transaction.update(
          recruitmentRef.collection('members').doc(nextLeader),
          {'canApproveApplications': true, 'updatedAt': now},
        );
      }
      final raidId = r?['raidId'] is String ? r!['raidId'] as String : null;
      final difficultyId =
          r?['difficultyId'] is String ? r!['difficultyId'] as String : null;
      final className = m?['classNameSnapshot'] is String
          ? m!['classNameSnapshot'] as String
          : null;
      final partyIndex = m?['partyIndex'] is int ? m!['partyIndex'] as int : null;
      final slotIndex = m?['slotIndex'] is int ? m!['slotIndex'] as int : null;
      if (kick) {
        PartyMembershipEventWriter.writeToRecipients(
          transaction: transaction,
          firestore: _firestore,
          type: PartyEventType.memberKicked,
          recipientPlayerIds: {...remaining, command.targetPlayerId},
          recruitmentId: command.recruitmentId,
          recruitmentRevision: nextRevision,
          actorPlayerId: actorPlayerId,
          targetPlayerId: command.targetPlayerId,
          targetCharacterNameSnapshot: characterName,
          characterNameSnapshot: characterName,
          classNameSnapshot: className,
          role: role,
          raidId: raidId,
          difficultyId: difficultyId,
          partyIndex: partyIndex,
          slotIndex: slotIndex,
          serverTimestamp: now,
        );
      } else {
        PartyMembershipEventWriter.writeToRecipients(
          transaction: transaction,
          firestore: _firestore,
          type: PartyEventType.memberLeft,
          recipientPlayerIds: beforeMembers,
          recruitmentId: command.recruitmentId,
          recruitmentRevision: nextRevision,
          actorPlayerId: actorPlayerId,
          targetPlayerId: command.targetPlayerId,
          characterNameSnapshot: characterName,
          classNameSnapshot: className,
          role: role,
          raidId: raidId,
          difficultyId: difficultyId,
          partyIndex: partyIndex,
          slotIndex: slotIndex,
          serverTimestamp: now,
        );
      }
      return const PartyMembershipResult.success();
    });
  }

  @override
  Future<PartyMembershipResult> setApprovalPermission(PartySetApprovalPermissionCommand command) async {
    final invalid = const PartyMembershipCommandValidator().validatePermission(command);
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    return _run((transaction, actorPlayerId) async {
      final recruitmentRef = _firestore.collection('recruitments').doc(command.recruitmentId);
      final targetRef = recruitmentRef.collection('members').doc(command.targetPlayerId);
      final recruitment = await transaction.get(recruitmentRef);
      final target = await transaction.get(targetRef);
      final r = recruitment.data();
      final common = _validateActive(r, command.expectedRecruitmentRevision);
      if (common != null) return PartyMembershipResult.failure(common);
      if (r?['leaderPlayerId'] != actorPlayerId || command.targetPlayerId == actorPlayerId) return const PartyMembershipResult.failure(PartyMembershipFailure.unauthorized);
      if (!target.exists) return const PartyMembershipResult.failure(PartyMembershipFailure.notFound);
      final now = FieldValue.serverTimestamp();
      transaction.update(targetRef, PartyMembershipWritePlan.setApprovalPermission(enabled: command.enabled, serverTimestamp: now));
      transaction.update(recruitmentRef, {'revision': command.expectedRecruitmentRevision + 1, 'updatedAt': now});
      return const PartyMembershipResult.success();
    });
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _members(String recruitmentId) async {
    if (_firebaseAuth.currentUser == null) return null;
    try { return await _firestore.collection('recruitments').doc(recruitmentId).collection('members').get(); } on FirebaseException { return null; }
  }

  Future<bool> _composition(Transaction transaction, QuerySnapshot<Map<String, dynamic>> known, {required String replacePlayerId, required String replacementClassName, required PartyRole replacementRole, required Map<String, dynamic> recruitment}) async {
    int? targetPartyIndex;
    final dealerClassesByParty = <int, List<String>>{};
    for (final item in known.docs) {
      final snapshot = await transaction.get(item.reference);
      if (!snapshot.exists) continue;
      final data = snapshot.data();
      final role = item.id == replacePlayerId ? replacementRole : _role(data?['role']);
      final className = item.id == replacePlayerId ? replacementClassName : data?['classNameSnapshot'];
      final partyIndex = data?['partyIndex'];
      if (role == null || className is! String || partyIndex is! int) return false;
      if (item.id == replacePlayerId) targetPartyIndex = partyIndex;
      if (role == PartyRole.dealer) dealerClassesByParty.putIfAbsent(partyIndex, () => []).add(className);
    }
    if (targetPartyIndex == null) return false;
    if (replacementRole == PartyRole.support) return true;
    final sameClassCount = dealerClassesByParty[targetPartyIndex]!.where((name) => name == replacementClassName).length;
    final classLimit = recruitment['maxDealersPerClassPerParty'] as int;
    return sameClassCount <= classLimit;
  }

  Future<PartyMembershipResult> _run(Future<PartyMembershipResult> Function(Transaction, String) action) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return const PartyMembershipResult.failure(PartyMembershipFailure.unauthenticated);
    try {
      return await _firestore.runTransaction((transaction) async {
        final binding = await transaction.get(_firestore.collection('authBindings').doc(uid));
        final data = binding.data();
        final playerId = data?['playerId'];
        if (data?['status'] != 'active' || playerId is! String || playerId.isEmpty) return const PartyMembershipResult.failure(PartyMembershipFailure.playerBindingMissing);
        return action(transaction, playerId);
      });
    } on FirebaseException catch (error) { return PartyMembershipResult.failure(_firebaseFailure(error.code)); } catch (_) { return const PartyMembershipResult.failure(PartyMembershipFailure.unknown); }
  }

  DocumentReference<Map<String, dynamic>> _assignment(String playerId, String characterId, String raidId) => _firestore.collection('players').doc(playerId).collection('activeRaidAssignments').doc('${characterId}_$raidId');
}

PartyMembershipFailure? _validateActive(Map<String, dynamic>? data, int revision) {
  if (data == null) return PartyMembershipFailure.notFound;
  if (data['revision'] != revision) return PartyMembershipFailure.revisionConflict;
  if (data['status'] != 'active') return PartyMembershipFailure.recruitmentClosed;
  return null;
}

PartyRole? _role(Object? value) => switch (value) { 'dealer' => PartyRole.dealer, 'support' => PartyRole.support, _ => null };
double? _itemLevel(Object? value) => value is num ? value.toDouble() : value is String ? double.tryParse(value.replaceAll(',', '').trim()) : null;
PartyMembershipFailure _firebaseFailure(String code) => switch (code) { 'permission-denied' => PartyMembershipFailure.permissionDenied, 'unavailable' || 'deadline-exceeded' || 'aborted' => PartyMembershipFailure.temporarilyUnavailable, _ => PartyMembershipFailure.unknown };
