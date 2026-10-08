import '../../../recruitment_list/data/mappers/party_raid_listing_document.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../recruitment_list/data/mappers/raid_state_availability.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../recruitment_list/data/mappers/party_atomic_document_mapper.dart';
import '../../../recruitment_list/data/mappers/party_atomic_member_removal_write_plan.dart';
import '../../../recruitment_list/domain/entities/party_atomic_command.dart';
import '../../../recruitment_list/domain/policies/party_composition_policy.dart';
import '../../../recruitment_list/domain/services/party_create_occupancy_gate.dart';
import '../../../recruitment_list/domain/services/party_ownership_record_policy.dart';
import '../../domain/game_account_ownership_snapshot.dart';
import '../../domain/entities/weekly_raid_claim_command.dart';
import '../../domain/repositories/weekly_raid_claim_command_repository.dart';
import '../mappers/weekly_raid_claim_document_id.dart';

/// `raidStates`를 신규 주간 레이드 원장으로 사용하는 개인 완료 명령.
///
/// 구 Claim/assignment는 읽기·해제 호환에만 사용하며 신규 완료에는
/// dual-write하지 않는다. 활성 파티에서 완료할 때는 탈퇴/승계 또는 마지막
/// 1인 해산과 본인 state 전환을 같은 Transaction으로 확정한다.
class FirestoreWeeklyRaidStatusCommandRepository
    implements WeeklyRaidClaimCommandRepository {
  const FirestoreWeeklyRaidStatusCommandRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    this.clock = DateTime.now,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final DateTime Function() clock;

  @override
  Future<WeeklyRaidClaimImpactResult> inspectManualClaimImpact(
    CreateManualWeeklyRaidClaimCommand command,
  ) async {
    if (_firebaseAuth.currentUser == null) {
      return const WeeklyRaidClaimImpactResult.failure(
        WeeklyRaidClaimCommandFailure.unauthenticated,
      );
    }
    if (!_validCreate(command)) {
      return const WeeklyRaidClaimImpactResult.failure(
        WeeklyRaidClaimCommandFailure.invalidRequest,
      );
    }
    try {
      final context = await _loadContext(command);
      return WeeklyRaidClaimImpactResult.success(context.impact);
    } on _WeeklyRaidStateContractException {
      return const WeeklyRaidClaimImpactResult.failure(
        WeeklyRaidClaimCommandFailure.stateInconsistent,
      );
    } on FirebaseException catch (error) {
      return WeeklyRaidClaimImpactResult.failure(_failure(error.code));
    } catch (_) {
      return const WeeklyRaidClaimImpactResult.failure(
        WeeklyRaidClaimCommandFailure.unknown,
      );
    }
  }

  @override
  Future<WeeklyRaidClaimCommandResult> createManualClaim(
    CreateManualWeeklyRaidClaimCommand command, {
    bool resolveConflicts = false,
  }) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unauthenticated,
      );
    }
    if (!_validCreate(command)) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.invalidRequest,
      );
    }

    try {
      final context = await _loadContext(command);
      if (context.impact.hasOrphanedParticipation) {
        return const WeeklyRaidClaimCommandResult.failure(
          WeeklyRaidClaimCommandFailure.orphanedParticipation,
        );
      }
      if (context.impact.requiresConfirmation && !resolveConflicts) {
        return WeeklyRaidClaimCommandResult.failure(
          context.impact.hasActiveRecruitment
              ? WeeklyRaidClaimCommandFailure.activeAssignment
              : WeeklyRaidClaimCommandFailure.pendingApplication,
        );
      }

      WeeklyRaidClaimCommandResult? result;
      for (var attempt = 0; attempt < 2; attempt += 1) {
        final outcome = await _firestore.runTransaction((transaction) async {
          final playerId = await _boundPlayerId(transaction, uid);
          if (playerId == null) {
            return const _ManualClaimTransactionOutcome.result(
              WeeklyRaidClaimCommandResult.failure(
                WeeklyRaidClaimCommandFailure.unauthenticated,
              ),
            );
          }
          if (playerId != command.playerId) {
            return const _ManualClaimTransactionOutcome.result(
              WeeklyRaidClaimCommandResult.failure(
                WeeklyRaidClaimCommandFailure.invalidRequest,
              ),
            );
          }

          final stateRef = _state(
            command.playerId,
            command.characterId,
            command.raidId,
          );
          final claimRef = _claim(command);
          final assignmentRef = _assignment(
            command.playerId,
            command.characterId,
            command.raidId,
          );
          final state = await transaction.get(stateRef);
          final claim = await transaction.get(claimRef);
          final assignment = await transaction.get(assignmentRef);
          final ownership = await _ownership(
            command.playerId,
            command.characterId,
            transaction,
          );
          _validateObservation(
            command.observation,
            playerId: command.playerId,
            characterId: command.characterId,
            raidId: command.raidId,
            cycleKey: command.cycleKey,
            ownership: ownership,
            state: state.data(),
            claim: claim.data(),
            assignment: assignment.data(),
            afterHistoricalDelete: attempt > 0,
          );
          final stateData = _currentRecord(
            ownership,
            state.data(),
            command.playerId,
            command.characterId,
            command.raidId,
            isState: true,
          );
          final claimData = _currentRecord(
            ownership,
            claim.data(),
            command.playerId,
            command.characterId,
            command.raidId,
            cycleKey: command.cycleKey,
          );
          final assignmentData = _currentRecord(
            ownership,
            assignment.data(),
            command.playerId,
            command.characterId,
            command.raidId,
          );

          if (stateData != null) {
            _validateStateIdentity(command, stateData);
            final stateCycleKey = stateData['cycleKey'] as String;
            if (stateCycleKey != command.cycleKey) {
              if (stateData['status'] != 'completed' ||
                  assignmentData != null) {
                return const _ManualClaimTransactionOutcome.result(
                  WeeklyRaidClaimCommandResult.failure(
                    WeeklyRaidClaimCommandFailure.stateInconsistent,
                  ),
                );
              }
              transaction.delete(stateRef);
              return const _ManualClaimTransactionOutcome.retryAfterRollover();
            }
            if (stateData['status'] == 'completed') {
              return const _ManualClaimTransactionOutcome.result(
                WeeklyRaidClaimCommandResult.success(),
              );
            }
            if (stateData['status'] != 'active' || !resolveConflicts) {
              return const _ManualClaimTransactionOutcome.result(
                WeeklyRaidClaimCommandResult.failure(
                  WeeklyRaidClaimCommandFailure.activeAssignment,
                ),
              );
            }
            return _ManualClaimTransactionOutcome.result(
              await _completeActiveState(
                transaction: transaction,
                command: command,
                stateRef: stateRef,
                stateData: stateData,
                assignmentRef: assignmentRef,
                assignmentData: assignmentData,
              ),
            );
          }

          if (assignmentData != null) {
            return const _ManualClaimTransactionOutcome.result(
              WeeklyRaidClaimCommandResult.failure(
                WeeklyRaidClaimCommandFailure.stateInconsistent,
              ),
            );
          }
          if (claimData != null) {
            return const _ManualClaimTransactionOutcome.result(
              WeeklyRaidClaimCommandResult.success(),
            );
          }

          final now = FieldValue.serverTimestamp();
          transaction.set(stateRef, {
            'ownershipRevision': ownership.revision,
            'schemaVersion': 1,
            'playerId': command.playerId,
            'characterId': command.characterId,
            'raidId': command.raidId,
            'difficultyId': command.difficultyId,
            'cycleKey': command.cycleKey,
            'status': 'completed',
            'source': 'manual',
            'recruitmentId': null,
            'revision': 1,
            'cycleStartedAt': Timestamp.fromDate(
              command.cycleStartedAt.toUtc(),
            ),
            'cycleEndsAt': Timestamp.fromDate(command.cycleEndsAt.toUtc()),
            'completedAt': now,
            'updatedAt': now,
          });
          return const _ManualClaimTransactionOutcome.result(
            WeeklyRaidClaimCommandResult.success(),
          );
        });
        if (outcome.shouldRetryAfterRollover) continue;
        result = outcome.commandResult;
        break;
      }
      result ??= const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.temporarilyUnavailable,
      );

      if (result.isSuccess && resolveConflicts) {
        unawaited(
          _supersedePendingApplications(context.pendingApplications, command),
        );
      }
      return result;
    } on _WeeklyRaidStateContractException {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.stateInconsistent,
      );
    } on FirebaseException catch (error) {
      return WeeklyRaidClaimCommandResult.failure(_failure(error.code));
    } catch (_) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unknown,
      );
    }
  }

  @override
  Future<WeeklyRaidClaimCommandResult> cleanupOrphanParticipation(
    CleanupOrphanRaidParticipationCommand command,
  ) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unauthenticated,
      );
    }
    if (!_validCleanup(command)) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.invalidRequest,
      );
    }
    try {
      return await _firestore.runTransaction((transaction) async {
        final playerId = await _boundPlayerId(transaction, uid);
        if (playerId != command.playerId) {
          return const WeeklyRaidClaimCommandResult.failure(
            WeeklyRaidClaimCommandFailure.invalidRequest,
          );
        }
        final stateRef = _state(
          command.playerId,
          command.characterId,
          command.raidId,
        );
        final assignmentRef = _assignment(
          command.playerId,
          command.characterId,
          command.raidId,
        );
        final recruitmentRef = _firestore
            .collection('recruitments')
            .doc(command.recruitmentId);
        final state = await transaction.get(stateRef);
        final assignment = await transaction.get(assignmentRef);
        final recruitment = await transaction.get(recruitmentRef);
        final stateData = state.data();
        final assignmentData = assignment.data();
        final ownership = await _ownership(
          command.playerId,
          command.characterId,
          transaction,
        );
        if (command.observation?.matchesCleanup(
              playerId: command.playerId,
              characterId: command.characterId,
              raidId: command.raidId,
              ownershipRevision: ownership.revision!,
              state: stateData,
              assignment: assignmentData,
            ) !=
            true) {
          throw const _WeeklyRaidStateContractException();
        }
        if (stateData == null && assignmentData == null) {
          return const WeeklyRaidClaimCommandResult.success();
        }
        if (stateData != null) {
          _validateOrphanState(command, stateData);
          if (_currentRecord(
                ownership,
                stateData,
                command.playerId,
                command.characterId,
                command.raidId,
                isState: true,
              ) ==
              null) {
            throw const _WeeklyRaidStateContractException();
          }
        }
        if (assignmentData != null) {
          _validateOrphanAssignment(command, assignmentData);
          if (_currentRecord(
                ownership,
                assignmentData,
                command.playerId,
                command.characterId,
                command.raidId,
                cycleKey: command.cycleKey,
              ) ==
              null) {
            throw const _WeeklyRaidStateContractException();
          }
        }
        final recruitmentData = recruitment.data();
        if (recruitmentData != null &&
            recruitmentData['raidId'] != command.raidId) {
          throw const _WeeklyRaidStateContractException();
        }
        final occupancy = _classifyActiveOccupancy(
          observedCycleKey: command.cycleKey,
          requestedCycleKey: command.cycleKey,
          recruitment: recruitmentData,
        );
        if (occupancy !=
            ExistingRaidStateOccupancyDecision.currentOrphanActive) {
          return const WeeklyRaidClaimCommandResult.failure(
            WeeklyRaidClaimCommandFailure.activeAssignment,
          );
        }
        if (stateData != null) transaction.delete(stateRef);
        if (assignmentData != null) transaction.delete(assignmentRef);
        return const WeeklyRaidClaimCommandResult.success();
      });
    } on _WeeklyRaidStateContractException {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.stateInconsistent,
      );
    } on FirebaseException catch (error) {
      return WeeklyRaidClaimCommandResult.failure(_failure(error.code));
    } catch (_) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unknown,
      );
    }
  }

  Future<WeeklyRaidClaimCommandResult> _completeActiveState({
    required Transaction transaction,
    required CreateManualWeeklyRaidClaimCommand command,
    required DocumentReference<Map<String, dynamic>> stateRef,
    required Map<String, dynamic> stateData,
    required DocumentReference<Map<String, dynamic>> assignmentRef,
    required Map<String, dynamic>? assignmentData,
  }) async {
    final recruitmentId = stateData['recruitmentId'];
    if (recruitmentId is! String || recruitmentId.isEmpty) {
      throw const _WeeklyRaidStateContractException();
    }
    if (assignmentData != null &&
        (assignmentData['playerId'] != command.playerId ||
            assignmentData['characterId'] != command.characterId ||
            assignmentData['raidId'] != command.raidId ||
            assignmentData['cycleKey'] != command.cycleKey ||
            assignmentData['recruitmentId'] != recruitmentId ||
            assignmentData['status'] != 'active')) {
      throw const _WeeklyRaidStateContractException();
    }
    final recruitmentRef = _firestore
        .collection('recruitments')
        .doc(recruitmentId);
    final memberRef = recruitmentRef
        .collection('members')
        .doc(command.playerId);
    final recruitment = await transaction.get(recruitmentRef);
    final membership = await transaction.get(memberRef);
    final raw = recruitment.data();
    final memberData = membership.data();
    if (raw == null ||
        memberData == null ||
        raw['schemaVersion'] != 2 ||
        raw['status'] != 'active' ||
        raw['currentCycleStatus'] != 'active' ||
        raw['raidId'] != command.raidId ||
        raw['currentCycleKey'] != command.cycleKey ||
        memberData['characterId'] != command.characterId ||
        raw['revision'] != command.observation?.recruitmentRevision ||
        (memberData.containsKey('ownershipRevision')
                ? memberData['ownershipRevision']
                : 0) !=
            command.observation?.ownershipRevision) {
      throw const _WeeklyRaidStateContractException();
    }

    final aggregate = PartyAtomicDocumentMapper.aggregate(
      Map<String, Object?>.from(raw),
    );
    final target = aggregate.partySlots
        .where((slot) => slot.playerId == command.playerId)
        .firstOrNull;
    if (target == null ||
        target.characterId != command.characterId ||
        (target.ownershipRevision ?? 0) !=
            command.observation?.ownershipRevision) {
      throw const _WeeklyRaidStateContractException();
    }

    PartyLeaderSuccessorSnapshot? successorSnapshot;
    DocumentReference<Map<String, dynamic>>? successorRef;
    if (aggregate.leaderPlayerId == command.playerId &&
        aggregate.memberCount > 1) {
      final successor = aggregate.partySlots
          .where((slot) => slot.playerId != command.playerId)
          .first;
      successorRef = recruitmentRef
          .collection('members')
          .doc(successor.playerId);
      final successorDoc = await transaction.get(successorRef);
      final successorData = successorDoc.data();
      final successorOwnership = await _ownership(
        successor.playerId,
        successor.characterId,
        transaction,
      );
      if (successorData == null ||
          successorData['characterId'] != successor.characterId ||
          successorOwnership.classifyParticipation(successorData) !=
              GameAccountOwnershipCondition.current ||
          (successor.ownershipRevision ?? 0) != successorOwnership.revision) {
        throw const _WeeklyRaidStateContractException();
      }
      final characterName = successorData['characterNameSnapshot'];
      final className = successorData['classNameSnapshot'];
      if (characterName is! String || className is! String) {
        throw const _WeeklyRaidStateContractException();
      }
      successorSnapshot = PartyLeaderSuccessorSnapshot(
        playerId: successor.playerId,
        characterName: characterName,
        className: className,
      );
    }

    DocumentReference<Map<String, dynamic>>? groupRef;
    int? groupCountAfter;
    final groupId = aggregate.visibility == 'group' ? aggregate.groupId : null;
    if (aggregate.memberCount == 1 && groupId != null) {
      groupRef = _firestore.collection('groups').doc(groupId);
      final group = await transaction.get(groupRef);
      final count = group.data()?['activeRecruitmentCount'];
      if (count is! int || count <= 0) {
        throw const _WeeklyRaidStateContractException();
      }
      groupCountAfter = count - 1;
    }

    final now = FieldValue.serverTimestamp();
    final eventId =
        'memberLeft_${aggregate.recruitmentId}_${aggregate.revision + 1}';
    late final Map<String, Object?> recruitmentPatch;
    late final Map<String, Object?> event;
    if (aggregate.memberCount > 1) {
      final plan = PartyAtomicMemberRemovalWritePlan(
        aggregate: aggregate,
        rules: _rules(raw),
        targetPlayerId: command.playerId,
        actorPlayerId: command.playerId,
        type: PartyAtomicMemberRemovalType.leave,
        raidId: command.raidId,
        serverTimestamp: now,
        successorSnapshot: successorSnapshot,
      );
      recruitmentPatch = Map<String, Object?>.from(plan.recruitmentPatch);
      event = Map<String, Object?>.from(plan.event)
        ..['reason'] = 'weeklyRaidCompleted';
      if (successorRef != null && plan.successorMembershipPatch != null) {
        transaction.update(successorRef, plan.successorMembershipPatch!);
      }
    } else {
      recruitmentPatch = {
        'status': 'disbanded',
        'manualRecruitmentEnabled': false,
        'hasAvailableSlot': false,
        'memberPlayerIds': const <String>[],
        'memberCount': 0,
        'dealerCount': 0,
        'supportCount': 0,
        'partySlots': const <Map<String, Object?>>[],
        'raidStateTargets': const <Map<String, Object?>>[],
        'nonGroupMemberCount': 0,
        'groupActiveRecruitmentCountAfter': ?groupCountAfter,
        'revision': aggregate.revision + 1,
        'updatedAt': now,
      };
      event = {
        'schemaVersion': 1,
        'eventId': eventId,
        'recruitmentId': aggregate.recruitmentId,
        'type': 'memberLeft',
        'commandId': eventId,
        'commandRevision': aggregate.revision + 1,
        'audiencePlayerIds': [command.playerId],
        'actorPlayerId': command.playerId,
        'targetPlayerId': command.playerId,
        'reason': 'weeklyRaidCompleted',
        'occurredAt': now,
      };
    }
    recruitmentPatch.addAll({
      'commandTargets': [
        {
          'playerId': command.playerId,
          'stateId': PartyRaidState.documentIdFor(
            characterId: command.characterId,
            raidId: command.raidId,
          ),
        },
      ],
      'lastCommandId': eventId,
      'lastCommandType': PartyAtomicCommandType.personalComplete.name,
      'lastCommandActorPlayerId': command.playerId,
      'lastCommandAt': now,
    });

    transaction.update(recruitmentRef, recruitmentPatch);
    transaction.delete(memberRef);
    transaction.update(stateRef, {
      'status': 'completed',
      'source': 'manual',
      'revision': FieldValue.increment(1),
      'completedAt': now,
      'updatedAt': now,
    });
    if (assignmentData != null) transaction.delete(assignmentRef);
    if (groupId != null) {
      final listingRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('raidListings')
          .doc(aggregate.recruitmentId);
      if (aggregate.memberCount == 1) {
        transaction.delete(listingRef);
      } else {
        if (aggregate.visibility == 'group') {
          transaction.set(
            listingRef,
            partyRaidListingDocument(
              currentRecruitment: raw,
              recruitmentPatch: recruitmentPatch,
            ),
          );
        }
      }
    }
    if (groupRef case final ref?) {
      transaction.update(ref, {
        'activeRecruitmentCount': groupCountAfter!,
        'lastRecruitmentId': aggregate.recruitmentId,
        'revision': FieldValue.increment(1),
        'updatedAt': now,
      });
    }
    transaction.set(_firestore.collection('partyEvents').doc(eventId), event);
    return const WeeklyRaidClaimCommandResult.success();
  }

  @override
  Future<WeeklyRaidClaimCommandResult> deleteManualClaim(
    DeleteManualWeeklyRaidClaimCommand command,
  ) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unauthenticated,
      );
    }
    final claimId = _claimId(
      command.cycleKey,
      command.characterId,
      command.raidId,
    );
    if (claimId == null) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.invalidRequest,
      );
    }
    try {
      return await _firestore.runTransaction((transaction) async {
        final playerId = await _boundPlayerId(transaction, uid);
        if (playerId != command.playerId) {
          return const WeeklyRaidClaimCommandResult.failure(
            WeeklyRaidClaimCommandFailure.invalidRequest,
          );
        }
        final stateRef = _state(
          command.playerId,
          command.characterId,
          command.raidId,
        );
        final claimRef = _firestore
            .collection('players')
            .doc(command.playerId)
            .collection('weeklyRaidClaims')
            .doc(claimId);
        final state = await transaction.get(stateRef);
        final claim = await transaction.get(claimRef);
        final assignment = await transaction.get(
          _assignment(command.playerId, command.characterId, command.raidId),
        );
        final ownership = await _ownership(
          command.playerId,
          command.characterId,
          transaction,
        );
        _validateObservation(
          command.observation,
          playerId: command.playerId,
          characterId: command.characterId,
          raidId: command.raidId,
          cycleKey: command.cycleKey,
          ownership: ownership,
          state: state.data(),
          claim: claim.data(),
          assignment: assignment.data(),
        );
        final stateData = _currentRecord(
          ownership,
          state.data(),
          command.playerId,
          command.characterId,
          command.raidId,
          isState: true,
        );
        final claimData = _currentRecord(
          ownership,
          claim.data(),
          command.playerId,
          command.characterId,
          command.raidId,
          cycleKey: command.cycleKey,
        );
        if (stateData != null) {
          _validateDeleteState(command, stateData);
          if (stateData['status'] == 'completed') transaction.delete(stateRef);
        }
        if (claimData != null) transaction.delete(claimRef);
        if (stateData != null &&
            stateData['status'] != 'active' &&
            stateData['status'] != 'completed') {
          throw const _WeeklyRaidStateContractException();
        }
        return const WeeklyRaidClaimCommandResult.success();
      });
    } on _WeeklyRaidStateContractException {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.stateInconsistent,
      );
    } on FirebaseException catch (error) {
      return WeeklyRaidClaimCommandResult.failure(_failure(error.code));
    } catch (_) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unknown,
      );
    }
  }

  Future<_StatusCommandContext> _loadContext(
    CreateManualWeeklyRaidClaimCommand command,
  ) async {
    final state = await _state(
      command.playerId,
      command.characterId,
      command.raidId,
    ).get();
    final assignment = await _assignment(
      command.playerId,
      command.characterId,
      command.raidId,
    ).get();
    final claim = await _claim(
      command,
    ).get(const GetOptions(source: Source.server));
    final ownership = await _ownership(command.playerId, command.characterId);
    final observedApplications = <String, Map<String, dynamic>>{};
    WeeklyRaidCommandObservation observation([int? recruitmentRevision]) =>
        WeeklyRaidCommandObservation(
          playerId: command.playerId,
          characterId: command.characterId,
          raidId: command.raidId,
          cycleKey: command.cycleKey,
          ownershipRevision: ownership.revision!,
          state: state.data(),
          claim: claim.data(),
          assignment: assignment.data(),
          recruitmentRevision: recruitmentRevision,
          applications: observedApplications,
        );
    _currentRecord(
      ownership,
      claim.data(),
      command.playerId,
      command.characterId,
      command.raidId,
      cycleKey: command.cycleKey,
    );
    String? recruitmentId;
    int? recruitmentRevision;
    String? observedCycleKey;
    final stateData = _currentRecord(
      ownership,
      state.data(),
      command.playerId,
      command.characterId,
      command.raidId,
      isState: true,
    );
    final assignmentData = _currentRecord(
      ownership,
      assignment.data(),
      command.playerId,
      command.characterId,
      command.raidId,
    );
    if (command.forCancellation) {
      return _StatusCommandContext(
        impact: ManualWeeklyRaidClaimImpact(observation: observation()),
        pendingApplications: const [],
      );
    }
    if (stateData != null) {
      _validateStateIdentity(command, stateData);
      observedCycleKey = stateData['cycleKey'] as String;
      if (stateData['status'] == 'active') {
        if (stateData['source'] != 'party') {
          throw const _WeeklyRaidStateContractException();
        }
        final rawRecruitmentId = stateData['recruitmentId'];
        if (rawRecruitmentId is! String || rawRecruitmentId.isEmpty) {
          throw const _WeeklyRaidStateContractException();
        }
        recruitmentId = rawRecruitmentId;
      }
    } else if (assignmentData != null) {
      _validateAssignmentIdentity(command, assignmentData);
      observedCycleKey = assignmentData['cycleKey'] as String;
      final rawRecruitmentId = assignmentData['recruitmentId'];
      if (rawRecruitmentId is! String || rawRecruitmentId.isEmpty) {
        throw const _WeeklyRaidStateContractException();
      }
      recruitmentId = rawRecruitmentId;
    }

    String? title;
    var isLeader = false;
    var willDisband = false;
    String? successorName;
    if (recruitmentId != null && recruitmentId.isNotEmpty) {
      final recruitment = await _firestore
          .collection('recruitments')
          .doc(recruitmentId)
          .get();
      final data = recruitment.data();
      recruitmentRevision = data?['revision'] as int?;
      if (data != null && data['raidId'] != command.raidId) {
        throw const _WeeklyRaidStateContractException();
      }
      final occupancy = _classifyActiveOccupancy(
        observedCycleKey: observedCycleKey!,
        requestedCycleKey: command.cycleKey,
        recruitment: data,
      );
      if (occupancy == ExistingRaidStateOccupancyDecision.currentOrphanActive ||
          occupancy ==
              ExistingRaidStateOccupancyDecision.historicalOrphanActive) {
        return _StatusCommandContext(
          impact: ManualWeeklyRaidClaimImpact(
            observation: observation(recruitmentRevision),
            orphanedRecruitmentId: recruitmentId,
            orphanedCycleKey: observedCycleKey,
            orphanedStateRevision: stateData?['revision'] as int?,
            isHistoricalOrphanedParticipation:
                occupancy ==
                ExistingRaidStateOccupancyDecision.historicalOrphanActive,
          ),
          pendingApplications: const [],
        );
      }
      if (occupancy != ExistingRaidStateOccupancyDecision.currentActive) {
        throw const _WeeklyRaidStateContractException();
      }
      if (data == null ||
          data['status'] != 'active' ||
          data['currentCycleStatus'] != 'active' ||
          data['raidId'] != command.raidId ||
          data['currentCycleKey'] != command.cycleKey) {
        throw const _WeeklyRaidStateContractException();
      }
      title = data['title'] as String?;
      isLeader = data['leaderPlayerId'] == command.playerId;
      final memberIds = List<String>.from(
        data['memberPlayerIds'] as List? ?? const [],
      );
      if (!memberIds.contains(command.playerId)) {
        throw const _WeeklyRaidStateContractException();
      }
      willDisband = memberIds.length == 1;
      if (isLeader && memberIds.length > 1) {
        final successorId = memberIds.firstWhere(
          (id) => id != command.playerId,
        );
        final successor = await recruitment.reference
            .collection('members')
            .doc(successorId)
            .get();
        successorName = successor.data()?['characterNameSnapshot'] as String?;
      }
    }

    final pending = <_PendingStatusApplication>[];
    final query = await _firestore
        .collectionGroup('applications')
        .where('schemaVersion', isEqualTo: 1)
        .where('applicantPlayerId', isEqualTo: command.playerId)
        .where('cycleKey', isEqualTo: command.cycleKey)
        .orderBy('updatedAt', descending: true)
        .get();
    for (final application in query.docs) {
      final data = application.data();
      if (data['status'] != 'pending' ||
          data['characterId'] != command.characterId ||
          ownership.classifyParticipation(data) !=
              GameAccountOwnershipCondition.current) {
        continue;
      }
      final recruitmentRef = application.reference.parent.parent;
      if (recruitmentRef == null) continue;
      final recruitment = await _readAccessiblePendingRecruitment(
        () => recruitmentRef.get(),
      );
      if (recruitment == null ||
          recruitment.data()?['raidId'] != command.raidId) {
        continue;
      }
      pending.add(
        _PendingStatusApplication(
          applicationRef: application.reference,
          recruitmentRef: recruitmentRef,
          observed: Map<String, dynamic>.unmodifiable(data),
        ),
      );
      observedApplications[application.reference.path] = data;
    }
    return _StatusCommandContext(
      impact: ManualWeeklyRaidClaimImpact(
        observation: observation(recruitmentRevision),
        activeRecruitmentId: recruitmentId,
        activeRecruitmentTitle: title,
        isRecruitmentLeader: isLeader,
        willDisbandRecruitment: willDisband,
        nextLeaderCharacterName: successorName,
        pendingApplicationCount: pending.length,
      ),
      pendingApplications: pending,
    );
  }

  Future<void> _supersedePendingApplications(
    List<_PendingStatusApplication> applications,
    CreateManualWeeklyRaidClaimCommand command,
  ) async {
    for (final candidate in applications) {
      try {
        await _firestore.runTransaction((transaction) async {
          final recruitment = await transaction.get(candidate.recruitmentRef);
          final application = await transaction.get(candidate.applicationRef);
          final state = await transaction.get(
            _state(command.playerId, command.characterId, command.raidId),
          );
          final ownership = await _ownership(
            command.playerId,
            command.characterId,
            transaction,
          );
          final recruitmentData = recruitment.data();
          final applicationData = application.data();
          if (recruitmentData == null ||
              applicationData == null ||
              applicationData['status'] != 'pending' ||
              command.observation?.matchesApplication(
                    candidate.applicationRef.path,
                    applicationData,
                  ) !=
                  true ||
              applicationData['revision'] != candidate.observed['revision'] ||
              applicationData['updatedAt'] != candidate.observed['updatedAt'] ||
              applicationData['characterId'] != command.characterId ||
              applicationData['cycleKey'] != command.cycleKey ||
              applicationData['applicantPlayerId'] != command.playerId ||
              applicationData['ownershipRevision'] !=
                  candidate.observed['ownershipRevision'] ||
              ownership.revision != command.observation?.ownershipRevision ||
              ownership.classifyParticipation(applicationData) !=
                  GameAccountOwnershipCondition.current ||
              state.data()?['status'] != 'completed' ||
              state.data()?['cycleKey'] != command.cycleKey ||
              _currentRecord(
                    ownership,
                    state.data(),
                    command.playerId,
                    command.characterId,
                    command.raidId,
                    isState: true,
                  ) ==
                  null) {
            return;
          }
          final countedAsNonGroup =
              applicationData['countedAsNonGroupApplicant'] == true;
          transaction.update(candidate.recruitmentRef, {
            'pendingApplicationCount': FieldValue.increment(-1),
            if (countedAsNonGroup)
              'pendingNonGroupApplicantCount': FieldValue.increment(-1),
            'revision': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(candidate.applicationRef, {
            'status': 'superseded',
            'resolutionReason': 'weeklyRaidCompleted',
            'revision': FieldValue.increment(1),
            'decidedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      } on FirebaseException {
        // 완료 state가 이미 최종 차단 원장이다. 신청 정리는 비핵심 후처리다.
      } on _WeeklyRaidStateContractException {
        // Ownership changed or became unknown after completion. Preserve applications.
      }
    }
  }

  Future<GameAccountOwnershipSnapshot> _ownership(
    String playerId,
    String characterId, [
    Transaction? transaction,
  ]) async {
    final characterRef = _firestore.collection('characters').doc(characterId);
    final character =
        (transaction == null
                ? await characterRef.get(
                    const GetOptions(source: Source.server),
                  )
                : await transaction.get(characterRef))
            .data();
    final accountId = character?['gameAccountId'];
    if (accountId is! String || accountId.isEmpty) {
      throw const _WeeklyRaidStateContractException();
    }
    final accountRef = _firestore.collection('gameAccounts').doc(accountId);
    final account =
        (transaction == null
                ? await accountRef.get(const GetOptions(source: Source.server))
                : await transaction.get(accountRef))
            .data();
    final ownership = GameAccountOwnershipSnapshot.inspect(
      playerId: playerId,
      gameAccountId: accountId,
      account: account,
      character: character,
    );
    if (ownership.condition != GameAccountOwnershipCondition.current) {
      throw const _WeeklyRaidStateContractException();
    }
    return ownership;
  }

  Map<String, dynamic>? _currentRecord(
    GameAccountOwnershipSnapshot ownership,
    Map<String, dynamic>? data,
    String playerId,
    String characterId,
    String raidId, {
    bool isState = false,
    String? cycleKey,
  }) {
    if (data == null) return null;
    if (isState && RaidStateAvailability.isStub(data)) {
      final condition = PartyOwnershipRecordPolicy.classify(
        ownership: ownership,
        data: data,
        playerId: playerId,
        characterId: characterId,
        raidId: raidId,
        isRaidState: true,
        availabilityOnly: true,
      );
      if (condition == GameAccountOwnershipCondition.unknown) {
        throw const _WeeklyRaidStateContractException();
      }
      return null;
    }
    final recordCycle = data['cycleKey'];
    if (recordCycle is! String || recordCycle.isEmpty) {
      throw const _WeeklyRaidStateContractException();
    }
    final condition = PartyOwnershipRecordPolicy.classify(
      ownership: ownership,
      data: data,
      playerId: playerId,
      characterId: characterId,
      raidId: raidId,
      isRaidState: isState,
      claimCycleKey: cycleKey ?? recordCycle,
    );
    if (condition == GameAccountOwnershipCondition.unknown) {
      throw const _WeeklyRaidStateContractException();
    }
    return condition == GameAccountOwnershipCondition.current ? data : null;
  }

  void _validateObservation(
    WeeklyRaidCommandObservation? observation, {
    required String playerId,
    required String characterId,
    required String raidId,
    required String cycleKey,
    required GameAccountOwnershipSnapshot ownership,
    required Map<String, dynamic>? state,
    required Map<String, dynamic>? claim,
    required Map<String, dynamic>? assignment,
    bool afterHistoricalDelete = false,
  }) {
    if (observation == null ||
        !observation.matches(
          playerId: playerId,
          characterId: characterId,
          raidId: raidId,
          cycleKey: cycleKey,
          ownershipRevision: ownership.revision!,
          state: state,
          claim: claim,
          assignment: assignment,
          afterHistoricalDelete: afterHistoricalDelete,
        )) {
      throw const _WeeklyRaidStateContractException();
    }
  }

  Future<String?> _boundPlayerId(Transaction transaction, String uid) async {
    final binding = await transaction.get(
      _firestore.collection('authBindings').doc(uid),
    );
    final data = binding.data();
    final playerId = data?['playerId'];
    return data?['status'] == 'active' &&
            playerId is String &&
            playerId.isNotEmpty
        ? playerId
        : null;
  }

  bool _validCreate(CreateManualWeeklyRaidClaimCommand command) =>
      command.playerId.trim().isNotEmpty &&
      command.characterId.trim().isNotEmpty &&
      command.raidId.trim().isNotEmpty &&
      command.difficultyId.trim().isNotEmpty &&
      command.cycleKey.trim().isNotEmpty &&
      _claimId(command.cycleKey, command.characterId, command.raidId) != null &&
      command.cycleEndsAt.toUtc().difference(command.cycleStartedAt.toUtc()) ==
          const Duration(days: 7);

  bool _validCleanup(CleanupOrphanRaidParticipationCommand command) =>
      command.playerId.trim().isNotEmpty &&
      command.characterId.trim().isNotEmpty &&
      command.raidId.trim().isNotEmpty &&
      command.cycleKey.trim().isNotEmpty &&
      command.recruitmentId.trim().isNotEmpty;

  ExistingRaidStateOccupancyDecision _classifyActiveOccupancy({
    required String observedCycleKey,
    required String requestedCycleKey,
    required Map<String, dynamic>? recruitment,
  }) {
    final rawCycleEndsAt = recruitment?['cycleEndsAt'];
    return PartyCreateOccupancyGate.classifyExistingRaidState(
      requestedCycleKey: requestedCycleKey,
      stateCycleKey: observedCycleKey,
      stateStatus: 'active',
      recruitmentExists: recruitment != null,
      recruitmentStatus: recruitment?['status'] as String?,
      recruitmentCycleStatus: recruitment?['currentCycleStatus'] as String?,
      recruitmentCycleKey: recruitment?['currentCycleKey'] as String?,
      recruitmentContinuesTogether: recruitment?['continueTogether'] == true,
      recruitmentCycleEndsAt: rawCycleEndsAt is Timestamp
          ? rawCycleEndsAt.toDate()
          : null,
      now: clock(),
    );
  }

  void _validateOrphanState(
    CleanupOrphanRaidParticipationCommand command,
    Map<String, dynamic> data,
  ) {
    if (data['playerId'] != command.playerId ||
        data['characterId'] != command.characterId ||
        data['raidId'] != command.raidId ||
        data['cycleKey'] != command.cycleKey ||
        data['recruitmentId'] != command.recruitmentId ||
        data['status'] != 'active' ||
        data['source'] != 'party' ||
        (command.expectedStateRevision != null &&
            data['revision'] != command.expectedStateRevision)) {
      throw const _WeeklyRaidStateContractException();
    }
  }

  void _validateOrphanAssignment(
    CleanupOrphanRaidParticipationCommand command,
    Map<String, dynamic> data,
  ) {
    if (data['playerId'] != command.playerId ||
        data['characterId'] != command.characterId ||
        data['raidId'] != command.raidId ||
        data['cycleKey'] != command.cycleKey ||
        data['recruitmentId'] != command.recruitmentId ||
        data['status'] != 'active') {
      throw const _WeeklyRaidStateContractException();
    }
  }

  void _validateStateIdentity(
    CreateManualWeeklyRaidClaimCommand command,
    Map<String, dynamic> data,
  ) {
    if (data['playerId'] != command.playerId ||
        data['characterId'] != command.characterId ||
        data['raidId'] != command.raidId ||
        data['cycleKey'] is! String ||
        (data['status'] != 'active' && data['status'] != 'completed')) {
      throw const _WeeklyRaidStateContractException();
    }
  }

  void _validateAssignmentIdentity(
    CreateManualWeeklyRaidClaimCommand command,
    Map<String, dynamic> data,
  ) {
    if (data['playerId'] != command.playerId ||
        data['characterId'] != command.characterId ||
        data['raidId'] != command.raidId ||
        data['cycleKey'] is! String ||
        data['status'] != 'active') {
      throw const _WeeklyRaidStateContractException();
    }
  }

  void _validateDeleteState(
    DeleteManualWeeklyRaidClaimCommand command,
    Map<String, dynamic> data,
  ) {
    if (data['playerId'] != command.playerId ||
        data['characterId'] != command.characterId ||
        data['raidId'] != command.raidId ||
        data['cycleKey'] != command.cycleKey) {
      throw const _WeeklyRaidStateContractException();
    }
  }

  RecruitmentPartyRules _rules(Map<String, dynamic> data) =>
      RecruitmentPartyRules(
        partyCount: data['partyCount'] as int,
        membersPerParty: data['membersPerParty'] as int,
        supportsPerParty: data['supportsPerParty'] as int,
        maxDealersPerClassPerParty: data['maxDealersPerClassPerParty'] as int,
      );

  DocumentReference<Map<String, dynamic>> _state(
    String playerId,
    String characterId,
    String raidId,
  ) => _firestore
      .collection('players')
      .doc(playerId)
      .collection('raidStates')
      .doc(
        PartyRaidState.documentIdFor(characterId: characterId, raidId: raidId),
      );

  DocumentReference<Map<String, dynamic>> _assignment(
    String playerId,
    String characterId,
    String raidId,
  ) => _firestore
      .collection('players')
      .doc(playerId)
      .collection('activeRaidAssignments')
      .doc('${characterId}_$raidId');

  DocumentReference<Map<String, dynamic>> _claim(
    CreateManualWeeklyRaidClaimCommand command,
  ) => _firestore
      .collection('players')
      .doc(command.playerId)
      .collection('weeklyRaidClaims')
      .doc(_claimId(command.cycleKey, command.characterId, command.raidId)!);

  String? _claimId(String cycleKey, String characterId, String raidId) {
    try {
      return WeeklyRaidClaimDocumentId.create(
        cycleKey: cycleKey,
        characterId: characterId,
        raidId: raidId,
      );
    } on ArgumentError {
      return null;
    }
  }

  WeeklyRaidClaimCommandFailure _failure(String code) => switch (code) {
    'permission-denied' => WeeklyRaidClaimCommandFailure.permissionDenied,
    'aborted' ||
    'unavailable' ||
    'deadline-exceeded' ||
    'failed-precondition' =>
      WeeklyRaidClaimCommandFailure.temporarilyUnavailable,
    _ => WeeklyRaidClaimCommandFailure.unknown,
  };

  Future<T?> _readAccessiblePendingRecruitment<T>(
    Future<T> Function() read,
  ) async {
    try {
      return await read();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return null;
      rethrow;
    }
  }
}

class _StatusCommandContext {
  const _StatusCommandContext({
    required this.impact,
    required this.pendingApplications,
  });

  final ManualWeeklyRaidClaimImpact impact;
  final List<_PendingStatusApplication> pendingApplications;
}

class _PendingStatusApplication {
  const _PendingStatusApplication({
    required this.applicationRef,
    required this.recruitmentRef,
    required this.observed,
  });

  final DocumentReference<Map<String, dynamic>> applicationRef;
  final DocumentReference<Map<String, dynamic>> recruitmentRef;
  final Map<String, dynamic> observed;
}

class _ManualClaimTransactionOutcome {
  const _ManualClaimTransactionOutcome.result(this.commandResult)
    : shouldRetryAfterRollover = false;

  const _ManualClaimTransactionOutcome.retryAfterRollover()
    : commandResult = null,
      shouldRetryAfterRollover = true;

  final WeeklyRaidClaimCommandResult? commandResult;
  final bool shouldRetryAfterRollover;
}

class _WeeklyRaidStateContractException implements Exception {
  const _WeeklyRaidStateContractException();
}
