/// Fields already exposed by the group recruitment read model. New source
/// fields require an explicit privacy review before they can enter a listing.
const partyRaidListingFields = <String>{
  'schemaVersion',
  'recruitmentId',
  'title',
  'leaderPlayerId',
  'leaderCharacterNameSnapshot',
  'leaderClassNameSnapshot',
  'memberPlayerIds',
  'raidCatalogVersion',
  'raidId',
  'difficultyId',
  'raidNameSnapshot',
  'difficultyNameSnapshot',
  'difficultyAliasSnapshot',
  'gateCount',
  'minItemLevel',
  'minCombatPower',
  'experienceLevel',
  'maxPlayHours',
  'raidStartAt',
  'status',
  'visibility',
  'groupId',
  'approvalPolicy',
  'continueTogether',
  'manualRecruitmentEnabled',
  'hasAvailableSlot',
  'currentCycleKey',
  'targetCycleKey',
  'currentCycleStatus',
  'cycleStartedAt',
  'cycleEndsAt',
  'partyCount',
  'membersPerParty',
  'supportsPerParty',
  'maxDealersPerClassPerParty',
  'slotLedgerVersion',
  'memberCount',
  'maxMemberCount',
  'dealerCount',
  'supportCount',
  'revision',
  'createdAt',
  'updatedAt',
  'completedAt',
  'completedByPlayerId',
  'partySlots',
  'nonGroupMemberCount',
  'pendingApplicationCount',
  'pendingNonGroupApplicantCount',
  'raidStateTargets',
  'commandTargets',
  'groupActiveRecruitmentCountAfter',
  'lastCommandId',
  'lastCommandType',
  'lastCommandActorPlayerId',
  'lastCommandAt',
  'ownershipCleanup',
};

/// Copy the transaction's final source, never the previous listing. Callers
/// supply concrete counters/revisions; server timestamps may remain transforms.
Map<String, Object?> partyRaidListingDocument({
  required Map<String, Object?> currentRecruitment,
  Map<String, Object?> recruitmentPatch = const {},
}) {
  final after = <String, Object?>{...currentRecruitment, ...recruitmentPatch};
  if (!partyRaidListingFields.containsAll(after.keys)) {
    throw StateError('모집 목록에 허용되지 않은 원본 필드가 있습니다.');
  }
  return Map.unmodifiable(after);
}
