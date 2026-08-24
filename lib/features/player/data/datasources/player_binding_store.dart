abstract class PlayerBindingStore {
  Future<String> getOrCreateActivePlayerId({required String authUid});
}
