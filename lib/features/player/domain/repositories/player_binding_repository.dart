import '../entities/player_session.dart';

abstract class PlayerBindingRepository {
  Future<PlayerSession?> getExisting({required String authUid});

  Future<PlayerSession> getOrCreate({required String authUid});
}
