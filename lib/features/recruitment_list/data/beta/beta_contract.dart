import 'dart:convert';

import '../../../account/domain/role_summary.dart';
import '../../../account/domain/member_raid_models.dart';
import '../../domain/policies/party_cycle_policy.dart';
import 'beta_wire_schema.g.dart';

enum RecruitmentContractMode { legacy, betaWire2 }

/// Closed, pinned wire validation, separate from existing semantic parsers.
/// This never negotiates with a server or retries using a different profile.
class BetaContract {
  const BetaContract({this.mode = RecruitmentContractMode.legacy});
  final RecruitmentContractMode mode;
  static const version = 'beta-recruitment-wire-2';
  static const profile = 'beta-recruitment-1';
  static final Map<String, dynamic> _wire = jsonDecode(betaWireSchemaJson);

  Map<String, dynamic> operation(String method, String path) {
    final found = (_wire['operations'] as List).where((o) {
      final template = o['path'] as String;
      final pattern = template
          .split('/')
          .map((s) => s.startsWith('{') ? r'[^/]+' : RegExp.escape(s))
          .join('/');
      return o['method'] == method && RegExp('^$pattern\$').hasMatch(path);
    }).toList();
    roleCheck(found.length == 1);
    final templateParts = (found.single['path'] as String).split('/');
    final actualParts = path.split('/');
    for (var i = 0; i < templateParts.length; i++) {
      if (templateParts[i].startsWith('{')) roleId(actualParts[i]);
    }
    return roleMap(found.single);
  }

  Map<String, dynamic> query(
    String method,
    String path, [
    Map<String, dynamic> supplied = const {},
  ]) {
    if (mode == RecruitmentContractMode.legacy) {
      roleCheck(!supplied.containsKey('contract_profile'));
      return Map.unmodifiable(supplied);
    }
    final op = operation(method, path);
    final params = op['query'] as List;
    final profiled = params.any((p) => p['name'] == 'contract_profile');
    roleCheck(
      !supplied.containsKey('contract_profile') ||
          (profiled && supplied['contract_profile'] == profile),
    );
    return Map.unmodifiable({
      ...supplied,
      if (profiled) 'contract_profile': profile,
    });
  }

  void validateRequest(
    String method,
    String path,
    Map<String, dynamic> query,
    Object? body,
  ) {
    roleCheck(mode == RecruitmentContractMode.betaWire2);
    final op = operation(method, path);
    final params = op['query'] as List;
    roleCheck(query.keys.every((k) => params.any((p) => p['name'] == k)));
    for (final p in params) {
      final name = p['name'] as String;
      roleCheck(p['required'] != true || query.containsKey(name));
      if (query.containsKey(name)) validate(p['schema'], query[name]);
    }
    validate(op['request'], body);
    if (body is Map<String, dynamic>) {
      if (body['application_memo'] case final String text) {
        RawApplicationMemo(text);
      }
      if (path == '/v2/me/application-message-presets' &&
          body['items'] is List) {
        for (final item in body['items'] as List) {
          RawApplicationMemo(item['text'] as String);
        }
      }
    }
  }

  void validateResponse(String method, String path, int status, Object? value) {
    roleCheck(mode == RecruitmentContractMode.betaWire2);
    final responses = roleMap(operation(method, path)['responses']);
    roleCheck(responses.containsKey('$status'));
    validate(responses['$status'], value);
  }

  static void definition(
    String name,
    Object? value, [
    String location = 'root',
  ]) {
    final defs = roleMap(_wire['definitions']);
    roleCheck(defs.containsKey(name));
    validate(defs[name], value, location);
  }

  static void validate(
    Object? rawSchema,
    Object? v, [
    String location = 'root',
  ]) {
    try {
      _validate(rawSchema, v, location);
    } on FormatException catch (e) {
      throw FormatException('Invalid beta field $location: ${e.message}');
    }
  }

  static void _validate(Object? rawSchema, Object? v, String location) {
    if (rawSchema == null) {
      roleCheck(v == null);
      return;
    }
    final s = roleMap(rawSchema);
    if (s[r'$ref'] case final String ref) {
      definition(ref.split('/').last, v, location);
      return;
    }
    for (final alternative in ['anyOf', 'oneOf']) {
      if (s[alternative] case final List branches) {
        var matches = 0;
        final failures = <String>[];
        for (final branch in branches) {
          try {
            validate(branch, v, location);
            matches++;
          } on FormatException catch (e) {
            failures.add(e.message);
          }
        }
        if (!(alternative == 'oneOf' ? matches == 1 : matches > 0)) {
          throw FormatException(failures.join(' | '));
        }
      }
    }
    if (s.containsKey('const')) roleCheck(v == s['const']);
    if (s['enum'] case final List allowed) roleCheck(allowed.contains(v));
    switch (s['type']) {
      case 'null':
        roleCheck(v == null);
      case 'boolean':
        roleCheck(v is bool);
      case 'integer':
        roleCheck(v is int);
      case 'number':
        roleCheck(v is num && v.isFinite);
      case 'string':
        roleCheck(v is String);
      case 'array':
        roleCheck(v is List);
      case 'object':
        roleCheck(v is Map<String, dynamic>);
    }
    if (v is Map<String, dynamic>) {
      final properties = roleMap(s['properties'] ?? <String, dynamic>{});
      if (s['additionalProperties'] == false) {
        if (!v.keys.every(properties.containsKey)) {
          throw const FormatException('Unexpected keys');
        }
      }
      for (final k in s['required'] as List? ?? const []) {
        if (!v.containsKey(k)) throw FormatException('Missing $k');
      }
      for (final e in v.entries) {
        if (properties.containsKey(e.key)) {
          validate(properties[e.key], e.value, '$location.${e.key}');
        }
      }
    }
    if (v is List) {
      roleCheck(
        v.length >= (s['minItems'] ?? 0) &&
            v.length <= (s['maxItems'] ?? 100000),
      );
      if (s.containsKey('items')) {
        for (final item in v) {
          validate(s['items'], item);
        }
      }
    }
    if (v is num) {
      roleCheck(
        (s['minimum'] == null || v >= s['minimum']) &&
            (s['maximum'] == null || v <= s['maximum']) &&
            (s['exclusiveMinimum'] == null || v > s['exclusiveMinimum']) &&
            (s['exclusiveMaximum'] == null || v < s['exclusiveMaximum']),
      );
    }
    if (v is String) {
      roleCheck(
        v.runes.length >= (s['minLength'] ?? 0) &&
            v.runes.length <= (s['maxLength'] ?? 1000000),
      );
      if (s['pattern'] case final String pattern) {
        final match = RegExp(pattern).firstMatch(v);
        roleCheck(
          match != null && (!pattern.endsWith(r'$') || match.end == v.length),
        );
      }
      if (s['format'] == 'uuid' || s['format'] == 'uuid4') roleId(v);
      if (s['format'] == 'date-time') roleUtc(v);
      if (s['format'] == 'date') raidCycleKey(v);
    }
  }
}

Object? betaFreeze(Object? value) => value is Map
    ? Map<String, dynamic>.unmodifiable(
        value.map((k, v) => MapEntry(k as String, betaFreeze(v))),
      )
    : value is List
    ? List<dynamic>.unmodifiable(value.map(betaFreeze))
    : value;

/// A beta response is validated before removing only its declared additions.
/// The caller must still run the existing semantic parser. No legacy fallback.
class BetaResponse<T> {
  BetaResponse._(this.value, this.metadata);
  final T value;
  final Map<String, dynamic> metadata;
  static BetaResponse<T> parse<T>({
    required String method,
    required String path,
    required int status,
    required Map<String, dynamic> json,
    required T Function(Map<String, dynamic>) parseLegacy,
  }) {
    const contract = BetaContract(mode: RecruitmentContractMode.betaWire2);
    contract.validateResponse(method, path, status, json);
    _relations(json);
    final metadata = betaFreeze(json) as Map<String, dynamic>;
    Object? strip(Object? v) => v is Map<String, dynamic>
        ? {
            for (final e in v.entries)
              if (!const {
                'beta_schedule',
                'beta_schedule_targets',
                'beta_schedule_config',
                'recruitment_identity',
                'availability_copy',
                'application_memo',
              }.contains(e.key))
                e.key: strip(e.value),
          }
        : v is List
        ? v.map(strip).toList()
        : v;
    return BetaResponse._(parseLegacy(roleMap(strip(json))), metadata);
  }

  static void _relations(Object? raw) {
    if (raw is List) {
      for (final v in raw) {
        _relations(v);
      }
      return;
    }
    if (raw is! Map<String, dynamic>) return;
    if (raw['beta_schedule'] case final Map<String, dynamic> s) {
      BetaSchedule(s);
    }
    if (raw.containsKey('content')) {
      if (raw['content'] == null) {
        roleCheck(
          raw['beta_schedule'] == null && raw['recruitment_identity'] == null,
        );
      } else if (raw.containsKey('beta_schedule')) {
        final content = roleMap(raw['content']);
        final inner = content.containsKey('data')
            ? roleMap(content['data'])
            : content;
        for (final key in ['beta_schedule', 'recruitment_identity']) {
          if (raw.containsKey(key)) roleCheck(_same(raw[key], inner[key]));
        }
      }
    }
    if (raw['room'] case final Map<String, dynamic> room) {
      if (raw.containsKey('beta_schedule')) {
        roleCheck(_same(raw['beta_schedule'], room['beta_schedule']));
      }
    }
    if (raw['recruitment_identity'] != null) {
      final member = raw['my_membership'];
      final viewer = raw['viewer'];
      final memberAllowed =
          member is Map &&
          member['cycle_member_id'] != null &&
          {'leader', 'member'}.contains(member['target_role']) &&
          raw['my_target_role'] == member['target_role'] &&
          (raw['room'] is Map
                  ? raw['room']['target_state']
                  : raw['target_state']) ==
              'open' &&
          (raw['access'] == null || raw['access']['state'] == 'allowed');
      final viewerAllowed =
          viewer is Map &&
          viewer['membership_state'] == 'active' &&
          viewer['cycle_member_state'] == 'participating' &&
          viewer['mode'] == 'participant';
      roleCheck(memberAllowed || viewerAllowed);
    }
    for (final v in raw.values) {
      _relations(v);
    }
  }
}

bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]));
  }
  return a == b;
}

class BetaScheduleConfig {
  BetaScheduleConfig(Map<String, dynamic> json)
    : wire = betaFreeze(json) as Map<String, dynamic> {
    BetaContract.definition('Proposed_BetaScheduleConfig', wire);
    roleCheck(enabled == (additionalMembers != null));
  }
  final Map<String, dynamic> wire;
  DateTime get startsAt => roleUtc(wire['base_starts_at']);
  bool get enabled => wire['early_coordination_enabled'] as bool;
  int? get additionalMembers => wire['early_additional_members'] as int?;
}

class BetaCreationDraft {
  BetaCreationDraft(Map<String, BetaScheduleConfig> targets)
    : targets = Map.unmodifiable(targets) {
    roleCheck(targets.isNotEmpty && targets.length <= 2);
    final keys = targets.keys.toList()..sort();
    for (final e in targets.entries) {
      raidCycleKey(e.key);
      final window = const PartyCyclePolicy().fromKey(e.key)!;
      roleCheck(
        !e.value.startsAt.isBefore(window.startedAt) &&
            e.value.startsAt.isBefore(window.endsAt),
      );
    }
    if (keys.length == 2) {
      roleCheck(
        const PartyCyclePolicy().keyFor(
              const PartyCyclePolicy().fromKey(keys.first)!.endsAt,
            ) ==
            keys.last,
      );
    }
  }
  final Map<String, BetaScheduleConfig> targets;
  List<Map<String, dynamic>> toWire() => [
    for (final e in targets.entries)
      {'target_cycle_key': e.key, ...e.value.wire},
  ];
}

class BetaSchedule {
  BetaSchedule(Map<String, dynamic> json)
    : wire = betaFreeze(json) as Map<String, dynamic> {
    BetaContract.definition('Proposed_BetaScheduleView', wire);
    roleCheck(
      wire['early_coordination_enabled'] ==
          (wire['early_additional_members'] != null),
    );
    final start = roleUtc(wire['base_starts_at']),
        end = roleUtc(wire['base_ends_at']);
    roleCheck(
      end.isAfter(start) &&
          roleUtc(wire['base_deadline_at']) ==
              start.subtract(const Duration(minutes: 30)),
    );
    final cs = wire['confirmed_starts_at'], ce = wire['confirmed_ends_at'];
    roleCheck((cs == null) == (ce == null));
    if (cs != null) roleCheck(roleUtc(ce).isAfter(roleUtc(cs)));
    roleCheck(
      roleUtc(wire['effective_starts_at']) ==
              roleUtc(cs ?? wire['base_starts_at']) &&
          roleUtc(wire['effective_ends_at']) ==
              roleUtc(ce ?? wire['base_ends_at']),
    );
    if (state == 'early_confirmed') {
      roleCheck(cs != null && roleUtc(cs).isBefore(start));
    }
  }
  final Map<String, dynamic> wire;
  String get state => wire['coordination_state'] as String;
}

class AvailabilityCopy {
  AvailabilityCopy(Map<String, dynamic> json)
    : wire = betaFreeze(json) as Map<String, dynamic> {
    BetaContract.definition('Proposed_AvailabilityCopyView', wire);
  }
  final Map<String, dynamic> wire;
  bool get unset => wire['state'] == 'unset';
}

class RecruitmentIdentity {
  RecruitmentIdentity(Map<String, dynamic> json) {
    BetaContract.definition('Proposed_RecruitmentIdentity', json);
    number = json['number'] as int;
    password = json['password'] as String;
  }
  late final int number;
  late final String password;
}

class ApplicationMemo {
  ApplicationMemo(this.text) {
    BetaContract.definition('Proposed_MemoStored', text);
  }
  final String text;
}

/// Original input, before future UI normalization/validation. Never rewritten for retry.
class RawApplicationMemo {
  RawApplicationMemo(this.text) {
    BetaContract.definition('Proposed_Memo', text);
    roleCheck(utf8.encode(text).length <= 4096);
  }
  final String text;
}

class ApplicationMessagePresets {
  ApplicationMessagePresets(Map<String, dynamic> json)
    : wire = betaFreeze(json) as Map<String, dynamic> {
    BetaContract.definition('Proposed_PresetStoredDocument', wire);
    final ids = (wire['items'] as List).map((v) => v['id']).toList();
    roleCheck(ids.toSet().length == ids.length);
    if (wire['saved_at'] == null) {
      roleCheck(wire['version'] == 1 && ids.isEmpty);
    }
  }
  final Map<String, dynamic> wire;
}
