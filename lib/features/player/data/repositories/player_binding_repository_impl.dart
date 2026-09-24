import '../../domain/entities/player_session.dart';
import '../../domain/repositories/player_binding_repository.dart';
import '../datasources/player_binding_store.dart';

class PlayerBindingRepositoryImpl implements PlayerBindingRepository {
  PlayerBindingRepositoryImpl(this._store);

  final PlayerBindingStore _store;

  @override
  Future<PlayerSession?> getExisting({required String authUid}) async {
    final normalizedAuthUid = _normalizedAuthUid(authUid);
    final playerId = await _store.getExistingActivePlayerId(
      authUid: normalizedAuthUid,
    );
    if (playerId == null) return null;
    return PlayerSession(authUid: normalizedAuthUid, playerId: playerId);
  }

  @override
  Future<PlayerSession> getOrCreate({required String authUid}) async {
    final normalizedAuthUid = _normalizedAuthUid(authUid);
    final playerId = await _store.getOrCreateActivePlayerId(
      authUid: normalizedAuthUid,
    );
    return PlayerSession(authUid: normalizedAuthUid, playerId: playerId);
  }

  String _normalizedAuthUid(String authUid) {
    final normalized = authUid.trim();
    if (normalized.isEmpty) throw ArgumentError.value(authUid, 'authUid');
    return normalized;
  }
}
