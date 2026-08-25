abstract interface class AccountOwnershipStatusGateway {
  Future<Map<String, String>> loadStatuses(Iterable<String> gameAccountIds);
}
