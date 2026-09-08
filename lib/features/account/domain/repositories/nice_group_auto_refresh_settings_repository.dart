abstract interface class NiceGroupAutoRefreshSettingsRepository {
  Future<bool> loadEnabled({required String playerId});

  Future<void> saveEnabled({required String playerId, required bool enabled});
}
