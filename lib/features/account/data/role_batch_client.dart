import 'dart:convert';

import '../../../shared/diagnostics/startup_timing.dart';
import '../domain/account_read_session.dart';
import '../domain/entities/character_build_role.dart';
import '../domain/role_summary.dart';
import '../domain/scoped_cache_models.dart';
import 'role_summary_client.dart';

const startupBatchContract = 'b1f11bb5011056ce5dd655efe7c8efe2765960e3';
typedef RoleUploadKey = (String, CharacterBuildRole);

class RoleBatchWrite {
  RoleBatchWrite(this.ref, this.role, this.commandId, Map<String, dynamic> body)
    : _body = jsonEncode(body) {
    roleId(ref.characterId);
    roleCheck(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(commandId),
    );
    roleShape(
      body,
      'expected_version expected_ownership_revision expected_lifecycle_revision summary',
    );
    rolePositive(body['expected_version']);
    rolePositive(body['expected_ownership_revision']);
    final life = rolePositive(body['expected_lifecycle_revision']);
    final summary = RoleSummary.fromJson(roleMap(body['summary']));
    roleCheck(summary.lifecycleRevision == life);
    if (utf8.encode(_body).length > 32768) {
      throw const AccountReadException('REQUEST_TOO_LARGE', status: 413);
    }
  }
  final ScopedCharacterRef ref;
  final CharacterBuildRole role;
  final String commandId, _body;
  RoleUploadKey get key => (ref.characterId, role);
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  Map<String, dynamic> get wire => {
    'character_id': ref.characterId,
    'role': role.name,
    'command_id': commandId,
    ...body,
  };
}

class RoleBatchResult {
  const RoleBatchResult({this.ack, this.failure});
  final RoleSummaryAck? ack;
  final AccountReadException? failure;
}

/// Strict additional wire; never falls back to single HTTP calls.
class RoleBatchClient {
  RoleBatchClient(this.single);
  final RoleSummaryClient single;

  static List<List<RoleBatchWrite>> chunks(List<RoleBatchWrite> commands) {
    final result = <List<RoleBatchWrite>>[];
    var chunk = <RoleBatchWrite>[];
    final ids = <String>{}, resources = <RoleUploadKey>{};
    for (final command in commands) {
      roleCheck(ids.add(command.commandId) && resources.add(command.key));
      final candidate = [...chunk, command];
      if (candidate.length > 50 || encodedSize(candidate) > 524288) {
        roleCheck(chunk.isNotEmpty);
        result.add(List.unmodifiable(chunk));
        chunk = [];
      }
      chunk.add(command);
    }
    if (chunk.isNotEmpty) result.add(List.unmodifiable(chunk));
    return List.unmodifiable(result);
  }

  static int encodedSize(List<RoleBatchWrite> commands) => utf8
      .encode(jsonEncode({'items': commands.map((c) => c.wire).toList()}))
      .length;

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

  Future<Map<String, RoleBatchResult>> put(
    List<RoleBatchWrite> commands,
  ) async {
    roleCheck(commands.isNotEmpty && commands.length <= 50);
    roleCheck(chunks(commands).length == 1);
    final captured = accountReadScope(single.api.session);
    for (final command in commands) {
      single.requireScope(command.ref, captured);
    }
    final raw = await single.api.request(
      '/v2/me/role-summary-batches',
      method: 'POST',
      body: {'items': commands.map((c) => c.wire).toList()},
    );
    for (final command in commands) {
      single.requireScope(command.ref, captured);
    }
    return _parse(
      () => StartupTiming.sync(StartupWork.dto, () {
        final json = roleMap(raw);
        roleShape(json, 'items');
        final values = json['items'];
        roleCheck(values is List && values.length == commands.length);
        final expected = {for (final c in commands) c.commandId: c};
        final result = <String, RoleBatchResult>{};
        for (final value in values as List) {
          final item = roleMap(value);
          roleShape(item, 'character_id role command_id status result error');
          final id = roleId(item['command_id']);
          final command = expected[id];
          roleCheck(command != null && !result.containsKey(id));
          roleCheck(
            roleId(item['character_id']) == command!.ref.characterId &&
                item['role'] == command.role.name,
          );
          final status = _status(item['status']);
          if (status == 200) {
            roleCheck(item['error'] == null);
            final ack = RoleSummaryAck.fromJson(roleMap(item['result']));
            final body = command.body;
            final summary = RoleSummary.fromJson(roleMap(body['summary']));
            final version = body['expected_version'] as int;
            roleCheck(
              ack.characterId == command.ref.characterId &&
                  ack.role == command.role &&
                  ack.ownershipRevision ==
                      body['expected_ownership_revision'] &&
                  ack.lifecycleRevision ==
                      body['expected_lifecycle_revision'] &&
                  ack.stored.summary!.same(summary) &&
                  (ack.stored.version == version ||
                      ack.stored.version == version + 1),
            );
            result[id] = RoleBatchResult(ack: ack);
          } else {
            roleCheck(item['result'] == null);
            result[id] = RoleBatchResult(
              failure: _error(item['error'], status),
            );
          }
        }
        return result;
      }),
    );
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
