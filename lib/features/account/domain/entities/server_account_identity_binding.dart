class ServerAccountIdentityBinding {
  ServerAccountIdentityBinding({
    required this.localAccountId,
    required String serverGameAccountId,
    required Map<int, String> serverCharacterIdsByLocalId,
  }) : serverGameAccountId = _requireId(
         serverGameAccountId,
         'serverGameAccountId',
       ),
       serverCharacterIdsByLocalId = Map.unmodifiable(
         serverCharacterIdsByLocalId.map(
           (localId, serverId) =>
               MapEntry(localId, _requireId(serverId, 'serverCharacterId')),
         ),
       ) {
    if (localAccountId <= 0) {
      throw ArgumentError.value(
        localAccountId,
        'localAccountId',
        'Must be a positive local row ID.',
      );
    }
    if (this.serverCharacterIdsByLocalId.values.toSet().length !=
        this.serverCharacterIdsByLocalId.length) {
      throw ArgumentError.value(
        serverCharacterIdsByLocalId,
        'serverCharacterIdsByLocalId',
        'Server character IDs must be unique.',
      );
    }
  }

  final int localAccountId;
  final String serverGameAccountId;
  final Map<int, String> serverCharacterIdsByLocalId;

  static String _requireId(String value, String argumentName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, argumentName, 'Must not be blank.');
    }
    return normalized;
  }
}
