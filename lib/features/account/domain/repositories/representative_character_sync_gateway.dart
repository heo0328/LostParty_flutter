class RepresentativeCharacterSyncState {
  const RepresentativeCharacterSyncState({
    required this.representativeCharacterId,
    required this.updatedAt,
  });

  static const cooldown = Duration(minutes: 5);

  final String? representativeCharacterId;
  final DateTime? updatedAt;

  DateTime? get nextChangeAt => updatedAt?.add(cooldown);

  Duration remainingAt(DateTime now) {
    final next = nextChangeAt;
    if (next == null || !next.isAfter(now)) return Duration.zero;
    return next.difference(now);
  }
}

class RepresentativeCharacterSyncException implements Exception {
  const RepresentativeCharacterSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class RepresentativeCharacterSyncGateway {
  Future<RepresentativeCharacterSyncState> loadState({
    required String gameAccountId,
  });

  Future<RepresentativeCharacterSyncState> setRepresentative({
    required String gameAccountId,
    required String characterId,
  });

  /// First fill when the server representative is empty. Does not start cooldown.
  Future<RepresentativeCharacterSyncState> seedRepresentative({
    required String gameAccountId,
    required String characterId,
  });
}
