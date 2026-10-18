import 'services/account_detail_access.dart';
import 'scoped_cache_models.dart';
import 'server_account_models.dart';

const lifecycleContract = 'c91af2e003877daacb833aaa0c109eae11b72816';

void _require(bool value) {
  if (!value) throw const FormatException('Invalid lifecycle response.');
}

Map<String, dynamic> _map(Object? value) {
  _require(value is Map<String, dynamic>);
  return value as Map<String, dynamic>;
}

void _shape(Map<String, dynamic> json, String fields) {
  final keys = fields.split(' ').toSet();
  _require(json.length == keys.length && keys.every(json.containsKey));
}

String _text(Object? value) {
  _require(value is String);
  return value as String;
}

String _uuid(Object? value) {
  try {
    return cacheUuid(_text(value));
  } on ScopedCacheException {
    throw const FormatException('Invalid UUID.');
  }
}

int _positive(Object? value) {
  _require(value is int && value >= 1);
  return value as int;
}

DateTime _utc(Object? value) {
  final raw = _text(value);
  _require(
    RegExp(
      r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|\+00:00)$',
    ).hasMatch(raw),
  );
  final time = DateTime.parse(raw);
  // DateTime.parse normalizes invalid calendar dates; reject that rollover.
  _require(time.toIso8601String().substring(0, 19) == raw.substring(0, 19));
  return time.toUtc();
}

String? lifecycleCursor(Object? value) {
  if (value == null) return null;
  final cursor = _text(value);
  _require(cursor.isNotEmpty && cursor.length <= 2048);
  return cursor;
}

List<dynamic> _items(Object? value, {int maximum = 50}) {
  _require(value is List && value.length <= maximum);
  return value as List;
}

dynamic _freeze(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
      value.map((k, v) => MapEntry(k, _freeze(v))),
    );
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}

/// Immutable wire observations, separate from local integer IDs and permissions.
class LifecycleCharacter {
  LifecycleCharacter.fromJson(
    Map<String, dynamic> json, {
    bool basicOnly = false,
  }) {
    _shape(
      json,
      'server_name character_name class_name character_level item_level combat_power character_id roster_status summary_fetched_at last_confirmed_at requires_refresh eligible power_stale power_fetched_at power_checked_at power_status power_reason lifecycle_state lifecycle_revision usable blocked_reason',
    );
    final observation = Map<String, dynamic>.of(json)
      ..remove('lifecycle_state')
      ..remove('lifecycle_revision')
      ..remove('usable')
      ..remove('blocked_reason');
    ServerAccountCharacter.fromJson(observation);
    _utc(json['summary_fetched_at']);
    for (final key in [
      'last_confirmed_at',
      'power_fetched_at',
      'power_checked_at',
    ]) {
      if (json[key] != null) _utc(json[key]);
    }
    _require(
      {
        'preview',
        'active',
        'suspect',
        'retired',
      }.contains(json['lifecycle_state']),
    );
    _require(json['usable'] is bool);
    _require(
      json['blocked_reason'] == null ||
          {
            'OWNERSHIP_REQUIRED',
            'CHARACTER_UNUSABLE',
            'IDENTITY_CONFLICT',
          }.contains(json['blocked_reason']),
    );
    if (json['character_id'] != null) _uuid(json['character_id']);
    if (json['lifecycle_revision'] != null) {
      _positive(json['lifecycle_revision']);
    }
    if (json['lifecycle_state'] == 'preview') {
      _require(
        json['character_id'] == null &&
            json['lifecycle_revision'] == null &&
            json['usable'] == false &&
            json['blocked_reason'] == 'OWNERSHIP_REQUIRED',
      );
    } else {
      _require(
        json['character_id'] != null && json['lifecycle_revision'] != null,
      );
      _require(
        json['usable'] != true ||
            (json['lifecycle_state'] == 'active' &&
                json['blocked_reason'] == null),
      );
      _require(json['usable'] != false || json['blocked_reason'] != null);
    }
    wire =
        _freeze(basicOnly ? basicCharacterObservation(json) : json)
            as Map<String, dynamic>;
  }
  late final Map<String, dynamic> wire;
  String? get characterId =>
      wire['character_id'] == null ? null : _uuid(wire['character_id']);
  String get serverName => wire['server_name'] as String;
  String get characterName => wire['character_name'] as String;
  String get lifecycleState => wire['lifecycle_state'] as String;
  int? get lifecycleRevision => wire['lifecycle_revision'] as int?;
  bool get usable => wire['usable'] as bool;
  String? get blockedReason => wire['blocked_reason'] as String?;
}

class LifecycleCharacterPage {
  LifecycleCharacterPage.fromJson(
    Map<String, dynamic> json, {
    int maximumItems = 50,
  }) {
    _shape(
      json,
      'registration_id game_account_id is_main registration_version ownership_status ownership_revision roster_revision settings items next_cursor server_fetched_at',
    );
    registrationId = _uuid(json['registration_id']);
    accountId = json['game_account_id'] == null
        ? null
        : _uuid(json['game_account_id']);
    _require(json['is_main'] is bool);
    isMain = json['is_main'] as bool;
    version = _positive(json['registration_version']);
    ownershipStatus = _text(json['ownership_status']);
    _require(
      {'unverified', 'owned', 'ownership_lost'}.contains(ownershipStatus),
    );
    ownershipRevision = json['ownership_revision'] == null
        ? null
        : _positive(json['ownership_revision']);
    rosterRevision = _positive(json['roster_revision']);
    settings = ServerCharacterSettings.fromJson(_map(json['settings']));
    if (settings.nextChangeAt != null) {
      _utc(_map(json['settings'])['next_change_at']);
    }
    settingsWire =
        _freeze({
              ..._map(json['settings']),
              'selection_complete': settings.selectionComplete,
              'next_change_at': settings.nextChangeAt?.toIso8601String(),
            })
            as Map<String, dynamic>;
    _require(maximumItems == 50 || maximumItems == 200);
    items = List.unmodifiable(
      _items(json['items'], maximum: maximumItems).map(
        (item) => LifecycleCharacter.fromJson(
          _map(item),
          basicOnly: ownershipStatus != 'owned',
        ),
      ),
    );
    nextCursor = lifecycleCursor(json['next_cursor']);
    fetchedAt = _utc(json['server_fetched_at']);
    _require(
      ownershipStatus != 'owned' ||
          (accountId != null && ownershipRevision != null),
    );
    for (final item in items) {
      _require(item.lifecycleState != 'retired');
      _require(
        ownershipStatus == 'owned'
            ? item.lifecycleState != 'preview'
            : item.lifecycleState == 'preview',
      );
    }
  }
  late final String registrationId, ownershipStatus;
  late final String? accountId, nextCursor;
  late final bool isMain;
  late final int version, rosterRevision;
  late final int? ownershipRevision;
  late final DateTime fetchedAt;
  late final ServerCharacterSettings settings;
  late final Map<String, dynamic> settingsWire;
  late final List<LifecycleCharacter> items;

  CacheRegistrationSnapshot registration(
    String label, [
    Iterable<LifecycleCharacter> characters = const [],
  ]) => CacheRegistrationSnapshot(
    registrationId: registrationId,
    accountId: accountId,
    version: version,
    isMain: isMain,
    label: label,
    ownershipStatus: ownershipStatus,
    ownershipRevision: ownershipRevision,
    rosterRevision: rosterRevision,
    settings: CacheSettings(
      version: settings.settingsVersion,
      state: settings.configurationState,
      activityIds: settings.activityCharacterIds,
      representativeId: settings.representativeCharacterId,
    ),
    fetchedAt: fetchedAt,
    sourceContract: lifecycleContract,
    display: {
      'settings': settingsWire,
      'preview': characters
          .where((c) => c.characterId == null)
          .map((c) => c.wire)
          .toList(),
    },
  );

  /// Compare all settings fields, allowing set ordering and optional default.
  bool sameStructure(LifecycleCharacterPage other) =>
      registration('').sameStructure(other.registration('')) &&
      sameLifecycleSettings(settingsWire, other.settingsWire);
}

bool sameLifecycleSettings(Map<String, dynamic> a, Map<String, dynamic> b) {
  for (final key in a.keys) {
    final x = a[key], y = b[key];
    if (x is List && y is List) {
      if (x.length != y.length || !x.toSet().containsAll(y)) return false;
    } else if (x != y) {
      return false;
    }
  }
  return a.length == b.length;
}

class CharacterRetirement {
  CharacterRetirement.fromJson(Map<String, dynamic> json) {
    _shape(
      json,
      'history_id character_id game_account_id server_name character_name class_name combat_power item_level power_fetched_at item_level_fetched_at retired_at lifecycle_revision',
    );
    historyId = _uuid(json['history_id']);
    characterId = _uuid(json['character_id']);
    accountId = _uuid(json['game_account_id']);
    for (final key in ['server_name', 'character_name', 'class_name']) {
      _text(json[key]);
    }
    for (final key in ['combat_power', 'item_level']) {
      if (json[key] != null) _text(json[key]);
    }
    for (final key in ['power_fetched_at', 'item_level_fetched_at']) {
      if (json[key] != null) _utc(json[key]);
    }
    retiredAt = _utc(json['retired_at']);
    lifecycleRevision = _positive(json['lifecycle_revision']);
    wire = _freeze(json) as Map<String, dynamic>;
  }
  late final String historyId, characterId, accountId;
  late final DateTime retiredAt;
  late final int lifecycleRevision;
  late final Map<String, dynamic> wire;
  String get serverName => wire['server_name'] as String;
  String get characterName => wire['character_name'] as String;
  String get className => wire['class_name'] as String;
  String? get combatPower => wire['combat_power'] as String?;
  String? get itemLevel => wire['item_level'] as String?;
  DateTime? get powerFetchedAt =>
      wire['power_fetched_at'] == null ? null : _utc(wire['power_fetched_at']);
  DateTime? get itemLevelFetchedAt => wire['item_level_fetched_at'] == null
      ? null
      : _utc(wire['item_level_fetched_at']);
}

class CharacterRetirementPage {
  CharacterRetirementPage.fromJson(Map<String, dynamic> json) {
    _shape(json, 'items next_cursor history_revision');
    items = List.unmodifiable(
      _items(
        json['items'],
      ).map((item) => CharacterRetirement.fromJson(_map(item))),
    );
    nextCursor = lifecycleCursor(json['next_cursor']);
    revision = _positive(json['history_revision']);
    _require(
      items.map((item) => item.historyId).toSet().length == items.length,
    );
  }
  late final List<CharacterRetirement> items;
  late final String? nextCursor;
  late final int revision;
}
