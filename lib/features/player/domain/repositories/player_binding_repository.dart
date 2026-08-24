import '../entities/player_session.dart';

abstract class PlayerBindingRepository {
  Future<PlayerSession> getOrCreate({required String authUid});
}
