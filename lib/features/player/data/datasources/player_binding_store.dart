abstract class PlayerBindingStore {
  Future<String?> getExistingActivePlayerId({required String authUid});

  Future<String> getOrCreateActivePlayerId({required String authUid});
}
