import '../../account/domain/role_summary.dart';
import '../../account/domain/member_raid_models.dart';

String candidateHex(Object? value) {
  roleCheck(value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value));
  return value as String;
}

String? candidateDecimal(Object? value) {
  if (value == null) return null;
  roleCheck(
    value is String &&
        value.length <= 64 &&
        RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(value),
  );
  return value as String;
}

// Compare stored decimals without converting to double or losing precision.
int compareCandidateLevels(String? a, String? b) {
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  final x = a.split('.'), y = b.split('.');
  final xi = BigInt.parse(x.first), yi = BigInt.parse(y.first);
  final whole = yi.compareTo(xi);
  if (whole != 0) return whole;
  final xf = x.length == 1 ? '' : x[1], yf = y.length == 1 ? '' : y[1];
  final width = xf.length > yf.length ? xf.length : yf.length;
  return yf.padRight(width, '0').compareTo(xf.padRight(width, '0'));
}

class CandidatePower {
  CandidatePower(Map<String, dynamic> j) {
    roleShape(
      j,
      'value source trust observed_at saved_at power_revision integrity_status',
    );
    value = candidateDecimal(j['value']);
    source = j['source'] as String;
    roleCheck(
      {'stored_role_success', 'unavailable', 'not_disclosed'}.contains(source),
    );
    if (source == 'stored_role_success') {
      roleCheck(value != null && j['trust'] == 'client_submitted');
      roleUtc(j['observed_at']);
      roleUtc(j['saved_at']);
      rolePositive(j['power_revision']);
      roleCheck(
        {
          'clean',
          'review',
          'error',
          'unavailable',
        }.contains(j['integrity_status']),
      );
    } else {
      roleCheck(
        value == null &&
            [
              'trust',
              'observed_at',
              'saved_at',
              'power_revision',
              'integrity_status',
            ].every((k) => j[k] == null),
      );
    }
  }
  late final String? value;
  late final String source;
  String get label =>
      source == 'not_disclosed' ? '비공개' : value?.split('.').first ?? '정보 없음';
}

class CandidateCharacter {
  CandidateCharacter(Map<String, dynamic> j) {
    roleShape(
      j,
      'character_id server_name character_name class_name role_family item_level item_level_source summary_fetched_at ownership_revision lifecycle_revision ownership_state activity_state lifecycle_state dealer support',
    );
    id = roleId(j['character_id']);
    server = raidText(j['server_name']);
    name = raidText(j['character_name']);
    className = j['class_name'] as String?;
    roleCheck(j['role_family'] == null);
    level = candidateDecimal(j['item_level']);
    roleCheck(
      j['item_level_source'] ==
          (level == null ? 'unavailable' : 'stored_character_summary'),
    );
    roleUtc(j['summary_fetched_at']);
    rolePositive(j['ownership_revision']);
    rolePositive(j['lifecycle_revision']);
    roleCheck(
      j['ownership_state'] == 'owned' &&
          j['activity_state'] == 'selected' &&
          j['lifecycle_state'] == 'active',
    );
    dealer = CandidatePower(roleMap(j['dealer']));
    support = CandidatePower(roleMap(j['support']));
  }
  late final String id, server, name;
  late final String? className, level;
  late final CandidatePower dealer, support;
}

class CandidateMember {
  CandidateMember(Map<String, dynamic> j) {
    roleShape(
      j,
      'member_ref alias display continues_from_previous continues_on_next characters',
    );
    ref = candidateHex(j['member_ref']);
    final a = roleMap(j['alias']);
    roleShape(a, 'group_id group_membership_id');
    group = roleId(a['group_id']);
    membership = roleId(a['group_membership_id']);
    if (j['display'] != null) {
      final d = roleMap(j['display']);
      roleShape(d, 'server_name character_name class_name');
      raidText(d['server_name']);
      representative = raidText(d['character_name']);
      roleCheck(d['class_name'] == null || d['class_name'] is String);
    }
    fromPrevious = j['continues_from_previous'] as bool;
    toNext = j['continues_on_next'] as bool;
    characters = List.unmodifiable(
      raidList(j['characters']).map((v) => CandidateCharacter(roleMap(v))),
    );
    roleCheck(
      characters.length <= 100 &&
          (characters.isNotEmpty || (!fromPrevious && !toNext)),
    );
    _ordered(characters);
  }
  CandidateMember.merge(CandidateMember a, CandidateMember b)
    : ref = a.ref,
      group = a.group,
      membership = a.membership,
      representative = a.representative,
      fromPrevious = a.fromPrevious,
      toNext = b.toNext,
      characters = List.unmodifiable([...a.characters, ...b.characters]) {
    roleCheck(
      a.toNext &&
          b.fromPrevious &&
          a.ref == b.ref &&
          a.membership == b.membership &&
          a.representative == b.representative,
    );
    _ordered(characters);
  }
  late final String ref, group, membership;
  String? representative;
  late final bool fromPrevious, toNext;
  late final List<CandidateCharacter> characters;
  static void _ordered(List<CandidateCharacter> values) {
    roleCheck(values.map((v) => v.id).toSet().length == values.length);
    for (var i = 1; i < values.length; i++) {
      final a = values[i - 1], b = values[i];
      final level = compareCandidateLevels(a.level, b.level);
      roleCheck(level < 0 || (level == 0 && a.id.compareTo(b.id) < 0));
    }
  }
}

class CandidatePage {
  CandidatePage(
    Map<String, dynamic> j, {
    required String group,
    required String contextToken,
    required String scopeDigest,
    required Map<String, String> aliases,
    int limit = 50,
  }) {
    roleShape(
      j,
      'group_id filter_context_token scope_digest candidate_token evaluated_at groups next_cursor',
    );
    roleCheck(
      roleId(j['group_id']) == group &&
          candidateHex(j['filter_context_token']) == contextToken &&
          candidateHex(j['scope_digest']) == scopeDigest,
    );
    token = candidateHex(j['candidate_token']);
    roleUtc(j['evaluated_at']);
    members = List.unmodifiable(
      raidList(j['groups']).map((v) => CandidateMember(roleMap(v))),
    );
    roleCheck(
      members.length <= 100 &&
          members.fold<int>(
                0,
                (n, m) => n + (m.characters.isEmpty ? 1 : m.characters.length),
              ) <=
              limit,
    );
    cursor = j['next_cursor'] as String?;
    roleCheck(
      cursor == null ||
          (cursor!.isNotEmpty && cursor!.length <= 2048 && members.isNotEmpty),
    );
    for (var i = 0; i < members.length; i++) {
      final m = members[i];
      roleCheck(m.group == group && aliases[m.ref] == m.membership);
      roleCheck(
        (i == 0 || !m.fromPrevious) && (i == members.length - 1 || !m.toNext),
      );
      if (i > 0) {
        roleCheck(members[i - 1].membership.compareTo(m.membership) < 0);
      }
    }
    roleCheck(cursor != null || members.isEmpty || !members.last.toNext);
    roleCheck(
      members.expand((m) => m.characters).map((v) => v.id).toSet().length ==
          members.expand((m) => m.characters).length,
    );
  }
  late final String token;
  late final String? cursor;
  late final List<CandidateMember> members;
  List<CandidateMember> appendTo(List<CandidateMember> previous) {
    final result = [...previous];
    for (final m in members) {
      if (result.isNotEmpty && result.last.membership == m.membership) {
        result[result.length - 1] = CandidateMember.merge(result.last, m);
      } else {
        roleCheck(
          !m.fromPrevious &&
              (result.isEmpty ||
                  (!result.last.toNext &&
                      result.last.membership.compareTo(m.membership) < 0)),
        );
        result.add(m);
      }
    }
    roleCheck(
      result.expand((m) => m.characters).map((v) => v.id).toSet().length ==
          result.expand((m) => m.characters).length,
    );
    roleCheck(cursor != null || result.isEmpty || !result.last.toNext);
    return List.unmodifiable(result);
  }
}
