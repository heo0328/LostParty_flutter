import 'dart:convert';

/// These are normalized storage records, not Backend wire DTOs.
class ScopedCacheException implements Exception {
  const ScopedCacheException(this.code);
  final String code;
  @override
  String toString() => 'ScopedCacheException($code)';
}

String cacheUuid(String value) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    throw const ScopedCacheException('INVALID_ID');
  }
  return value.toLowerCase();
}

void cacheRequire(bool condition, [String code = 'INVALID_SNAPSHOT']) {
  if (!condition) throw ScopedCacheException(code);
}

class StorageScope {
  factory StorageScope({
    required String baseUrl,
    required String userId,
    bool allowHttp = false,
  }) {
    final uri = Uri.tryParse(baseUrl);
    cacheRequire(
      uri != null &&
          uri.hasAuthority &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !uri.hasQuery &&
          !uri.hasFragment &&
          (uri.scheme == 'https' || (allowHttp && uri.scheme == 'http')),
      'INVALID_ENVIRONMENT',
    );
    final parsed = uri!;
    final normalized = parsed.replace(
      scheme: parsed.scheme.toLowerCase(),
      host: parsed.host.toLowerCase(),
      path: parsed.path == '/' ? '' : parsed.path,
    );
    return StorageScope._(normalized.toString(), cacheUuid(userId));
  }
  const StorageScope._(this.environment, this.userId);
  final String environment, userId;
  @override
  bool operator ==(Object other) =>
      other is StorageScope &&
      other.environment == environment &&
      other.userId == userId;
  @override
  int get hashCode => Object.hash(environment, userId);
}

class ScopedRegistrationRef {
  ScopedRegistrationRef(this.scope, String registrationId)
    : registrationId = cacheUuid(registrationId);
  final StorageScope scope;
  final String registrationId;
}

class ScopedCharacterRef {
  ScopedCharacterRef(
    this.scope, {
    required String accountId,
    required String characterId,
  }) : accountId = cacheUuid(accountId),
       characterId = cacheUuid(characterId);
  final StorageScope scope;
  final String accountId, characterId;
}

class CacheSettings {
  CacheSettings({
    required this.version,
    required this.state,
    required List<String> activityIds,
    required String? representativeId,
  }) : activityIds = List.unmodifiable(activityIds.map(cacheUuid)),
       representativeId = representativeId == null
           ? null
           : cacheUuid(representativeId) {
    cacheRequire(
      version >= 0 &&
          {
            'unconfigured',
            'configured',
            'needs_reconfiguration',
          }.contains(state),
    );
    cacheRequire(
      this.activityIds.length <= 200 &&
          this.activityIds.toSet().length == this.activityIds.length,
    );
  }
  final int version;
  final String state;
  final List<String> activityIds;
  final String? representativeId;
  Map<String, Object?> toStorage() => {
    'version': version,
    'state': state,
    'activity': activityIds,
    'representative': representativeId,
  };
  factory CacheSettings.fromStorage(Map<String, dynamic> json) => CacheSettings(
    version: json['version'] as int,
    state: json['state'] as String,
    activityIds: (json['activity'] as List).cast<String>(),
    representativeId: json['representative'] as String?,
  );
}

class CacheRegistrationSnapshot {
  CacheRegistrationSnapshot({
    required String registrationId,
    required String? accountId,
    required this.version,
    required this.isMain,
    required this.label,
    required this.ownershipStatus,
    required this.ownershipRevision,
    required this.rosterRevision,
    required this.settings,
    required this.fetchedAt,
    required this.sourceContract,
    Map<String, dynamic> display = const {},
  }) : registrationId = cacheUuid(registrationId),
       accountId = accountId == null ? null : cacheUuid(accountId),
       displayJson = jsonEncode(display) {
    cacheRequire(
      version >= 1 &&
          rosterRevision >= 0 &&
          (ownershipRevision == null || ownershipRevision! >= 1) &&
          fetchedAt.isUtc &&
          sourceContract.isNotEmpty &&
          {'unverified', 'owned', 'ownership_lost'}.contains(ownershipStatus),
    );
    cacheRequire(
      ownershipStatus != 'owned' ||
          (this.accountId != null && ownershipRevision != null),
    );
  }
  final String registrationId,
      label,
      ownershipStatus,
      sourceContract,
      displayJson;
  final String? accountId;
  final int version, rosterRevision;
  final int? ownershipRevision;
  final bool isMain;
  final CacheSettings settings;
  final DateTime fetchedAt;
  Map<String, Object?> toStorage() => {
    'registration': registrationId,
    'account': accountId,
    'version': version,
    'main': isMain,
    'label': label,
    'ownership': ownershipStatus,
    'ownershipRevision': ownershipRevision,
    'rosterRevision': rosterRevision,
    'settings': settings.toStorage(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'source': sourceContract,
    'display': jsonDecode(displayJson),
  };
  factory CacheRegistrationSnapshot.fromStorage(Map<String, dynamic> json) =>
      CacheRegistrationSnapshot(
        registrationId: json['registration'] as String,
        accountId: json['account'] as String?,
        version: json['version'] as int,
        isMain: json['main'] as bool,
        label: json['label'] as String,
        ownershipStatus: json['ownership'] as String,
        ownershipRevision: json['ownershipRevision'] as int?,
        rosterRevision: json['rosterRevision'] as int,
        settings: CacheSettings.fromStorage(
          json['settings'] as Map<String, dynamic>,
        ),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        sourceContract: json['source'] as String,
        display: json['display'] as Map<String, dynamic>,
      );

  bool sameStructure(CacheRegistrationSnapshot other) =>
      registrationId == other.registrationId &&
      accountId == other.accountId &&
      version == other.version &&
      label == other.label &&
      isMain == other.isMain &&
      ownershipStatus == other.ownershipStatus &&
      ownershipRevision == other.ownershipRevision &&
      rosterRevision == other.rosterRevision &&
      settings.version == other.settings.version &&
      settings.state == other.settings.state &&
      settings.representativeId == other.settings.representativeId &&
      settings.activityIds.length == other.settings.activityIds.length &&
      settings.activityIds.toSet().containsAll(other.settings.activityIds);
}

class CacheCharacterObservation {
  CacheCharacterObservation({
    required String characterId,
    required String accountId,
    required this.serverName,
    required this.characterName,
    required this.lifecycleState,
    required this.lifecycleRevision,
    required this.usable,
    required this.blockedReason,
    Map<String, dynamic> profile = const {},
  }) : characterId = cacheUuid(characterId),
       accountId = cacheUuid(accountId),
       profileJson = jsonEncode(profile) {
    cacheRequire(
      serverName.isNotEmpty &&
          characterName.isNotEmpty &&
          (lifecycleRevision == null || lifecycleRevision! >= 1) &&
          (lifecycleState == null ||
              {'active', 'suspect', 'retired'}.contains(lifecycleState)),
    );
    cacheRequire((lifecycleState == null) == (lifecycleRevision == null));
    cacheRequire(
      usable != true || (lifecycleState == 'active' && blockedReason == null),
    );
  }
  final String characterId, accountId, serverName, characterName, profileJson;
  final String? lifecycleState, blockedReason;
  final int? lifecycleRevision;
  final bool? usable;
  Map<String, Object?> toStorage() => {
    'id': characterId,
    'account': accountId,
    'server': serverName,
    'name': characterName,
    'lifecycle': lifecycleState,
    'revision': lifecycleRevision,
    'usable': usable,
    'blocked': blockedReason,
    'profile': jsonDecode(profileJson),
  };
  factory CacheCharacterObservation.fromStorage(Map<String, dynamic> json) =>
      CacheCharacterObservation(
        characterId: json['id'] as String,
        accountId: json['account'] as String,
        serverName: json['server'] as String,
        characterName: json['name'] as String,
        lifecycleState: json['lifecycle'] as String?,
        lifecycleRevision: json['revision'] as int?,
        usable: json['usable'] as bool?,
        blockedReason: json['blocked'] as String?,
        profile: json['profile'] as Map<String, dynamic>,
      );
}

class CacheRosterSnapshot {
  CacheRosterSnapshot(
    this.registration,
    Iterable<CacheCharacterObservation> items,
  ) : characters = List.unmodifiable(items) {
    cacheRequire(
      characters.length <= 200 &&
          characters.map((c) => c.characterId).toSet().length ==
              characters.length,
    );
    cacheRequire(
      characters.every((c) => c.accountId == registration.accountId),
    );
    cacheRequire(registration.ownershipStatus == 'owned' || characters.isEmpty);
  }
  final CacheRegistrationSnapshot registration;
  final List<CacheCharacterObservation> characters;
}
