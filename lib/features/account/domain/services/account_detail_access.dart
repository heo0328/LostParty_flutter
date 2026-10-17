/// Registration/preview and device-local identities never establish ownership.
bool hasAccountDetailAccess({
  required String ownershipStatus,
  required String? accountId,
  required int? ownershipRevision,
}) =>
    ownershipStatus == 'owned' &&
    accountId != null &&
    ownershipRevision != null &&
    ownershipRevision >= 1;

/// Retain the wire shape while excluding cached detail from basic observations.
Map<String, dynamic> basicCharacterObservation(Map<String, dynamic> json) => {
  ...json,
  'combat_power': null,
  'power_fetched_at': null,
  'power_checked_at': null,
  'power_stale': true,
  'power_status': 'unknown',
  'power_reason': null,
};
