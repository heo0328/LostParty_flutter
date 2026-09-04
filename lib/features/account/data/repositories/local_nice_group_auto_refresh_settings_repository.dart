import '../../domain/repositories/nice_group_auto_refresh_settings_repository.dart';
import '../local/account_database.dart';

class LocalNiceGroupAutoRefreshSettingsRepository
    implements NiceGroupAutoRefreshSettingsRepository {
  const LocalNiceGroupAutoRefreshSettingsRepository({required this.database});

  final AccountDatabase database;

  @override
  Future<bool> loadEnabled({required String playerId}) =>
      database.loadNiceGroupAutoRefreshEnabled(playerId);

  @override
  Future<void> saveEnabled({required String playerId, required bool enabled}) =>
      database.saveNiceGroupAutoRefreshEnabled(
        playerId: playerId,
        enabled: enabled,
      );
}
