import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/weekly_raid_claim.dart';
import '../../domain/entities/weekly_raid_claim_command.dart';
import '../../domain/repositories/weekly_raid_claim_command_repository.dart';
import '../../domain/repositories/weekly_raid_claim_repository.dart';
import '../dtos/weekly_raid_claim_dto.dart';
import '../mappers/weekly_raid_claim_mapper.dart';
import '../mappers/weekly_raid_claim_document_id.dart';
import '../../../recruitment_list/data/mappers/party_membership_event_writer.dart';
import '../../../recruitment_list/data/mappers/party_membership_write_plan.dart';
import '../../../recruitment_list/data/mappers/party_raid_listing_sync.dart';
import '../../../recruitment_list/domain/entities/party_event.dart';

class FirestoreWeeklyRaidClaimRepository
    implements WeeklyRaidClaimRepository, WeeklyRaidClaimCommandRepository {
  FirestoreWeeklyRaidClaimRepository({
    required FirebaseFirestore firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _mapper = WeeklyRaidClaimMapper(
         toDateTime: (value) => switch (value) {
           Timestamp timestamp => timestamp.toDate(),
           DateTime dateTime => dateTime,
           _ => throw const FormatException('Expected Firestore Timestamp.'),
         },
       );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final WeeklyRaidClaimMapper _mapper;

  @override
  Future<WeeklyRaidClaimImpactResult> inspectManualClaimImpact(
    CreateManualWeeklyRaidClaimCommand command,
  ) async {
    if (_firebaseAuth.currentUser == null) {
      return const WeeklyRaidClaimImpactResult.failure(
        WeeklyRaidClaimCommandFailure.unauthenticated,
      );
    }
    try {
      final context = await _loadConflictContext(command);
      return WeeklyRaidClaimImpactResult.success(context.impact);
    } on FirebaseException catch (error) {
      return WeeklyRaidClaimImpactResult.failure(_commandFailure(error.code));
    } catch (_) {
      return const WeeklyRaidClaimImpactResult.failure(
        WeeklyRaidClaimCommandFailure.unknown,
      );
    }
  }

  @override
  Stream<List<WeeklyRaidClaim>> watchCurrentCycleClaims({
    required String playerId,
    required String cycleKey,
  }) {
    if (playerId.trim().isEmpty || cycleKey.trim().isEmpty) {
      return Stream.error(
        const WeeklyRaidClaimReadException(
          WeeklyRaidClaimReadFailureType.contract,
        ),
      );
    }
    final claimsQuery = _firestore
        .collection('players')
        .doc(playerId)
        .collection('weeklyRaidClaims')
        .where('cycleKey', isEqualTo: cycleKey);
    final eventsQuery = _firestore
        .collection('players')
        .doc(playerId)
        .collection('events');
    late final StreamController<List<WeeklyRaidClaim>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? claimsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? eventsSub;

    void emitSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
      if (controller.isClosed) return;
      try {
        controller.add(_mapCurrentCycleClaims(snapshot, playerId, cycleKey));
      } catch (error, stackTrace) {
        controller.addError(_readException(error), stackTrace);
      }
    }

    Future<void> refreshFromServer() async {
      try {
        final snapshot = await claimsQuery.get(
          const GetOptions(source: Source.server),
        );
        emitSnapshot(snapshot);
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(_readException(error), stackTrace);
        }
      }
    }

    controller = StreamController<List<WeeklyRaidClaim>>(
      onListen: () {
        claimsSub = claimsQuery.snapshots().listen(
          emitSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(_readException(error), stackTrace);
            }
          },
        );
        eventsSub = eventsQuery.snapshots().listen(
          (snapshot) {
            final shouldRefresh = snapshot.docChanges.any((change) {
              if (change.type != DocumentChangeType.added) return false;
              final type = change.doc.data()?['type'];
              return type == 'partyCompleted' ||
                  type == 'partyCompletionCancelled';
            });
            if (shouldRefresh) unawaited(refreshFromServer());
          },
          onError: (_) {},
        );
      },
      onCancel: () async {
        await claimsSub?.cancel();
        await eventsSub?.cancel();
      },
    );
    return controller.stream;
  }

  List<WeeklyRaidClaim> _mapCurrentCycleClaims(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String playerId,
    String cycleKey,
  ) {
    try {
      return snapshot.docs
          .map((document) {
            final claim = _mapper.map(
              WeeklyRaidClaimDto.fromMap(document.data()),
              documentId: document.id,
            );
            if (claim.playerId != playerId || claim.cycleKey != cycleKey) {
              throw const FormatException('Claim path mismatch.');
            }
            return claim;
          })
          .toList(growable: false);
    } on WeeklyRaidClaimReadException {
      rethrow;
    } catch (_) {
      throw const WeeklyRaidClaimReadException(
        WeeklyRaidClaimReadFailureType.contract,
      );
    }
  }

  WeeklyRaidClaimReadException _readException(Object error) {
    if (error is WeeklyRaidClaimReadException) return error;
    if (error is FirebaseException) {
      return WeeklyRaidClaimReadException(switch (error.code) {
        'permission-denied' => WeeklyRaidClaimReadFailureType.permissionDenied,
        'unavailable' ||
        'deadline-exceeded' => WeeklyRaidClaimReadFailureType.unavailable,
        _ => WeeklyRaidClaimReadFailureType.unknown,
      });
    }
    return const WeeklyRaidClaimReadException(
      WeeklyRaidClaimReadFailureType.unknown,
    );
  }

  @override
  Future<WeeklyRaidClaimCommandResult> createManualClaim(
    CreateManualWeeklyRaidClaimCommand command, {
    bool resolveConflicts = false,
  }
  ) async {
    if (_firebaseAuth.currentUser == null) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unauthenticated,
      );
    }
    final claimId = _claimId(
      cycleKey: command.cycleKey,
      characterId: command.characterId,
      raidId: command.raidId,
    );
    if (claimId == null ||
        command.difficultyId.trim().isEmpty ||
        command.cycleEndsAt.toUtc().difference(
              command.cycleStartedAt.toUtc(),
            ) !=
            const Duration(days: 7)) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.invalidRequest,
      );
    }
    try {
      final conflictContext = await _loadConflictContext(command);
      if (!resolveConflicts &&
          conflictContext.impact.pendingApplicationCount > 0) {
        return const WeeklyRaidClaimCommandResult.failure(
          WeeklyRaidClaimCommandFailure.pendingApplication,
        );
      }
      final claimRef = _claim(command.playerId, claimId);
      final assignmentRef = _firestore
          .collection('players')
          .doc(command.playerId)
          .collection('activeRaidAssignments')
          .doc('${command.characterId}_${command.raidId}');
      return await _firestore.runTransaction((transaction) async {
        final claim = await transaction.get(claimRef);
        final assignment = await transaction.get(assignmentRef);
        if (claim.exists) {
          return const WeeklyRaidClaimCommandResult.success();
        }
        if (assignment.exists && !resolveConflicts) {
          return const WeeklyRaidClaimCommandResult.failure(
            WeeklyRaidClaimCommandFailure.activeAssignment,
          );
        }
        Map<String, dynamic>? recruitmentData;
        Map<String, dynamic>? memberData;
        DocumentReference<Map<String, dynamic>>? recruitmentRef;
        DocumentReference<Map<String, dynamic>>? memberRef;
        DocumentSnapshot<Map<String, dynamic>>? nextLeader;
        if (assignment.exists) {
          final assignmentData = assignment.data();
          final recruitmentId = assignmentData?['recruitmentId'];
          if (recruitmentId is! String || recruitmentId.isEmpty) {
            return const WeeklyRaidClaimCommandResult.failure(
              WeeklyRaidClaimCommandFailure.invalidRequest,
            );
          }
          recruitmentRef = _firestore.collection('recruitments').doc(recruitmentId);
          memberRef = recruitmentRef.collection('members').doc(command.playerId);
          final recruitment = await transaction.get(recruitmentRef);
          final member = await transaction.get(memberRef);
          recruitmentData = recruitment.data();
          memberData = member.data();
          if (!recruitment.exists ||
              !member.exists ||
              recruitmentData?['status'] != 'active' ||
              memberData?['characterId'] != command.characterId ||
              recruitmentData?['raidId'] != command.raidId) {
            return const WeeklyRaidClaimCommandResult.failure(
              WeeklyRaidClaimCommandFailure.temporarilyUnavailable,
            );
          }
          final remaining = List<String>.from(
            recruitmentData?['memberPlayerIds'] as List,
          )..remove(command.playerId);
          if (recruitmentData?['leaderPlayerId'] == command.playerId &&
              remaining.isNotEmpty) {
            nextLeader = await transaction.get(
              recruitmentRef.collection('members').doc(remaining.first),
            );
          }
        }

        final pendingApplications = <_PendingClaimApplication>[];
        for (final candidate in conflictContext.pendingApplications) {
          final application = await transaction.get(candidate.applicationRef);
          final recruitment = await transaction.get(candidate.recruitmentRef);
          final applicationData = application.data();
          if (application.exists &&
              recruitment.exists &&
              applicationData?['status'] == 'pending' &&
              applicationData?['characterId'] == command.characterId &&
              applicationData?['cycleKey'] == command.cycleKey &&
              recruitment.data()?['raidId'] == command.raidId) {
            pendingApplications.add(candidate);
          }
        }
        PartyRaidListingTx? listing;
        if (assignment.exists) {
          listing = await PartyRaidListingTx.read(
            transaction: transaction,
            firestore: _firestore,
            groupId: recruitmentData?['groupId'],
            recruitmentId: recruitmentRef!.id,
          );
        }
        final now = FieldValue.serverTimestamp();
        if (assignment.exists) {
          final r = recruitmentData!;
          final m = memberData!;
          final beforeMembers = List<String>.from(r['memberPlayerIds'] as List);
          final remaining = [...beforeMembers]..remove(command.playerId);
          final oldLeader = r['leaderPlayerId'] as String;
          final nextLeaderId = oldLeader == command.playerId
              ? (remaining.isEmpty ? null : remaining.first)
              : oldLeader;
          final nextLeaderData = nextLeader?.data();
          final nextLeaderCharacterName = nextLeaderId == oldLeader
              ? r['leaderCharacterNameSnapshot'] as String?
              : nextLeaderData?['characterNameSnapshot'] as String?;
          final nextLeaderClassName = nextLeaderId == oldLeader
              ? r['leaderClassNameSnapshot'] as String?
              : nextLeaderData?['classNameSnapshot'] as String?;
          final recruitmentPatch = PartyMembershipWritePlan.removeFromRecruitment(
            memberPlayerIds: beforeMembers,
            targetPlayerId: command.playerId,
            memberCount: r['memberCount'] as int,
            dealerCount: r['dealerCount'] as int,
            supportCount: r['supportCount'] as int,
            targetRole: m['role'] as String,
            maxMemberCount: r['maxMemberCount'] as int,
            revision: r['revision'] as int,
            nextLeaderPlayerId: nextLeaderId,
            nextLeaderCharacterName: nextLeaderCharacterName,
            nextLeaderClassName: nextLeaderClassName,
            serverTimestamp: now,
          );
          transaction.update(recruitmentRef!, recruitmentPatch);
          listing?.write(
            transaction: transaction,
            currentRecruitment: partyRecruitmentMap(r),
            recruitmentPatch: recruitmentPatch,
          );
          transaction.delete(memberRef!);
          transaction.delete(assignmentRef);
          if (nextLeaderId != null && nextLeaderId != oldLeader) {
            transaction.update(
              recruitmentRef.collection('members').doc(nextLeaderId),
              {'canApproveApplications': true, 'updatedAt': now},
            );
          }
          PartyMembershipEventWriter.writeToRecipients(
            transaction: transaction,
            firestore: _firestore,
            type: PartyEventType.memberLeft,
            recipientPlayerIds: beforeMembers,
            recruitmentId: recruitmentRef.id,
            recruitmentRevision: (r['revision'] as int) + 1,
            actorPlayerId: command.playerId,
            targetPlayerId: command.playerId,
            characterNameSnapshot: m['characterNameSnapshot'] as String?,
            classNameSnapshot: m['classNameSnapshot'] as String?,
            role: m['role'] as String?,
            raidId: command.raidId,
            difficultyId: r['difficultyId'] as String?,
            partyIndex: m['partyIndex'] as int?,
            slotIndex: m['slotIndex'] as int?,
            reason: 'weeklyRaidCompleted',
            serverTimestamp: now,
          );
        }
        for (final pending in pendingApplications) {
          transaction.update(pending.applicationRef, {
            'status': 'superseded',
            'resolutionReason': 'weeklyRaidCompleted',
            'revision': FieldValue.increment(1),
            'decidedAt': now,
            'updatedAt': now,
          });
        }
        transaction.set(claimRef, {
          'schemaVersion': 1,
          'playerId': command.playerId,
          'characterId': command.characterId,
          'raidId': command.raidId,
          'difficultyId': command.difficultyId,
          'cycleKey': command.cycleKey,
          'source': 'manual',
          'cycleStartedAt': Timestamp.fromDate(command.cycleStartedAt.toUtc()),
          'cycleEndsAt': Timestamp.fromDate(command.cycleEndsAt.toUtc()),
          'completedAt': now,
          'updatedAt': now,
        });
        return const WeeklyRaidClaimCommandResult.success();
      });
    } on FirebaseException catch (error) {
      return WeeklyRaidClaimCommandResult.failure(_commandFailure(error.code));
    } catch (_) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unknown,
      );
    }
  }

  Future<_ManualClaimConflictContext> _loadConflictContext(
    CreateManualWeeklyRaidClaimCommand command,
  ) async {
    final assignmentRef = _firestore
        .collection('players')
        .doc(command.playerId)
        .collection('activeRaidAssignments')
        .doc('${command.characterId}_${command.raidId}');
    final assignment = await assignmentRef.get();
    String? activeRecruitmentId;
    String? activeRecruitmentTitle;
    var isLeader = false;
    var willDisband = false;
    String? nextLeaderCharacterName;
    if (assignment.exists) {
      activeRecruitmentId = assignment.data()?['recruitmentId'] as String?;
      if (activeRecruitmentId != null) {
        final recruitment = await _firestore
            .collection('recruitments')
            .doc(activeRecruitmentId)
            .get();
        final data = recruitment.data();
        activeRecruitmentTitle = data?['title'] as String?;
        isLeader = data?['leaderPlayerId'] == command.playerId;
        final memberIds = List<String>.from(data?['memberPlayerIds'] as List? ?? const []);
        willDisband = isLeader && memberIds.length == 1;
        if (isLeader && memberIds.length > 1) {
          final nextId = memberIds.firstWhere((id) => id != command.playerId);
          final nextMember = await recruitment.reference
              .collection('members')
              .doc(nextId)
              .get();
          nextLeaderCharacterName =
              nextMember.data()?['characterNameSnapshot'] as String?;
        }
      }
    }
    final applicationQuery = await _firestore
        .collectionGroup('applications')
        .where('schemaVersion', isEqualTo: 1)
        .where('applicantPlayerId', isEqualTo: command.playerId)
        .where('cycleKey', isEqualTo: command.cycleKey)
        .orderBy('updatedAt', descending: true)
        .get();
    final candidates = <_PendingClaimApplication>[];
    for (final application in applicationQuery.docs) {
      final data = application.data();
      if (data['status'] != 'pending' ||
          data['characterId'] != command.characterId) {
        continue;
      }
      final recruitmentRef = application.reference.parent.parent;
      if (recruitmentRef == null) continue;
      final recruitment = await recruitmentRef.get();
      if (recruitment.data()?['raidId'] != command.raidId) continue;
      candidates.add(
        _PendingClaimApplication(
          applicationRef: application.reference,
          recruitmentRef: recruitmentRef,
        ),
      );
    }
    return _ManualClaimConflictContext(
      impact: ManualWeeklyRaidClaimImpact(
        activeRecruitmentId: activeRecruitmentId,
        activeRecruitmentTitle: activeRecruitmentTitle,
        isRecruitmentLeader: isLeader,
        willDisbandRecruitment: willDisband,
        nextLeaderCharacterName: nextLeaderCharacterName,
        pendingApplicationCount: candidates.length,
      ),
      pendingApplications: candidates,
    );
  }

  @override
  Future<WeeklyRaidClaimCommandResult> deleteManualClaim(
    DeleteManualWeeklyRaidClaimCommand command,
  ) async {
    if (_firebaseAuth.currentUser == null) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unauthenticated,
      );
    }
    final claimId = _claimId(
      cycleKey: command.cycleKey,
      characterId: command.characterId,
      raidId: command.raidId,
    );
    if (claimId == null) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.invalidRequest,
      );
    }
    try {
      final claimRef = _claim(command.playerId, claimId);
      await _firestore.runTransaction((transaction) async {
        final claim = await transaction.get(claimRef);
        if (claim.exists) transaction.delete(claimRef);
      });
      return const WeeklyRaidClaimCommandResult.success();
    } on FirebaseException catch (error) {
      return WeeklyRaidClaimCommandResult.failure(_commandFailure(error.code));
    } catch (_) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unknown,
      );
    }
  }

  DocumentReference<Map<String, dynamic>> _claim(
    String playerId,
    String claimId,
  ) => _firestore
      .collection('players')
      .doc(playerId)
      .collection('weeklyRaidClaims')
      .doc(claimId);

  String? _claimId({
    required String cycleKey,
    required String characterId,
    required String raidId,
  }) {
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

  WeeklyRaidClaimCommandFailure _commandFailure(String code) => switch (code) {
    'permission-denied' => WeeklyRaidClaimCommandFailure.permissionDenied,
    'unavailable' ||
    'deadline-exceeded' ||
    'failed-precondition' ||
    'aborted' => WeeklyRaidClaimCommandFailure.temporarilyUnavailable,
    _ => WeeklyRaidClaimCommandFailure.unknown,
  };
}

class _ManualClaimConflictContext {
  const _ManualClaimConflictContext({
    required this.impact,
    required this.pendingApplications,
  });

  final ManualWeeklyRaidClaimImpact impact;
  final List<_PendingClaimApplication> pendingApplications;
}

class _PendingClaimApplication {
  const _PendingClaimApplication({
    required this.applicationRef,
    required this.recruitmentRef,
  });

  final DocumentReference<Map<String, dynamic>> applicationRef;
  final DocumentReference<Map<String, dynamic>> recruitmentRef;
}
