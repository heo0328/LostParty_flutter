import '../../features/player/domain/entities/player_session.dart';

sealed class AppStartupResult {
  const AppStartupResult();
}

class AppStartupReady extends AppStartupResult {
  const AppStartupReady(this.session);

  final PlayerSession session;
}

class AppStartupAuthenticationRequired extends AppStartupResult {
  const AppStartupAuthenticationRequired();
}
