// Models of Backend 254cb5d OpenAPI; never map these UUIDs to local PKs.
class ServerCharacterSummary {
  ServerCharacterSummary.fromJson(Map<String, dynamic> json) {
    _shape(
      json,
      [
        'server_name',
        'character_name',
        'class_name',
        'character_level',
        'item_level',
        'combat_power',
      ],
      [
        'server_name',
        'character_name',
        'class_name',
        'character_level',
        'item_level',
      ],
    );
    serverName = _text(json['server_name']);
    characterName = _text(json['character_name']);
    className = _text(json['class_name']);
    characterLevel = _integer(json['character_level']);
    itemLevel = json['item_level'] == null ? null : _text(json['item_level']);
    combatPower = json['combat_power'] == null
        ? null
        : _text(json['combat_power']);
  }
  late final String serverName;
  late final String characterName;
  late final String className;
  late final int characterLevel;
  late final String? itemLevel;
  late final String? combatPower;
}

class ServerCharacterSettings {
  ServerCharacterSettings.fromJson(Map<String, dynamic> json) {
    _shape(
      json,
      [
        'configuration_state',
        'activity_character_ids',
        'representative_character_id',
        'settings_version',
        'ownership_revision',
        'next_change_at',
        'selection_complete',
        'ineligible_character_ids',
      ],
      [
        'configuration_state',
        'activity_character_ids',
        'representative_character_id',
        'settings_version',
        'ownership_revision',
        'next_change_at',
        'ineligible_character_ids',
      ],
    );
    configurationState = _enum(json['configuration_state'], [
      'unconfigured',
      'configured',
      'needs_reconfiguration',
    ]);
    activityCharacterIds = _list(
      json['activity_character_ids'],
    ).map((value) => _uuid(value)).toList(growable: false);
    representativeCharacterId = json['representative_character_id'] == null
        ? null
        : _uuid(json['representative_character_id']);
    settingsVersion = _integer(json['settings_version']);
    ownershipRevision = json['ownership_revision'] == null
        ? null
        : _integer(json['ownership_revision']);
    nextChangeAt = json['next_change_at'] == null
        ? null
        : _time(json['next_change_at']);
    selectionComplete = _boolean(
      (json.containsKey('selection_complete')
          ? json['selection_complete']
          : true),
    );
    ineligibleCharacterIds = _list(
      json['ineligible_character_ids'],
    ).map((value) => _uuid(value)).toList(growable: false);
    if (!selectionComplete ||
        activityCharacterIds.length > 200 ||
        activityCharacterIds.toSet().length != activityCharacterIds.length ||
        ineligibleCharacterIds.toSet().length !=
            ineligibleCharacterIds.length) {
      throw const FormatException('Invalid selection.');
    }
  }
  late final String configurationState;
  late final List<String> activityCharacterIds;
  late final String? representativeCharacterId;
  late final int settingsVersion;
  late final int? ownershipRevision;
  late final DateTime? nextChangeAt;
  late final bool selectionComplete;
  late final List<String> ineligibleCharacterIds;
}

class ServerAccountRegistration {
  ServerAccountRegistration.fromJson(Map<String, dynamic> json) {
    _shape(
      json,
      [
        'registration_id',
        'label',
        'is_main',
        'version',
        'game_account_id',
        'verification_status',
        'ownership_status',
        'ownership_revision',
        'roster_revision',
        'settings',
        'representative_summary',
        'character_count',
        'server_fetched_at',
      ],
      [
        'registration_id',
        'label',
        'is_main',
        'version',
        'game_account_id',
        'verification_status',
        'ownership_status',
        'ownership_revision',
        'roster_revision',
        'settings',
        'representative_summary',
        'character_count',
        'server_fetched_at',
      ],
    );
    registrationId = _uuid(json['registration_id']);
    label = _text(json['label']);
    isMain = _boolean(json['is_main']);
    version = _integer(json['version']);
    gameAccountId = json['game_account_id'] == null
        ? null
        : _uuid(json['game_account_id']);
    verificationStatus = _enum(json['verification_status'], [
      'unverified',
      'verified',
    ]);
    ownershipStatus = _enum(json['ownership_status'], [
      'unverified',
      'owned',
      'ownership_lost',
    ]);
    ownershipRevision = json['ownership_revision'] == null
        ? null
        : _integer(json['ownership_revision']);
    rosterRevision = json['roster_revision'] == null
        ? null
        : _integer(json['roster_revision']);
    settings = ServerCharacterSettings.fromJson(_map(json['settings']));
    representativeSummary = json['representative_summary'] == null
        ? null
        : ServerCharacterSummary.fromJson(_map(json['representative_summary']));
    characterCount = _integer(json['character_count']);
    serverFetchedAt = _time(json['server_fetched_at']);
  }
  late final String registrationId;
  late final String label;
  late final bool isMain;
  late final int version;
  late final String? gameAccountId;
  late final String verificationStatus;
  late final String ownershipStatus;
  late final int? ownershipRevision;
  late final int? rosterRevision;
  late final ServerCharacterSettings settings;
  late final ServerCharacterSummary? representativeSummary;
  late final int characterCount;
  late final DateTime serverFetchedAt;
}

class ServerRegistrationPage {
  ServerRegistrationPage.fromJson(Map<String, dynamic> json) {
    _shape(json, ['items', 'next_cursor'], ['items', 'next_cursor']);
    items = _list(json['items'])
        .map((value) => ServerAccountRegistration.fromJson(_map(value)))
        .toList(growable: false);
    nextCursor = json['next_cursor'] == null
        ? null
        : _text(json['next_cursor']);
  }
  late final List<ServerAccountRegistration> items;
  late final String? nextCursor;
}

class ServerAccountCharacter {
  ServerAccountCharacter.fromJson(Map<String, dynamic> json) {
    _shape(
      json,
      [
        'server_name',
        'character_name',
        'class_name',
        'character_level',
        'item_level',
        'combat_power',
        'character_id',
        'roster_status',
        'summary_fetched_at',
        'last_confirmed_at',
        'requires_refresh',
        'eligible',
        'power_stale',
        'power_fetched_at',
      ],
      [
        'server_name',
        'character_name',
        'class_name',
        'character_level',
        'item_level',
        'character_id',
        'roster_status',
        'summary_fetched_at',
        'last_confirmed_at',
        'requires_refresh',
        'eligible',
        'power_fetched_at',
      ],
    );
    serverName = _text(json['server_name']);
    characterName = _text(json['character_name']);
    className = _text(json['class_name']);
    characterLevel = _integer(json['character_level']);
    itemLevel = json['item_level'] == null ? null : _text(json['item_level']);
    combatPower = json['combat_power'] == null
        ? null
        : _text(json['combat_power']);
    characterId = json['character_id'] == null
        ? null
        : _uuid(json['character_id']);
    rosterStatus = _enum(json['roster_status'], [
      'preview',
      'confirmed',
      'suspect',
      'missing',
    ]);
    summaryFetchedAt = _time(json['summary_fetched_at']);
    lastConfirmedAt = json['last_confirmed_at'] == null
        ? null
        : _time(json['last_confirmed_at']);
    requiresRefresh = _boolean(json['requires_refresh']);
    eligible = _boolean(json['eligible']);
    powerStale = _boolean(
      (json.containsKey('power_stale') ? json['power_stale'] : true),
    );
    powerFetchedAt = json['power_fetched_at'] == null
        ? null
        : _time(json['power_fetched_at']);
  }
  late final String serverName;
  late final String characterName;
  late final String className;
  late final int characterLevel;
  late final String? itemLevel;
  late final String? combatPower;
  late final String? characterId;
  late final String rosterStatus;
  late final DateTime summaryFetchedAt;
  late final DateTime? lastConfirmedAt;
  late final bool requiresRefresh;
  late final bool eligible;
  late final bool powerStale;
  late final DateTime? powerFetchedAt;
}

class ServerCharacterPage {
  ServerCharacterPage.fromJson(Map<String, dynamic> json) {
    _shape(json, ['items', 'next_cursor'], ['items', 'next_cursor']);
    items = _list(json['items'])
        .map((value) => ServerAccountCharacter.fromJson(_map(value)))
        .toList(growable: false);
    nextCursor = json['next_cursor'] == null
        ? null
        : _text(json['next_cursor']);
  }
  late final List<ServerAccountCharacter> items;
  late final String? nextCursor;
}

class ServerCharactersResponse {
  ServerCharactersResponse.fromJson(Map<String, dynamic> json) {
    _shape(
      json,
      [
        'characters',
        'settings',
        'ownership_status',
        'roster_revision',
        'server_fetched_at',
      ],
      [
        'characters',
        'settings',
        'ownership_status',
        'roster_revision',
        'server_fetched_at',
      ],
    );
    characters = ServerCharacterPage.fromJson(_map(json['characters']));
    settings = ServerCharacterSettings.fromJson(_map(json['settings']));
    ownershipStatus = _enum(json['ownership_status'], [
      'unverified',
      'owned',
      'ownership_lost',
    ]);
    rosterRevision = _integer(json['roster_revision']);
    serverFetchedAt = _time(json['server_fetched_at']);
  }
  late final ServerCharacterPage characters;
  late final ServerCharacterSettings settings;
  late final String ownershipStatus;
  late final int rosterRevision;
  late final DateTime serverFetchedAt;
}

void _shape(
  Map<String, dynamic> json,
  List<String> allowed,
  List<String> required,
) {
  if (required.any((key) => !json.containsKey(key)) ||
      json.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('Invalid account response.');
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid object.');
  }
  return value;
}

List<dynamic> _list(Object? value) {
  if (value is! List || value.length > 200) {
    throw const FormatException('Invalid list.');
  }
  return value;
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid text.');
  }
  return value;
}

String _uuid(Object? value) {
  final text = _text(value);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(text)) {
    throw const FormatException('Invalid ID.');
  }
  return text.toLowerCase();
}

int _integer(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid integer.');
  }
  return value;
}

bool _boolean(Object? value) {
  if (value is! bool) throw const FormatException('Invalid boolean.');
  return value;
}

String _enum(Object? value, List<String> allowed) {
  final text = _text(value);
  if (!allowed.contains(text)) throw const FormatException('Invalid state.');
  return text;
}

DateTime _time(Object? value) {
  final text = _text(value);
  if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text)) {
    throw const FormatException('Missing time zone.');
  }
  return DateTime.parse(text).toUtc();
}

/// Fully collected, consistent read snapshot. Not a writable activity draft.
class ServerAccountRoster {
  ServerAccountRoster(
    ServerCharactersResponse first,
    Iterable<ServerAccountCharacter> items,
  ) : characters = List.unmodifiable(items),
      settings = first.settings,
      ownershipStatus = first.ownershipStatus,
      rosterRevision = first.rosterRevision,
      serverFetchedAt = first.serverFetchedAt;
  final List<ServerAccountCharacter> characters;
  final ServerCharacterSettings settings;
  final String ownershipStatus;
  final int rosterRevision;
  final DateTime serverFetchedAt;
}
