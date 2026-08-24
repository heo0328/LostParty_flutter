import '../../domain/entities/player_session.dart';
import '../../domain/repositories/player_binding_repository.dart';
import '../datasources/player_binding_store.dart';

class PlayerBindingRepositoryImpl implements PlayerBindingRepository {
  PlayerBindingRepositoryImpl(this._store);

  final PlayerBindingStore _store;

  @override
  Future<PlayerSession> getOrCreate({required String authUid}) async {
    final normalizedAuthUid = authUid.trim();
    if (normalizedAuthUid.isEmpty) {
      throw ArgumentError.value(authUid, 'authUid');
    }
    final playerId = await _store.getOrCreateActivePlayerId(
      authUid: normalizedAuthUid,
    );
    return PlayerSession(authUid: normalizedAuthUid, playerId: playerId);
  }
}
