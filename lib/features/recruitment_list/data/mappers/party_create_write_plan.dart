import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/party_create_command.dart';
import '../../domain/policies/party_cycle_policy.dart';

class PartyCreateWritePlan {
  const PartyCreateWritePlan({
    required this.recruitment,
    required this.leaderMembership,
    required this.assignment,
  });

  factory PartyCreateWritePlan.fromCommand({
    required PartyCreateCommand command,
    required String playerId,
    required Object serverTimestamp,
    required String verifiedCharacterName,
    required String verifiedClassName,
    required double verifiedItemLevel,
  }) {
    final metadata = command.metadata;
    final rules = command.compositionRules;
    final cycle = const PartyCyclePolicy().fromKey(command.cycleKey);
    if (cycle == null) throw ArgumentError.value(command.cycleKey, 'cycleKey');
    final recruitment = <String, Object?>{
      'schemaVersion': 1,
      'title': command.title.trim(),
      'leaderPlayerId': playerId,
      'leaderCharacterNameSnapshot': verifiedCharacterName,
      'leaderClassNameSnapshot': verifiedClassName,
      'memberPlayerIds': [playerId],
      'raidCatalogVersion': metadata.catalogVersion,
      'raidId': metadata.raidId,
      'difficultyId': metadata.difficultyId,
      'raidNameSnapshot': metadata.raidName,
      'difficultyNameSnapshot': metadata.difficultyName,
      'difficultyAliasSnapshot': metadata.difficultyAlias,
      'gateCount': metadata.gateCount,
      'minItemLevel': metadata.minItemLevel,
      'minCombatPower': metadata.minCombatPower,
      'experienceLevel': metadata.experienceLevel?.name,
      'maxPlayHours': metadata.maxPlayHours,
      'raidStartAt': metadata.raidStartAt == null
          ? null
          : Timestamp.fromDate(metadata.raidStartAt!.toUtc()),
      'status': 'active',
      'visibility': command.visibility,
      'groupId': command.groupId,
      'approvalPolicy': _approvalPolicy(command),
      'continueTogether': false,
      'manualRecruitmentEnabled': true,
      'hasAvailableSlot': rules.totalMembers > 1,
      'currentCycleKey': command.cycleKey,
      'targetCycleKey': command.cycleKey,
      'currentCycleStatus': 'active',
      'cycleStartedAt': Timestamp.fromDate(cycle.startedAt),
      'cycleEndsAt': Timestamp.fromDate(cycle.endsAt),
      'partyCount': rules.partyCount,
      'membersPerParty': rules.membersPerParty,
      'supportsPerParty': rules.supportsPerParty,
      'maxDealersPerClassPerParty': rules.maxDealersPerClassPerParty,
      'slotLedgerVersion': 2,
      'memberCount': 1,
      'maxMemberCount': rules.totalMembers,
      'dealerCount': command.leaderRole.name == 'dealer' ? 1 : 0,
      'supportCount': command.leaderRole.name == 'support' ? 1 : 0,
      'revision': 1,
      'createdAt': serverTimestamp,
      'updatedAt': serverTimestamp,
      'completedAt': null,
      'completedByPlayerId': null,
    };
    return PartyCreateWritePlan(
      recruitment: recruitment,
      leaderMembership: {
        'schemaVersion': 1,
        'playerId': playerId,
        'characterId': command.leaderCharacterId,
        'characterNameSnapshot': verifiedCharacterName,
        'classNameSnapshot': verifiedClassName,
        'role': command.leaderRole.name,
        'partyIndex': 0,
        'slotIndex': 0,
        'joinedAt': serverTimestamp,
        'joinedBy': playerId,
        'submittedBuildSnapshotId': null,
        'itemLevelSnapshot': verifiedItemLevel,
        'combatPowerSnapshot': command.leaderCombatPower,
        'gemValidationSnapshot': command.leaderGemValidation?.toFields(),
        'buildIntegritySnapshot': command.leaderBuildIntegrity?.toFields(),
        'characterChangedAt': null,
        'canApproveApplications': true,
        'updatedAt': serverTimestamp,
      },
      assignment: {
        'schemaVersion': 1,
        'playerId': playerId,
        'characterId': command.leaderCharacterId,
        'raidId': metadata.raidId,
        'recruitmentId': command.recruitmentId,
        'cycleKey': command.cycleKey,
        'role': command.leaderRole.name,
        'createdAt': serverTimestamp,
        'updatedAt': serverTimestamp,
      },
    );
  }

  final Map<String, Object?> recruitment;
  final Map<String, Object?> leaderMembership;
  final Map<String, Object?> assignment;

  static Map<String, Object?> _approvalPolicy(PartyCreateCommand command) => {
    'mode': command.approvalPolicy.mode.name,
    'requiredApprovals': command.approvalPolicy.requiredApprovals,
    'leaderVoteRequired': command.approvalPolicy.leaderVoteRequired,
    'rejectionMode': command.approvalPolicy.rejectionMode.name,
  };
}
