import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../account/data/mappers/weekly_raid_claim_document_id.dart';
import '../../domain/entities/party_event.dart';
import '../../domain/entities/party_membership_command.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/repositories/party_membership_command_repository.dart';
import '../../domain/services/party_membership_command_validator.dart';
import '../mappers/party_membership_event_writer.dart';
import '../mappers/party_membership_write_plan.dart';
import '../mappers/party_raid_listing_sync.dart';

class FirestorePartyMembershipCommandRepository
    implements PartyMembershipCommandRepository {
  const FirestorePartyMembershipCommandRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<PartyMembershipResult> changeCharacter(
    PartyChangeCharacterCommand command,
  ) async {
    final invalid = const PartyMembershipCommandValidator().validateChange(
      command,
    );
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    if (_firebaseAuth.currentUser == null)
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.unauthenticated,
      );
    final knownMembers = await _members(command.recruitmentId);
    if (knownMembers == null)
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.temporarilyUnavailable,
      );
    return _run((transaction, playerId) async {
      final recruitmentRef = _firestore
          .collection('recruitments')
          .doc(command.recruitmentId);
      final memberRef = recruitmentRef.collection('members').doc(playerId);
      final recruitment = await transaction.get(recruitmentRef);
      final member = await transaction.get(memberRef);
      final r = recruitment.data();
      final m = member.data();
      final common = _validateActive(r, command.expectedRecruitmentRevision);
      if (common != null) return PartyMembershipResult.failure(common);
      if (!member.exists)
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.notFound,
        );
      final oldCharacterId = m?['characterId'];
      final oldRole = _role(m?['role']);
      final newRole = command.newRole;
      if (oldCharacterId == command.newCharacterId && oldRole == newRole)
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.alreadyCurrentCharacter,
        );
      if (oldCharacterId is! String || oldRole == null)
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.unknown,
        );
      // 반복 파티 완료 후 변경은 다음 회차 준비 구성이다. 이번 주 Claim·assignment는 건드리지 않는다.
      final isNextWeekPrep =
          r?['continueTogether'] == true &&
          r?['currentCycleStatus'] == 'completed';
      final characterRef = _firestore
          .collection('characters')
          .doc(command.newCharacterId);
      final oldAssignmentRef = _assignment(
        playerId,
        oldCharacterId,
        r?['raidId'] as String,
      );
      final newAssignmentRef = _assignment(
        playerId,
        command.newCharacterId,
        r?['raidId'] as String,
      );
      final character = await transaction.get(characterRef);
      final oldAssignment = await transaction.get(oldAssignmentRef);
      final newAssignment = await transaction.get(newAssignmentRef);
      final claim = isNextWeekPrep
          ? null
          : await transaction.get(
              _firestore
                  .collection('players')
                  .doc(playerId)
                  .collection('weeklyRaidClaims')
                  .doc(
                    WeeklyRaidClaimDocumentId.create(
                      cycleKey: r?['currentCycleKey'] as String,
                      characterId: command.newCharacterId,
                      raidId: r?['raidId'] as String,
                    ),
                  ),
            );
      final c = character.data();
      if (!character.exists || c?['status'] != 'active')
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidCharacter,
        );
      if (c?['ownerPlayerId'] != playerId)
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.ownershipLost,
        );
      if (isNextWeekPrep) {
        // 완료 후 assignment는 이미 없다. 남은 orphan만 정리하고 새로 만들지 않는다.
        if (oldAssignmentRef.path != newAssignmentRef.path &&
            newAssignment.exists) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.participationConflict,
          );
        }
      } else {
        if (!oldAssignment.exists) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.notFound,
          );
        }
        if (oldAssignmentRef.path != newAssignmentRef.path &&
            newAssignment.exists) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.participationConflict,
          );
        }
        if (claim != null && claim.exists) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.weeklyRaidCompleted,
          );
        }
      }
      final itemLevel = _itemLevel(c?['itemAvgLevel']);
      final name = c?['characterName'];
      final className = c?['characterClassName'];
      if (itemLevel == null ||
          itemLevel < (r?['minItemLevel'] as num? ?? double.infinity) ||
          name is! String ||
          className is! String)
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidCharacter,
        );
      final replacementPlan = await _replacementPlan(
        transaction,
        knownMembers,
        replacePlayerId: playerId,
        replacementClassName: className,
        replacementRole: newRole,
        recruitment: r!,
      );
      if (replacementPlan == null || !replacementPlan.canChange)
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidComposition,
        );
      final destination = replacementPlan.destination;
      if (destination != null && r['slotLedgerVersion'] != 1) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.unsupportedOnSpark,
        );
      }
      final previousCharacterName = m?['characterNameSnapshot'];
      if (previousCharacterName is! String) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.unknown,
        );
      }
      final listing = await PartyRaidListingTx.read(
        transaction: transaction,
        firestore: _firestore,
        groupId: r['groupId'],
        recruitmentId: command.recruitmentId,
      );
      final now = FieldValue.serverTimestamp();
      final nextRevision = command.expectedRecruitmentRevision + 1;
      final beforeMembers = List<String>.from(r['memberPlayerIds'] as List);
      final oldDealerCount = r['dealerCount'] as int;
      final oldSupportCount = r['supportCount'] as int;
      final dealerCount =
          oldDealerCount +
          (newRole == PartyRole.dealer ? 1 : 0) -
          (oldRole == PartyRole.dealer ? 1 : 0);
      final supportCount =
          oldSupportCount +
          (newRole == PartyRole.support ? 1 : 0) -
          (oldRole == PartyRole.support ? 1 : 0);
      final oldPartyIndex = m?['partyIndex'];
      final oldSlotIndex = m?['slotIndex'];
      if (destination != null &&
          (oldPartyIndex is! int || oldSlotIndex is! int)) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidComposition,
        );
      }
      transaction.update(
        memberRef,
        PartyMembershipWritePlan.changeCharacter(
          characterId: command.newCharacterId,
          characterName: name,
          className: className,
          role: newRole.name,
          itemLevel: itemLevel,
          combatPower: command.combatPower,
          gemValidation: command.gemValidation,
          buildIntegrity: command.buildIntegrity,
          partyIndex: destination?.partyIndex,
          slotIndex: destination?.slotIndex,
          serverTimestamp: now,
        ),
      );
      if (destination != null) {
        transaction.delete(
          recruitmentRef
              .collection('slots')
              .doc('${oldPartyIndex as int}_${oldSlotIndex as int}'),
        );
        transaction.set(
          recruitmentRef.collection('slots').doc(destination.documentId),
          {
            'playerId': playerId,
            'partyIndex': destination.partyIndex,
            'slotIndex': destination.slotIndex,
            'role': newRole.name,
            'classNameSnapshot': className,
            'updatedAt': now,
          },
        );
      }
      if (isNextWeekPrep) {
        if (oldAssignment.exists) {
          transaction.delete(oldAssignmentRef);
        }
      } else if (oldAssignmentRef.path == newAssignmentRef.path) {
        transaction.update(oldAssignmentRef, {
          'role': newRole.name,
          'updatedAt': now,
        });
      } else {
        transaction.delete(oldAssignmentRef);
        transaction.set(newAssignmentRef, {
          ...oldAssignment.data()!,
          'characterId': command.newCharacterId,
          'role': newRole.name,
          'createdAt': now,
          'updatedAt': now,
        });
      }
      if (r['leaderPlayerId'] == playerId) {
        final patch = PartyMembershipWritePlan.leaderDisplaySnapshots(
          characterName: name,
          className: className,
          revision: command.expectedRecruitmentRevision,
          serverTimestamp: now,
          dealerCount: dealerCount,
          supportCount: supportCount,
        );
        transaction.update(recruitmentRef, patch);
        listing.write(
          transaction: transaction,
          currentRecruitment: partyRecruitmentMap(r),
          recruitmentPatch: patch,
        );
      } else {
        final patch = <String, Object?>{
          'dealerCount': dealerCount,
          'supportCount': supportCount,
          'revision': nextRevision,
          'updatedAt': now,
        };
        transaction.update(recruitmentRef, patch);
        listing.write(
          transaction: transaction,
          currentRecruitment: partyRecruitmentMap(r),
          recruitmentPatch: patch,
        );
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
        role: newRole.name,
        previousCharacterNameSnapshot: previousCharacterName,
        raidId: r['raidId'] is String ? r['raidId'] as String : null,
        difficultyId: r['difficultyId'] is String
            ? r['difficultyId'] as String
            : null,
        partyIndex:
            destination?.partyIndex ??
            (m?['partyIndex'] is int ? m!['partyIndex'] as int : null),
        slotIndex:
            destination?.slotIndex ??
            (m?['slotIndex'] is int ? m!['slotIndex'] as int : null),
        previousPartyIndex: destination == null ? null : oldPartyIndex as int,
        previousSlotIndex: destination == null ? null : oldSlotIndex as int,
        serverTimestamp: now,
      );
      return const PartyMembershipResult.success();
    });
  }

  @override
  Future<PartyMembershipResult> leave(PartyRemoveMemberCommand command) async {
    final invalid = const PartyMembershipCommandValidator().validateRemove(
      command,
    );
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    return _remove(command, mode: _PartyRemoveMode.leave);
  }

  @override
  Future<PartyMembershipResult> kick(PartyRemoveMemberCommand command) async {
    final invalid = const PartyMembershipCommandValidator().validateRemove(
      command,
    );
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    return _remove(command, mode: _PartyRemoveMode.kick);
  }

  @override
  Future<PartyMembershipResult> removeLostGroupQualification(
    PartyRemoveMemberCommand command,
  ) async {
    final invalid = const PartyMembershipCommandValidator().validateRemove(
      command,
    );
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    return _remove(command, mode: _PartyRemoveMode.lostGroupQualification);
  }

  Future<PartyMembershipResult> _remove(
    PartyRemoveMemberCommand command, {
    required _PartyRemoveMode mode,
  }) async {
    return _run((transaction, actorPlayerId) async {
      final recruitmentRef = _firestore
          .collection('recruitments')
          .doc(command.recruitmentId);
      final targetRef = recruitmentRef
          .collection('members')
          .doc(command.targetPlayerId);
      final recruitment = await transaction.get(recruitmentRef);
      final target = await transaction.get(targetRef);
      final r = recruitment.data();
      final m = target.data();
      final common = _validateActive(r, command.expectedRecruitmentRevision);
      if (common != null) return PartyMembershipResult.failure(common);
      if (!target.exists)
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.notFound,
        );
      if (mode == _PartyRemoveMode.lostGroupQualification) {
        final groupId = r?['groupId'];
        if (r?['visibility'] != 'group' ||
            groupId is! String ||
            groupId.isEmpty) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.unauthorized,
          );
        }
        if (command.targetPlayerId == actorPlayerId) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.unauthorized,
          );
        }
        final actorRaidMember = await transaction.get(
          recruitmentRef.collection('members').doc(actorPlayerId),
        );
        final actorGroupMember = await transaction.get(
          _firestore
              .collection('groups')
              .doc(groupId)
              .collection('members')
              .doc(actorPlayerId),
        );
        final targetGroupMember = await transaction.get(
          _firestore
              .collection('groups')
              .doc(groupId)
              .collection('members')
              .doc(command.targetPlayerId),
        );
        if (!actorRaidMember.exists ||
            !actorGroupMember.exists ||
            targetGroupMember.exists) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.unauthorized,
          );
        }
      } else {
        final unauthorized = mode == _PartyRemoveMode.kick
            ? (r?['leaderPlayerId'] != actorPlayerId ||
                  command.targetPlayerId == actorPlayerId)
            : command.targetPlayerId != actorPlayerId;
        if (unauthorized) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.unauthorized,
          );
        }
      }
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
      final listing = await PartyRaidListingTx.read(
        transaction: transaction,
        firestore: _firestore,
        groupId: r?['groupId'],
        recruitmentId: command.recruitmentId,
      );
      final recruitmentPatch = PartyMembershipWritePlan.removeFromRecruitment(
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
      );
      transaction.update(recruitmentRef, recruitmentPatch);
      listing.write(
        transaction: transaction,
        currentRecruitment: partyRecruitmentMap(r),
        recruitmentPatch: recruitmentPatch,
      );
      transaction.delete(targetRef);
      final targetPartyIndex = m?['partyIndex'];
      final targetSlotIndex = m?['slotIndex'];
      if (r?['slotLedgerVersion'] == 1 &&
          targetPartyIndex is int &&
          targetSlotIndex is int) {
        transaction.delete(
          recruitmentRef
              .collection('slots')
              .doc('${targetPartyIndex}_$targetSlotIndex'),
        );
      }
      transaction.delete(
        _assignment(
          command.targetPlayerId,
          characterId,
          r?['raidId'] as String,
        ),
      );
      if (nextLeader != null &&
          nextLeader != oldLeader &&
          mode != _PartyRemoveMode.lostGroupQualification) {
        transaction.update(
          recruitmentRef.collection('members').doc(nextLeader),
          {'canApproveApplications': true, 'updatedAt': now},
        );
      }
      final raidId = r?['raidId'] is String ? r!['raidId'] as String : null;
      final difficultyId = r?['difficultyId'] is String
          ? r!['difficultyId'] as String
          : null;
      final className = m?['classNameSnapshot'] is String
          ? m!['classNameSnapshot'] as String
          : null;
      final partyIndex = m?['partyIndex'] is int
          ? m!['partyIndex'] as int
          : null;
      final slotIndex = m?['slotIndex'] is int ? m!['slotIndex'] as int : null;
      if (mode == _PartyRemoveMode.leave) {
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
      } else {
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
      }
      return const PartyMembershipResult.success();
    });
  }

  @override
  Future<PartyMembershipResult> setApprovalPermission(
    PartySetApprovalPermissionCommand command,
  ) async {
    final invalid = const PartyMembershipCommandValidator().validatePermission(
      command,
    );
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    return _run((transaction, actorPlayerId) async {
      final recruitmentRef = _firestore
          .collection('recruitments')
          .doc(command.recruitmentId);
      final targetRef = recruitmentRef
          .collection('members')
          .doc(command.targetPlayerId);
      final recruitment = await transaction.get(recruitmentRef);
      final target = await transaction.get(targetRef);
      final r = recruitment.data();
      final common = _validateActive(r, command.expectedRecruitmentRevision);
      if (common != null) return PartyMembershipResult.failure(common);
      if (r?['leaderPlayerId'] != actorPlayerId ||
          command.targetPlayerId == actorPlayerId)
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.unauthorized,
        );
      if (!target.exists)
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.notFound,
        );
      final now = FieldValue.serverTimestamp();
      transaction.update(
        targetRef,
        PartyMembershipWritePlan.setApprovalPermission(
          enabled: command.enabled,
          serverTimestamp: now,
        ),
      );
      transaction.update(recruitmentRef, {
        'revision': command.expectedRecruitmentRevision + 1,
        'updatedAt': now,
      });
      return const PartyMembershipResult.success();
    });
  }

  @override
  Future<PartyMembershipResult> repositionMembers(
    PartyRepositionMembersCommand command,
  ) async {
    final invalid = const PartyMembershipCommandValidator().validateReposition(
      command,
    );
    if (invalid != null) return PartyMembershipResult.failure(invalid);
    final knownMembers = await _members(command.recruitmentId);
    if (knownMembers == null) {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.temporarilyUnavailable,
      );
    }
    return _run((transaction, actorPlayerId) async {
      final recruitmentRef = _firestore
          .collection('recruitments')
          .doc(command.recruitmentId);
      final recruitmentSnapshot = await transaction.get(recruitmentRef);
      final recruitment = recruitmentSnapshot.data();
      final common = _validateActive(
        recruitment,
        command.expectedRecruitmentRevision,
      );
      if (common != null) return PartyMembershipResult.failure(common);
      if (recruitment?['leaderPlayerId'] != actorPlayerId) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.unauthorized,
        );
      }
      if (recruitment?['slotLedgerVersion'] != 1) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.unsupportedOnSpark,
        );
      }
      if (command.sourcePlayerId == actorPlayerId ||
          (command.destinationPartyIndex == 0 &&
              command.destinationSlotIndex == 0)) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidRequest,
        );
      }
      final partyCount = recruitment?['partyCount'];
      final membersPerParty = recruitment?['membersPerParty'];
      final supportsPerParty = recruitment?['supportsPerParty'];
      final classLimit = recruitment?['maxDealersPerClassPerParty'];
      if (partyCount is! int ||
          membersPerParty is! int ||
          supportsPerParty is! int ||
          classLimit is! int ||
          command.destinationPartyIndex >= partyCount ||
          command.destinationSlotIndex >= membersPerParty) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidRequest,
        );
      }

      final memberData = <String, Map<String, dynamic>>{};
      for (final known in knownMembers.docs) {
        final snapshot = await transaction.get(known.reference);
        final data = snapshot.data();
        if (snapshot.exists && data != null) memberData[known.id] = data;
      }
      final source = memberData[command.sourcePlayerId];
      if (source == null) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.notFound,
        );
      }
      final sourcePartyIndex = source['partyIndex'];
      final sourceSlotIndex = source['slotIndex'];
      if (sourcePartyIndex is! int || sourceSlotIndex is! int) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidComposition,
        );
      }
      if (sourcePartyIndex == command.destinationPartyIndex &&
          sourceSlotIndex == command.destinationSlotIndex) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidRequest,
        );
      }
      String? destinationPlayerId;
      for (final entry in memberData.entries) {
        if (entry.value['partyIndex'] == command.destinationPartyIndex &&
            entry.value['slotIndex'] == command.destinationSlotIndex) {
          destinationPlayerId = entry.key;
          break;
        }
      }

      final occupied = <OccupiedPartyMember>[];
      for (final entry in memberData.entries) {
        final data = entry.value;
        final role = _role(data['role']);
        final className = data['classNameSnapshot'];
        final currentParty = data['partyIndex'];
        final currentSlot = data['slotIndex'];
        if (role == null ||
            className is! String ||
            currentParty is! int ||
            currentSlot is! int) {
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.invalidComposition,
          );
        }
        final isSource = entry.key == command.sourcePlayerId;
        final isDestination = entry.key == destinationPlayerId;
        occupied.add(
          OccupiedPartyMember(
            id: entry.key,
            className: className,
            role: role,
            partyIndex: isSource
                ? command.destinationPartyIndex
                : isDestination
                ? sourcePartyIndex
                : currentParty,
            slotIndex: isSource
                ? command.destinationSlotIndex
                : isDestination
                ? sourceSlotIndex
                : currentSlot,
            isLeader: entry.key == actorPlayerId,
          ),
        );
      }
      final policy = PartyCompositionPolicy(
        RecruitmentPartyRules(
          partyCount: partyCount,
          membersPerParty: membersPerParty,
          supportsPerParty: supportsPerParty,
          maxDealersPerClassPerParty: classLimit,
        ),
      );
      if (policy.failureForArrangement(occupied) != null) {
        return const PartyMembershipResult.failure(
          PartyMembershipFailure.invalidComposition,
        );
      }
      final listing = await PartyRaidListingTx.read(
        transaction: transaction,
        firestore: _firestore,
        groupId: recruitment?['groupId'],
        recruitmentId: command.recruitmentId,
      );
      final now = FieldValue.serverTimestamp();
      final nextRevision = command.expectedRecruitmentRevision + 1;
      final patch = <String, Object?>{
        'revision': nextRevision,
        'updatedAt': now,
      };
      transaction.update(recruitmentRef, patch);
      listing.write(
        transaction: transaction,
        currentRecruitment: partyRecruitmentMap(recruitment),
        recruitmentPatch: patch,
      );
      transaction.update(
        recruitmentRef.collection('members').doc(command.sourcePlayerId),
        {
          'partyIndex': command.destinationPartyIndex,
          'slotIndex': command.destinationSlotIndex,
          'updatedAt': now,
        },
      );
      final sourceSlotRef = recruitmentRef
          .collection('slots')
          .doc('${sourcePartyIndex}_$sourceSlotIndex');
      final destinationSlotRef = recruitmentRef
          .collection('slots')
          .doc(
            '${command.destinationPartyIndex}_${command.destinationSlotIndex}',
          );
      if (destinationPlayerId == null) {
        transaction.delete(sourceSlotRef);
        transaction.set(destinationSlotRef, {
          'playerId': command.sourcePlayerId,
          'partyIndex': command.destinationPartyIndex,
          'slotIndex': command.destinationSlotIndex,
          'role': source['role'],
          'classNameSnapshot': source['classNameSnapshot'],
          'updatedAt': now,
        });
      } else {
        transaction.update(
          recruitmentRef.collection('members').doc(destinationPlayerId),
          {
            'partyIndex': sourcePartyIndex,
            'slotIndex': sourceSlotIndex,
            'updatedAt': now,
          },
        );
        transaction.update(sourceSlotRef, {
          'playerId': destinationPlayerId,
          'role': memberData[destinationPlayerId]!['role'],
          'classNameSnapshot':
              memberData[destinationPlayerId]!['classNameSnapshot'],
          'updatedAt': now,
        });
        transaction.update(destinationSlotRef, {
          'playerId': command.sourcePlayerId,
          'role': source['role'],
          'classNameSnapshot': source['classNameSnapshot'],
          'updatedAt': now,
        });
      }
      final recipients = List<String>.from(
        recruitment?['memberPlayerIds'] as List,
      );
      PartyMembershipEventWriter.writeToRecipients(
        transaction: transaction,
        firestore: _firestore,
        type: PartyEventType.memberMoved,
        recipientPlayerIds: recipients,
        recruitmentId: command.recruitmentId,
        recruitmentRevision: nextRevision,
        actorPlayerId: actorPlayerId,
        targetPlayerId: command.sourcePlayerId,
        characterNameSnapshot: source['characterNameSnapshot'] as String?,
        classNameSnapshot: source['classNameSnapshot'] as String?,
        role: source['role'] as String?,
        partyIndex: command.destinationPartyIndex,
        slotIndex: command.destinationSlotIndex,
        previousPartyIndex: sourcePartyIndex,
        previousSlotIndex: sourceSlotIndex,
        serverTimestamp: now,
      );
      if (destinationPlayerId != null) {
        final destination = memberData[destinationPlayerId]!;
        PartyMembershipEventWriter.writeToRecipients(
          transaction: transaction,
          firestore: _firestore,
          type: PartyEventType.memberMoved,
          recipientPlayerIds: recipients,
          recruitmentId: command.recruitmentId,
          recruitmentRevision: nextRevision,
          actorPlayerId: actorPlayerId,
          targetPlayerId: destinationPlayerId,
          characterNameSnapshot:
              destination['characterNameSnapshot'] as String?,
          classNameSnapshot: destination['classNameSnapshot'] as String?,
          role: destination['role'] as String?,
          partyIndex: sourcePartyIndex,
          slotIndex: sourceSlotIndex,
          previousPartyIndex: command.destinationPartyIndex,
          previousSlotIndex: command.destinationSlotIndex,
          serverTimestamp: now,
        );
      }
      return const PartyMembershipResult.success();
    });
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _members(
    String recruitmentId,
  ) async {
    if (_firebaseAuth.currentUser == null) return null;
    try {
      return await _firestore
          .collection('recruitments')
          .doc(recruitmentId)
          .collection('members')
          .get();
    } on FirebaseException {
      return null;
    }
  }

  Future<PartyReplacementPlan?> _replacementPlan(
    Transaction transaction,
    QuerySnapshot<Map<String, dynamic>> known, {
    required String replacePlayerId,
    required String replacementClassName,
    required PartyRole replacementRole,
    required Map<String, dynamic> recruitment,
  }) async {
    final occupied = <OccupiedPartyMember>[];
    for (final item in known.docs) {
      final snapshot = await transaction.get(item.reference);
      if (!snapshot.exists) continue;
      final data = snapshot.data();
      final role = _role(data?['role']);
      final className = data?['classNameSnapshot'];
      final partyIndex = data?['partyIndex'];
      final slotIndex = data?['slotIndex'];
      if (role == null || className is! String || partyIndex is! int) {
        return null;
      }
      occupied.add(
        OccupiedPartyMember(
          id: item.id,
          className: className,
          role: role,
          partyIndex: partyIndex,
          slotIndex: slotIndex is int ? slotIndex : null,
          isLeader: recruitment['leaderPlayerId'] == item.id,
        ),
      );
    }
    final partyCount = recruitment['partyCount'];
    final membersPerParty = recruitment['membersPerParty'];
    final supportsPerParty = recruitment['supportsPerParty'];
    final classLimit = recruitment['maxDealersPerClassPerParty'];
    if (partyCount is! int ||
        membersPerParty is! int ||
        supportsPerParty is! int ||
        classLimit is! int) {
      return null;
    }
    return PartyCompositionPolicy(
      RecruitmentPartyRules(
        partyCount: partyCount,
        membersPerParty: membersPerParty,
        supportsPerParty: supportsPerParty,
        maxDealersPerClassPerParty: classLimit,
      ),
    ).planReplacement(
      replaceMemberId: replacePlayerId,
      className: replacementClassName,
      role: replacementRole,
      existing: occupied,
    );
  }

  Future<PartyMembershipResult> _run(
    Future<PartyMembershipResult> Function(Transaction, String) action,
  ) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null)
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.unauthenticated,
      );
    try {
      return await _firestore.runTransaction((transaction) async {
        final binding = await transaction.get(
          _firestore.collection('authBindings').doc(uid),
        );
        final data = binding.data();
        final playerId = data?['playerId'];
        if (data?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty)
          return const PartyMembershipResult.failure(
            PartyMembershipFailure.playerBindingMissing,
          );
        return action(transaction, playerId);
      });
    } on FirebaseException catch (error) {
      return PartyMembershipResult.failure(_firebaseFailure(error.code));
    } catch (_) {
      return const PartyMembershipResult.failure(
        PartyMembershipFailure.unknown,
      );
    }
  }

  DocumentReference<Map<String, dynamic>> _assignment(
    String playerId,
    String characterId,
    String raidId,
  ) => _firestore
      .collection('players')
      .doc(playerId)
      .collection('activeRaidAssignments')
      .doc('${characterId}_$raidId');
}

PartyMembershipFailure? _validateActive(
  Map<String, dynamic>? data,
  int revision,
) {
  if (data == null) return PartyMembershipFailure.notFound;
  if (data['revision'] != revision)
    return PartyMembershipFailure.revisionConflict;
  if (data['status'] != 'active')
    return PartyMembershipFailure.recruitmentClosed;
  return null;
}

PartyRole? _role(Object? value) => switch (value) {
  'dealer' => PartyRole.dealer,
  'support' => PartyRole.support,
  _ => null,
};
double? _itemLevel(Object? value) => value is num
    ? value.toDouble()
    : value is String
    ? double.tryParse(value.replaceAll(',', '').trim())
    : null;
PartyMembershipFailure _firebaseFailure(String code) => switch (code) {
  'permission-denied' => PartyMembershipFailure.permissionDenied,
  'unavailable' ||
  'deadline-exceeded' ||
  'aborted' => PartyMembershipFailure.temporarilyUnavailable,
  _ => PartyMembershipFailure.unknown,
};

enum _PartyRemoveMode { leave, kick, lostGroupQualification }
