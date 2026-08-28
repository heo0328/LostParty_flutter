abstract interface class PlayerActivityRepository {
  Future<void> recordAppLaunch({required String playerId});
}
