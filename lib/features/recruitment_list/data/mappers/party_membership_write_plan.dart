class PartyMembershipWritePlan {
  const PartyMembershipWritePlan._();

  static Map<String, Object?> changeCharacter({
    required String characterId,
    required String characterName,
    required String className,
    required String role,
    required double itemLevel,
    required double? combatPower,
    required Object serverTimestamp,
  }) => {
    'characterId': characterId,
    'characterNameSnapshot': characterName,
    'classNameSnapshot': className,
    'role': role,
    'itemLevelSnapshot': itemLevel,
    'combatPowerSnapshot': combatPower,
    'characterChangedAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> leaderDisplaySnapshots({
    required String characterName,
    required String className,
    required int revision,
    required Object serverTimestamp,
    required int dealerCount,
    required int supportCount,
  }) => {
    'leaderCharacterNameSnapshot': characterName,
    'leaderClassNameSnapshot': className,
    'dealerCount': dealerCount,
    'supportCount': supportCount,
    'revision': revision + 1,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> setApprovalPermission({
    required bool enabled,
    required Object serverTimestamp,
  }) => {'canApproveApplications': enabled, 'updatedAt': serverTimestamp};

  static Map<String, Object?> removeFromRecruitment({
    required List<String> memberPlayerIds,
    required String targetPlayerId,
    required int memberCount,
    required int dealerCount,
    required int supportCount,
    required String targetRole,
    required int maxMemberCount,
    required int revision,
    required String? nextLeaderPlayerId,
    required String? nextLeaderCharacterName,
    required String? nextLeaderClassName,
    required Object serverTimestamp,
  }) {
    final remaining = memberPlayerIds
        .where((id) => id != targetPlayerId)
        .toList(growable: false);
    final disbanded = remaining.isEmpty;
    return {
      'memberPlayerIds': remaining,
      'memberCount': memberCount - 1,
      'dealerCount': dealerCount - (targetRole == 'dealer' ? 1 : 0),
      'supportCount': supportCount - (targetRole == 'support' ? 1 : 0),
      'leaderPlayerId': nextLeaderPlayerId,
      'leaderCharacterNameSnapshot': nextLeaderCharacterName,
      'leaderClassNameSnapshot': nextLeaderClassName,
      'hasAvailableSlot': !disbanded && memberCount - 1 < maxMemberCount,
      if (disbanded) 'status': 'disbanded',
      if (disbanded) 'manualRecruitmentEnabled': false,
      'revision': revision + 1,
      'updatedAt': serverTimestamp,
    };
  }
}
