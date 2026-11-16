import '../../../shared/diagnostics/startup_timing.dart';
import '../domain/account_read_session.dart';
import '../domain/role_summary.dart';
import '../domain/scoped_cache_models.dart';
import 'role_summary_client.dart';

class RoleBatchClient {
  RoleBatchClient(this.single);
  final RoleSummaryClient single;
  Future<
    Map<String, ({PersonalProfile? profile, AccountReadException? failure})>
  >
  profiles(List<ScopedCharacterRef> refs) async {
    final captured = accountReadScope(single.api.session);
    final unique = <String>{};
    for (final ref in refs) {
      single.requireScope(ref, captured);
      roleCheck(unique.add(roleId(ref.characterId)));
    }
    final result =
        <String, ({PersonalProfile? profile, AccountReadException? failure})>{};
    for (var start = 0; start < refs.length; start += 50) {
      final part = refs.skip(start).take(50).toList();
      final raw = await single.api.request(
        '/v2/me/characters/personal-profiles',
        query: {'character_id': part.map((r) => r.characterId).toList()},
      );
      for (final ref in part) {
        single.requireScope(ref, captured);
      }
      final decoded = _parse(
        () => StartupTiming.sync(StartupWork.dto, () {
          final json = roleMap(raw);
          roleShape(json, 'evaluated_at items');
          roleUtc(json['evaluated_at']);
          final values = json['items'];
          roleCheck(values is List && values.length == part.length);
          final expected = {for (final ref in part) ref.characterId: ref};
          final found =
              <
                String,
                ({PersonalProfile? profile, AccountReadException? failure})
              >{};
          for (final value in values as List) {
            final item = roleMap(value);
            roleShape(item, 'character_id status profile error');
            final id = roleId(item['character_id']);
            roleCheck(expected.containsKey(id) && !found.containsKey(id));
            final status = _status(item['status']);
            if (status == 200) {
              roleCheck(item['error'] == null);
              final profile = PersonalProfile.fromJson(
                roleMap(item['profile']),
              );
              roleCheck(
                profile.characterId == id &&
                    profile.accountId == expected[id]!.accountId,
              );
              found[id] = (profile: profile, failure: null);
            } else {
              roleCheck(item['profile'] == null);
              found[id] = (
                profile: null,
                failure: _error(item['error'], status),
              );
            }
          }
          return found;
        }),
      );
      result.addAll(decoded);
    }
    return result;
  }

  static int _status(Object? value) {
    roleCheck(value is int && (value == 200 || (value >= 400 && value <= 599)));
    return value as int;
  }

  static AccountReadException _error(Object? raw, int status) {
    final error = roleMap(raw);
    roleShape(error, 'code message request_id retry_after_seconds');
    final code = error['code'],
        request = error['request_id'],
        seconds = error['retry_after_seconds'];
    roleCheck(
      code is String && RegExp(r'^[A-Z][A-Z0-9_]{0,79}$').hasMatch(code),
    );
    roleCheck(
      error['message'] is String &&
          request is String &&
          RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(request),
    );
    roleCheck(
      seconds == null || seconds is int && seconds >= 0 && seconds <= 86400,
    );
    return AccountReadException(
      code as String,
      status: status,
      requestId: request as String,
      retryAfter: seconds == null ? null : Duration(seconds: seconds as int),
    );
  }

  static T _parse<T>(T Function() action) {
    try {
      return action();
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }
}
