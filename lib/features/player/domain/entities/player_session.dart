class PlayerSession {
  PlayerSession({required this.authUid, required this.playerId}) {
    _requireNotBlank(authUid, 'authUid');
    _requireNotBlank(playerId, 'playerId');
  }

  final String authUid;
  final String playerId;

  static void _requireNotBlank(String value, String name) {
    if (value.trim().isEmpty) throw ArgumentError.value(value, name);
  }
}
