import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../group/data/mappers/group_active_recruitment_write_plan.dart';
import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_create_command.dart';
import '../../domain/repositories/party_create_repository.dart';
import '../../domain/services/party_create_command_validator.dart';
import '../../domain/services/party_create_occupancy_gate.dart';
import '../mappers/party_atomic_membership_write_plan.dart';
import '../mappers/party_create_write_plan.dart';

/// 새 Aggregate·raidState 구조용 파티 생성 Repository.
///
/// 운영 Router에는 아직 연결하지 않는다.
class FirestorePartyAtomicCreateRepository implements PartyCreateRepository {
  const FirestorePartyAtomicCreateRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    this.clock = DateTime.now,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final DateTime Function() clock;

  @override
  Future<PartyCreateResult> create(PartyCreateCommand command) async {
    final requestFailure = const PartyCreateCommandValidator().validate(
      command,
    );
    if (requestFailure != null) {
      return PartyCreateResult.failure(requestFailure);
    }
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null) {
      return const PartyCreateResult.failure(
        PartyCreateFailure.unauthenticated,
      );
    }

    try {
      // 만료된 점유 삭제와 신규 생성은 Rules 평가 한도 때문에 별도 원자 명령이다.
      // 첫 Transaction이 stale 상태만 삭제하면, 두 번째가 모든 생성 조건을 다시 읽는다.
      for (var attempt = 0; attempt < 2; attempt++) {
        final result = await _firestore.runTransaction<PartyCreateResult?>((
          transaction,
        ) async {
          final binding = await transaction.get(
            _firestore.collection('authBindings').doc(authUid),
          );
          final bindingData = binding.data();
          final playerId = bindingData?['playerId'];
          if (bindingData?['status'] != 'active' ||
              playerId is! String ||
              playerId.isEmpty) {
            return const PartyCreateResult.failure(
              PartyCreateFailure.playerBindingMissing,
            );
          }

          final characterRef = _firestore
              .collection('characters')
              .doc(command.leaderCharacterId);
          final recruitmentRef = _firestore
              .collection('recruitments')
              .doc(command.recruitmentId);
          final raidStateId = PartyRaidState.documentIdFor(
            characterId: command.leaderCharacterId,
            raidId: command.metadata.raidId,
          );
          final raidStateRef = _firestore
              .collection('players')
              .doc(playerId)
              .collection('raidStates')
              .doc(raidStateId);

          final character = await transaction.get(characterRef);
          final recruitment = await transaction.get(recruitmentRef);
          final raidState = await transaction.get(raidStateRef);
          final characterData = character.data();
          final raidStateData = raidState.data();
          final raidStateRecruitmentId = raidStateData?['recruitmentId'];
          final raidStateCycleKey = raidStateData?['cycleKey'];
          final raidStateStatus = raidStateData?['status'];

          DocumentSnapshot<Map<String, dynamic>>? assignedRecruitment;
          if (raidState.exists &&
              raidStateStatus == 'active' &&
              raidStateRecruitmentId is String &&
              raidStateRecruitmentId.isNotEmpty &&
              raidStateRecruitmentId != command.recruitmentId) {
            assignedRecruitment = await transaction.get(
              _firestore.collection('recruitments').doc(raidStateRecruitmentId),
            );
          }

          DocumentSnapshot<Map<String, dynamic>>? group;
          DocumentSnapshot<Map<String, dynamic>>? membership;
          final groupId = command.groupId;
          if (groupId != null) {
            final groupRef = _firestore.collection('groups').doc(groupId);
            group = await transaction.get(groupRef);
            membership = await transaction.get(
              groupRef.collection('members').doc(playerId),
            );
          }

          if (!character.exists) {
            return const PartyCreateResult.failure(
              PartyCreateFailure.serverDataMissing,
            );
          }
          if (characterData?['status'] != 'active') {
            return const PartyCreateResult.failure(
              PartyCreateFailure.invalidCharacter,
            );
          }
          if (characterData?['ownerPlayerId'] != playerId) {
            return const PartyCreateResult.failure(
              PartyCreateFailure.ownershipLost,
            );
          }
          if (raidState.exists &&
              raidStateStatus == 'completed' &&
              raidStateCycleKey == command.cycleKey) {
            return const PartyCreateResult.failure(
              PartyCreateFailure.weeklyRaidCompleted,
            );
          }

          final occupancy = PartyCreateOccupancyGate.decide(
            newRecruitmentId: command.recruitmentId,
            playerId: playerId,
            newRecruitmentExists: recruitment.exists,
            newRecruitmentLeaderId:
                recruitment.data()?['leaderPlayerId'] as String?,
            assignmentExists: raidState.exists && raidStateStatus == 'active',
            assignmentRecruitmentId: raidStateRecruitmentId is String
                ? raidStateRecruitmentId
                : null,
            assignmentCycleKey: raidStateCycleKey is String
                ? raidStateCycleKey
                : null,
            assignedRecruitmentExists: assignedRecruitment?.exists == true,
            assignedRecruitmentStatus:
                assignedRecruitment?.data()?['status'] as String?,
            assignedRecruitmentCycleKey:
                assignedRecruitment?.data()?['currentCycleKey'] as String?,
            assignedRecruitmentContinuesTogether:
                assignedRecruitment?.data()?['continueTogether'] == true,
            assignedRecruitmentCycleEndsAt:
                (assignedRecruitment?.data()?['cycleEndsAt'] as Timestamp?)
                    ?.toDate(),
            newCycleKey: command.cycleKey,
            now: clock(),
          );
          switch (occupancy) {
            case PartyCreateOccupancyDecision.alreadyCreated:
              return PartyCreateResult.success(command.recruitmentId);
            case PartyCreateOccupancyDecision.idConflict:
              return const PartyCreateResult.failure(
                PartyCreateFailure.idConflict,
              );
            case PartyCreateOccupancyDecision.participationConflict:
              return const PartyCreateResult.failure(
                PartyCreateFailure.participationConflict,
              );
            case PartyCreateOccupancyDecision.proceed:
            case PartyCreateOccupancyDecision.replaceStaleAssignment:
              break;
          }
          if (groupId != null &&
              (group?.data()?['status'] != 'active' ||
                  membership == null ||
                  !membership.exists)) {
            return const PartyCreateResult.failure(
              PartyCreateFailure.notGroupMember,
            );
          }

          final verifiedName = characterData?['characterName'];
          final verifiedClass = characterData?['characterClassName'];
          final verifiedItemLevel = _parseItemLevel(
            characterData?['itemAvgLevel'],
          );
          if (verifiedName is! String ||
              verifiedName.isEmpty ||
              verifiedClass is! String ||
              verifiedClass.isEmpty ||
              verifiedItemLevel == null ||
              verifiedItemLevel < command.metadata.minItemLevel) {
            return const PartyCreateResult.failure(
              PartyCreateFailure.invalidCharacter,
            );
          }

          final now = FieldValue.serverTimestamp();
          final base = PartyCreateWritePlan.fromCommand(
            command: command,
            playerId: playerId,
            serverTimestamp: now,
            verifiedCharacterName: verifiedName,
            verifiedClassName: verifiedClass,
            verifiedItemLevel: verifiedItemLevel,
          );
          final groupActiveRecruitmentCountAfter = groupId == null
              ? 0
              : ((group?.data()?['activeRecruitmentCount'] as int?) ?? -1) + 1;
          if (groupId != null && groupActiveRecruitmentCountAfter < 1) {
            return const PartyCreateResult.failure(
              PartyCreateFailure.serverDataMissing,
            );
          }
          final plan = PartyAtomicCreateWritePlan.fromBase(
            base: base,
            command: command,
            playerId: playerId,
            classKey: verifiedClass,
            serverTimestamp: now,
            groupActiveRecruitmentCountAfter: groupActiveRecruitmentCountAfter,
          );

          final claimId =
              '${command.cycleKey}_${command.leaderCharacterId}_${command.metadata.raidId}';
          final claim = await transaction.get(
            _firestore
                .collection('players')
                .doc(playerId)
                .collection('weeklyRaidClaims')
                .doc(claimId),
          );
          if (claim.exists) {
            return const PartyCreateResult.failure(
              PartyCreateFailure.weeklyRaidCompleted,
            );
          }

          if (occupancy ==
              PartyCreateOccupancyDecision.replaceStaleAssignment) {
            transaction.delete(raidStateRef);
            return null;
          }
          if (groupId != null && plan.groupActiveRecruitmentDelta == 1) {
            final groupRef = _firestore.collection('groups').doc(groupId);
            final currentCount = group?.data()?['activeRecruitmentCount'];
            final groupRevision = group?.data()?['revision'];
            if (currentCount is! int || groupRevision is! int) {
              return const PartyCreateResult.failure(
                PartyCreateFailure.serverDataMissing,
              );
            }
            final groupPlan = GroupActiveRecruitmentWritePlan.open(
              recruitmentId: command.recruitmentId,
              currentCount: currentCount,
              groupRevision: groupRevision,
              serverTimestamp: now,
            );
            transaction.update(groupRef, groupPlan.groupPatch);
            final listing = plan.groupRaidListing;
            if (listing != null) {
              transaction.set(
                groupRef.collection('raidListings').doc(command.recruitmentId),
                listing,
              );
            }
          }

          transaction.set(recruitmentRef, plan.recruitment);
          transaction.set(
            recruitmentRef.collection('members').doc(playerId),
            plan.leaderMembership,
          );
          transaction.set(raidStateRef, plan.raidState);
          transaction.set(
            _firestore
                .collection('partyEvents')
                .doc(plan.event['eventId']! as String),
            plan.event,
          );
          return PartyCreateResult.success(command.recruitmentId);
        });
        if (result != null) return result;
      }
      return const PartyCreateResult.failure(
        PartyCreateFailure.temporarilyUnavailable,
      );
    } on FirebaseException catch (error) {
      return PartyCreateResult.failure(_firebaseFailure(error.code));
    } on ArgumentError {
      return const PartyCreateResult.failure(PartyCreateFailure.invalidRequest);
    } on FormatException {
      return const PartyCreateResult.failure(PartyCreateFailure.invalidRequest);
    } catch (_) {
      return const PartyCreateResult.failure(PartyCreateFailure.unknown);
    }
  }

  double? _parseItemLevel(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '').trim());
    }
    return null;
  }

  PartyCreateFailure _firebaseFailure(String code) => switch (code) {
    'permission-denied' => PartyCreateFailure.permissionDenied,
    'unavailable' ||
    'deadline-exceeded' ||
    'aborted' => PartyCreateFailure.temporarilyUnavailable,
    _ => PartyCreateFailure.unknown,
  };
}
