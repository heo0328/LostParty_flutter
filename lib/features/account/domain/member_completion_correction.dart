import 'dart:convert';
import 'member_raid_models.dart';
import 'role_summary.dart';

Object? _freeze(Object? v) => v is Map
    ? Map<String, dynamic>.unmodifiable(
        v.map((k, x) => MapEntry(k as String, _freeze(x))),
      )
    : v is List
    ? List<dynamic>.unmodifiable(v.map(_freeze))
    : v;

Object? _ordered(Object? v) => v is Map
    ? {
        for (final k in v.keys.cast<String>().toList()..sort())
          k: _ordered(v[k]),
      }
    : v is List
    ? v.map(_ordered).toList()
    : v;

String correctionStableJson(Object? value) => jsonEncode(_ordered(value));

DateTime correctionTime(Object? value) {
  roleCheck(value is String);
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-](\d{2}):(\d{2}))$',
  ).firstMatch(value as String);
  roleCheck(match != null);
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match!.group(i)!)];
  final date = DateTime.utc(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  roleCheck(
    date.year == parts[0] &&
        date.month == parts[1] &&
        date.day == parts[2] &&
        date.hour == parts[3] &&
        date.minute == parts[4] &&
        date.second == parts[5],
  );
  if (match!.group(7) != 'Z') {
    roleCheck(
      int.parse(match.group(8)!) <= 23 && int.parse(match.group(9)!) <= 59,
    );
  }
  return DateTime.parse(value).toUtc();
}

int _revision(Object? value) {
  final result = rolePositive(value);
  roleCheck(result <= 2147483647);
  return result;
}

void _envelope(Map<String, dynamic> wire, String target) {
  roleShape(wire, 'server_now current_cycle_key data');
  final current = raidCycleKey(wire['current_cycle_key']);
  raidCycleKey(target);
  final start = DateTime.parse(
    '${current}T00:00:00Z',
  ).subtract(const Duration(hours: 3));
  final stamp = correctionTime(wire['server_now']);
  roleCheck(
    target.compareTo(current) <= 0 &&
        !stamp.isBefore(start) &&
        stamp.isBefore(start.add(const Duration(days: 7))),
  );
}

/// The original, immutable confirmation also survives durable command recovery.
class MemberCompletionCorrection {
  MemberCompletionCorrection(
    this.character,
    this.raid,
    this.target,
    Map<String, dynamic> raw,
  ) : wire = _freeze(jsonDecode(jsonEncode(raw))) as Map<String, dynamic> {
    roleId(character);
    raidIdentifier(raid);
    _envelope(wire, target);
    data = roleMap(wire['data']);
    roleShape(
      data,
      'character_id raid_id target_cycle_key weekly_revision ownership_revision lifecycle_revision completion_sources permission confirmation',
    );
    roleCheck(
      data['character_id'] == character &&
          data['raid_id'] == raid &&
          data['target_cycle_key'] == target,
    );
    for (final k in [
      'weekly_revision',
      'ownership_revision',
      'lifecycle_revision',
    ]) {
      _revision(data[k]);
    }
    final sources = raidList(data['completion_sources']);
    roleCheck(sources.length <= 2);
    var previous = -1;
    for (final raw in sources) {
      final s = roleMap(raw);
      roleShape(s, 'source completed_at difficulty_id party_id');
      final index = ['manual', 'party'].indexOf(s['source'] as String);
      roleCheck(index > previous);
      previous = index;
      correctionTime(s['completed_at']);
      if (s['difficulty_id'] != null) roleCheck(s['difficulty_id'] is String);
      if (s['party_id'] != null) roleId(s['party_id']);
      roleCheck(s['source'] != 'manual' || s['party_id'] == null);
    }
    final permission = roleMap(data['permission']);
    roleShape(permission, 'allowed reason next_change_at');
    allowed = raidBool(permission['allowed']);
    roleCheck(
      permission['next_change_at'] == null &&
          allowed == sources.isNotEmpty &&
          permission['reason'] == (allowed ? null : 'COMPLETION_NOT_FOUND'),
    );
    roleCheck(allowed == (data['confirmation'] != null));
    if (allowed) {
      final c = roleMap(data['confirmation']);
      roleShape(c, 'context_token issued_at expires_at');
      roleCheck(
        c['context_token'] is String &&
            (c['context_token'] as String).isNotEmpty &&
            utf8.encode(c['context_token']).length <= 4096,
      );
      final issued = correctionTime(c['issued_at']),
          expires = correctionTime(c['expires_at']);
      final end = DateTime.parse(
        '${wire['current_cycle_key']}T00:00:00Z',
      ).add(const Duration(days: 7)).subtract(const Duration(hours: 3));
      roleCheck(
        issued == correctionTime(wire['server_now']) &&
            expires.isAfter(issued) &&
            expires.difference(issued) <= const Duration(seconds: 120) &&
            !expires.isAfter(end),
      );
    }
  }
  final String character, raid, target;
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> data;
  late final bool allowed;
  String get signature => correctionStableJson({
    'current': wire['current_cycle_key'],
    for (final e in data.entries)
      if (e.key != 'confirmation') e.key: e.value,
  });
  Map<String, dynamic> body() {
    roleCheck(allowed);
    return {
      'target_cycle_key': target,
      'expected_cycle_key': wire['current_cycle_key'],
      'expected_weekly_revision': data['weekly_revision'],
      'expected_ownership_revision': data['ownership_revision'],
      'expected_lifecycle_revision': data['lifecycle_revision'],
      'correction_context_token': data['confirmation']['context_token'],
    };
  }
}

class MemberCompletionCorrectionResult {
  MemberCompletionCorrectionResult(
    Map<String, dynamic> raw,
    MemberCompletionCorrection original,
    String key,
  ) {
    _envelope(raw, original.target);
    roleCheck(raw['current_cycle_key'] == original.wire['current_cycle_key']);
    final d = roleMap(raw['data']);
    roleShape(
      d,
      'command_id outcome correction_id character_id raid_id target_cycle_key weekly_revision completion_sources participation_restored',
    );
    roleId(d['correction_id']);
    roleCheck(
      d['command_id'] == key &&
          d['outcome'] == 'applied' &&
          d['character_id'] == original.character &&
          d['raid_id'] == original.raid &&
          d['target_cycle_key'] == original.target &&
          _revision(d['weekly_revision']) ==
              original.data['weekly_revision'] + 1 &&
          raidList(d['completion_sources']).isEmpty &&
          d['participation_restored'] == false,
    );
    final stamp = correctionTime(raw['server_now']),
        confirmation = roleMap(original.data['confirmation']);
    roleCheck(
      !stamp.isBefore(correctionTime(confirmation['issued_at'])) &&
          stamp.isBefore(correctionTime(confirmation['expires_at'])),
    );
  }
}
