import 'dart:convert';

/// Current policy2 context; policy1 is accepted only for historical ACK recovery.
class CharacterManagementContext {
  static void validateCommandBody(Map<String, dynamic> body) {
    final policy2 = body.containsKey('policy_version');
    if (policy2) _require(body['policy_version'] == 'character-management-2');
    const fields =
        'activity_character_ids representative_character_id expected_registration_version expected_settings_version expected_ownership_revision expected_roster_revision expected_order_digest';
    final keys = fields.split(' ');
    _require(
      keys.every(body.containsKey) &&
          body.keys.every(
            (k) =>
                keys.contains(k) ||
                k == 'ordered_character_ids' ||
                (policy2 && k == 'policy_version'),
          ),
    );
    final selected = _ids(body['activity_character_ids'], 200);
    _require(
      selected.isNotEmpty &&
          (policy2 && body['representative_character_id'] == null ||
              selected.contains(_uuid(body['representative_character_id']))),
    );
    for (final key in keys.where(
      (k) => k.startsWith('expected_') && k != 'expected_order_digest',
    )) {
      _integer(body[key], 1);
    }
    _require(
      body['expected_order_digest'] is String &&
          RegExp(
            r'^[0-9a-f]{64}$',
          ).hasMatch(body['expected_order_digest'] as String),
    );
    if (body.containsKey('ordered_character_ids')) {
      final ordered = _ids(body['ordered_character_ids'], policy2 ? 200 : 199);
      final movable = selected
          .where((id) => id != body['representative_character_id'])
          .toSet();
      _require(
        (policy2 && body['representative_character_id'] == null) ||
            ordered.length == movable.length && movable.containsAll(ordered),
      );
    }
  }

  CharacterManagementContext.fromJson(
    Map<String, dynamic> json, {
    bool historical = false,
  }) {
    final policy2 = !historical;
    _closed(json, 'scope data');
    final s = json['scope'] as Map<String, dynamic>;
    final d = json['data'] as Map<String, dynamic>;
    _closed(
      s,
      'registration_id game_account_id registration_version settings_version ownership_revision roster_revision policy_version${policy2 ? ' is_main' : ''}',
    );
    _closed(
      d,
      'configuration_state activity_character_ids representative_character_id ordered_all_character_ids order_digest characters evaluated_at',
    );
    registrationId = _uuid(s['registration_id']);
    accountId = _uuid(s['game_account_id']);
    for (final key in [
      'registration_version',
      'settings_version',
      'ownership_revision',
      'roster_revision',
    ]) {
      _integer(s[key], 1);
    }
    _require(
      s['policy_version'] ==
          (policy2 ? 'character-management-2' : 'character-management-1'),
    );
    isMain = policy2 ? s['is_main'] as bool : false;
    _require(
      [
        'configured',
        'unconfigured',
        'needs_reconfiguration',
      ].contains(d['configuration_state']),
    );
    activityIds = _ids(d['activity_character_ids'], 200);
    representativeId = d['representative_character_id'] == null
        ? null
        : _uuid(d['representative_character_id']);
    if (policy2) _require(isMain || representativeId == null);
    orderedIds = _ids(d['ordered_all_character_ids'], 1000);
    _require(
      d['order_digest'] is String &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(d['order_digest'] as String),
    );
    final raw = d['characters'] as List;
    _require(raw.length == orderedIds.length);
    final parsed = <ManagementCharacter>[];
    for (var i = 0; i < raw.length; i++) {
      final row = ManagementCharacter.fromJson(
        raw[i] as Map<String, dynamic>,
        historical: historical,
      );
      _require(row.id == orderedIds[i]);
      parsed.add(row);
    }
    characters = List.unmodifiable(parsed);
    final at = d['evaluated_at'];
    _require(
      at is String &&
          RegExp(
            r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$',
          ).hasMatch(at),
    );
    final date = DateTime.tryParse(at as String);
    _require(
      date != null &&
          date.toUtc().toIso8601String().substring(0, 19) ==
              at.substring(0, 19),
    );
    // Freeze nested input too: callers cannot mutate CAS or queued commands.
    _json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  }
  late final Map<String, dynamic> _json;
  late final String registrationId, accountId;
  late final bool isMain;
  late final List<String> activityIds, orderedIds;
  late final String? representativeId;
  late final List<ManagementCharacter> characters;
  String get state => (_json['data'] as Map)['configuration_state'] as String;
  Map<String, dynamic> toJson() =>
      jsonDecode(jsonEncode(_json)) as Map<String, dynamic>;
  List<String> get residueIds =>
      activityIds.where((id) => !orderedIds.contains(id)).toList();

  String? automaticRepresentative(List<String> selected) {
    final candidates = characters
        .where((c) => selected.contains(c.id) && c.usable)
        .toList();
    if (candidates.any((c) => c.id == representativeId)) {
      return representativeId;
    }
    candidates.sort(
      (a, b) => compareManagementDecimal(a.level, b.level) == 0
          ? compareManagementDecimal(a.power, b.power) == 0
                ? a.name.compareTo(b.name) == 0
                      ? a.id.compareTo(b.id)
                      : a.name.compareTo(b.name)
                : compareManagementDecimal(a.power, b.power)
          : compareManagementDecimal(a.level, b.level),
    );
    return candidates.firstOrNull?.id;
  }

  Map<String, dynamic> command(
    List<String> selected,
    String? representative, {
    List<String>? ordered,
  }) {
    _ids(selected, 200);
    _require(
      selected.isNotEmpty &&
          (representative == null || selected.contains(representative)),
    );
    _require(isMain || representative == null);
    _require(
      selected.every((id) => characters.any((c) => c.id == id && c.usable)),
    );
    if (ordered != null) {
      _ids(ordered, isMain ? 199 : 200);
      final resolved = isMain
          ? representative ?? automaticRepresentative(selected)
          : null;
      final movable = selected.where((id) => id != resolved).toSet();
      _require(
        ordered.length == movable.length && movable.containsAll(ordered),
      );
    }
    final s = _json['scope'] as Map;
    return {
      'policy_version': 'character-management-2',
      'activity_character_ids': List<String>.of(selected),
      'representative_character_id': representative,
      for (final key in [
        'registration_version',
        'settings_version',
        'ownership_revision',
        'roster_revision',
      ])
        'expected_$key': s[key],
      'expected_order_digest': (_json['data'] as Map)['order_digest'],
      if (ordered != null) 'ordered_character_ids': List<String>.of(ordered),
    };
  }
}

class ManagementCharacter {
  ManagementCharacter.fromJson(
    Map<String, dynamic> json, {
    bool historical = false,
  }) {
    _closed(
      json,
      'character_id display_order item_level character_name usable blocked_reason${historical ? '' : ' combat_power item_level_observed_at combat_power_observed_at'}',
    );
    power = historical ? null : json['combat_power'] as String?;
    if (!historical) {
      for (final key in [
        'item_level_observed_at',
        'combat_power_observed_at',
      ]) {
        final at = json[key];
        _require(
          at == null ||
              at is String &&
                  RegExp(
                    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$',
                  ).hasMatch(at) &&
                  DateTime.tryParse(at) != null &&
                  DateTime.parse(
                        at,
                      ).toUtc().toIso8601String().substring(0, 19) ==
                      at.substring(0, 19),
        );
      }
      _require(
        power == null ||
            power!.length <= 64 &&
                RegExp(
                  r'^(?:0|[1-9][0-9]*)(?:\.[0-9]*[1-9])?$',
                ).hasMatch(power!),
      );
      _require((power == null) == (json['combat_power_observed_at'] == null));
    }
    id = _uuid(json['character_id']);
    rank = json['display_order'] == null
        ? null
        : _integer(json['display_order'], 0);
    level = json['item_level'] as String?;
    if (!historical) {
      _require((level == null) == (json['item_level_observed_at'] == null));
    }
    _require(
      level == null ||
          level!.length <= 64 &&
              RegExp(r'^(?:0|[1-9][0-9]*)(?:\.[0-9]*[1-9])?$').hasMatch(level!),
    );
    name = json['character_name'] as String;
    _require(name.runes.isNotEmpty && name.runes.length <= 64);
    usable = json['usable'] as bool;
    reason = json['blocked_reason'] as String?;
    _require(
      usable
          ? reason == null
          : ['CHARACTER_UNUSABLE', 'IDENTITY_CONFLICT'].contains(reason),
    );
  }
  late final String id, name;
  late final int? rank;
  late final String? level, reason, power;
  late final bool usable;
}

void _require(bool condition) {
  if (!condition) throw const FormatException('Invalid character-management-1');
}

void _closed(Map<String, dynamic> value, String fields) {
  final keys = fields.split(' ');
  _require(value.length == keys.length && keys.every(value.containsKey));
}

String _uuid(Object? value) {
  _require(
    value is String &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(value),
  );
  return value as String;
}

int _integer(Object? value, int minimum) {
  _require(value is int && value >= minimum && value <= 2147483647);
  return value as int;
}

List<String> _ids(Object? value, int maximum) {
  final ids = (value as List).map(_uuid).toList();
  _require(ids.length <= maximum && ids.toSet().length == ids.length);
  return List.unmodifiable(ids);
}

int compareManagementDecimal(String? a, String? b) {
  if (a == null || b == null) {
    return a == b
        ? 0
        : a == null
        ? 1
        : -1;
  }
  final ap = a.split('.'), bp = b.split('.');
  if (ap.first.length != bp.first.length) {
    return bp.first.length.compareTo(ap.first.length);
  }
  final whole = bp.first.compareTo(ap.first);
  if (whole != 0) return whole;
  final af = ap.length == 2 ? ap[1] : '', bf = bp.length == 2 ? bp[1] : '';
  final width = af.length > bf.length ? af.length : bf.length;
  return bf.padRight(width, '0').compareTo(af.padRight(width, '0'));
}
