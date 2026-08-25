import '../../domain/entities/party_recruitment.dart';

class PartyJoinWritePlan {
  const PartyJoinWritePlan({
    required this.recruitmentUpdate,
    required this.membership,
    required this.assignment,
  });

  factory PartyJoinWritePlan.create({
    required String recruitmentId,
    required String playerId,
    required String characterId,
    required String characterName,
    required String className,
    required double itemLevel,
    required double? combatPower,
    required PartyRole role,
    required int partyIndex,
    required String joinedBy,
    required String raidId,
    required String cycleKey,
    required int memberCount,
    required List<String> memberPlayerIds,
    required int maxMemberCount,
    required int dealerCount,
    required int supportCount,
    required int revision,
    required Object serverTimestamp,
  }) => PartyJoinWritePlan(
    recruitmentUpdate: {
      'memberPlayerIds': [...memberPlayerIds, playerId],
      'memberCount': memberCount + 1,
      'dealerCount': dealerCount + (role == PartyRole.dealer ? 1 : 0),
      'supportCount': supportCount + (role == PartyRole.support ? 1 : 0),
      'hasAvailableSlot': memberCount + 1 < maxMemberCount,
      'revision': revision + 1,
      'updatedAt': serverTimestamp,
    },
    membership: {
      'schemaVersion': 1,
      'playerId': playerId,
      'characterId': characterId,
      'characterNameSnapshot': characterName,
      'classNameSnapshot': className,
      'role': role.name,
      'partyIndex': partyIndex,
      'joinedAt': serverTimestamp,
      'joinedBy': joinedBy,
      'submittedBuildSnapshotId': null,
      'itemLevelSnapshot': itemLevel,
      'combatPowerSnapshot': combatPower,
      'characterChangedAt': null,
      'canApproveApplications': false,
      'updatedAt': serverTimestamp,
    },
    assignment: {
      'schemaVersion': 1,
      'playerId': playerId,
      'characterId': characterId,
      'raidId': raidId,
      'recruitmentId': recruitmentId,
      'cycleKey': cycleKey,
      'role': role.name,
      'createdAt': serverTimestamp,
      'updatedAt': serverTimestamp,
    },
  );

  final Map<String, Object?> recruitmentUpdate;
  final Map<String, Object?> membership;
  final Map<String, Object?> assignment;
}
