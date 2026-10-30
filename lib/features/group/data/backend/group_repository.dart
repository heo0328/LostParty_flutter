import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../account/domain/account_read_session.dart';
import '../../../account/domain/scoped_cache_models.dart';
import '../../../account/data/local/scoped_command_key.dart';
import '../../../auth/domain/backend_auth_models.dart';
import 'group_contract.dart';
import 'group_models.dart';

abstract interface class GroupJournal {
  Future<String?> read(String scope);
  Future<void> write(String scope, String? value);
}

class SecureGroupJournal implements GroupJournal {
  const SecureGroupJournal();
  static const storage = FlutterSecureStorage();
  String key(String scope) =>
      'group_commands_v1_${base64Url.encode(utf8.encode(scope))}';
  @override
  Future<String?> read(String scope) => storage.read(key: key(scope));
  @override
  Future<void> write(String scope, String? value) => value == null
      ? storage.delete(key: key(scope))
      : storage.write(key: key(scope), value: value);
}

/// App-owned change signal. A membership change does not impersonate logout.
class GroupChanges extends ChangeNotifier {
  int version = 0;
  void applied() {
    version++;
    notifyListeners();
  }
}

class GroupRepository {
  GroupRepository(
    this.dio,
    this.session,
    this.changes, {
    this.journal = const SecureGroupJournal(),
  });
  final Dio dio;
  final AccountReadSession session;
  final GroupChanges changes;
  final GroupJournal journal;
  bool _busy = false;
  String get storageScope => jsonEncode([
    StorageScope(
      baseUrl: dio.options.baseUrl,
      userId: session.userId!,
      allowHttp: kDebugMode,
    ).environment,
    session.userId,
  ]);
  String get readScope => session.isAuthenticated
      ? '$storageScope/${session.generation}'
      : 'signed-out/${session.generation}';

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? body,
    String? rawBody,
    String? key,
  }) async {
    final binding = accountReadScope(session),
        environment = dio.options.baseUrl;
    GroupContract.request(
      method,
      path,
      query,
      rawBody == null ? body : jsonDecode(rawBody),
    );
    void guard() {
      requireAccountReadScope(session, binding);
      if (environment != dio.options.baseUrl) {
        throw const AccountReadException('ENVIRONMENT_CHANGED');
      }
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await session.accessToken();
      guard();
      try {
        final result = await dio.request<Object?>(
          path,
          queryParameters: query,
          data: rawBody ?? body,
          options: Options(
            method: method,
            followRedirects: false,
            contentType: Headers.jsonContentType,
            headers: {
              'Authorization': 'Bearer $token',
              'Idempotency-Key': ?key,
            },
          ),
        );
        guard();
        GroupContract.response(method, path, result.statusCode!, result.data);
        final value = groupMap(result.data);
        final profile = query['reader_profile'] ?? query['management_profile'];
        if (profile != null && value['profile'] != profile) {
          throw const FormatException('Missing group profile');
        }
        return value;
      } on DioException catch (e) {
        guard();
        final error = e.response?.data is Map
            ? e.response!.data['error']
            : null;
        final code = error is Map && error['code'] is String
            ? error['code'] as String
            : e.response == null
            ? 'NETWORK_UNAVAILABLE'
            : 'INVALID_RESPONSE';
        if (attempt == 0 && code == 'ACCESS_EXPIRED') {
          await session.refresh();
          guard();
          continue;
        }
        if (e.response?.statusCode == 401 || code == 'ACCOUNT_DISABLED') {
          await session.reject(
            binding.generation,
            AuthApiException(code, status: e.response?.statusCode),
          );
        }
        throw AccountReadException(
          code,
          status: e.response?.statusCode,
          retryAfter: Duration(
            seconds:
                int.tryParse(e.response?.headers.value('retry-after') ?? '') ??
                2,
          ),
        );
      }
    }
    throw const AccountReadException('ACCESS_EXPIRED');
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic> query = const {},
  }) => request('GET', path, query: query);
  Future<List<Map<String, dynamic>>> all(
    String path, {
    Map<String, dynamic> query = const {},
  }) async {
    final scope = readScope;
    var restarted = false;
    while (true) {
      final rows = <Map<String, dynamic>>[], seen = <String>{};
      String? cursor;
      try {
        do {
          final page = await get(
            path,
            query: {...query, 'limit': 20, 'cursor': ?cursor},
          );
          if (scope != readScope) {
            throw const AccountReadException('STALE_READ');
          }
          rows.addAll(groupItems(page));
          cursor = page['next_cursor'] as String?;
          if (cursor != null && !seen.add(cursor)) {
            throw const FormatException('Repeated group cursor');
          }
        } while (cursor != null);
        return rows;
      } on AccountReadException catch (e) {
        if (e.code == 'CURSOR_STALE' && !restarted) {
          restarted = true;
          continue;
        }
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>?> pending() async {
    final scope = storageScope, binding = readScope;
    final value = await journal.read(scope);
    if (binding != readScope || scope != storageScope) {
      throw const AccountReadException('STALE_READ');
    }
    if (value == null) return null;
    final command = groupMap(jsonDecode(value));
    if (command['version'] != 1 ||
        command['scope'] != scope ||
        command['key'] is! String ||
        command['raw_body'] is! String) {
      throw const FormatException('Invalid group journal');
    }
    if (!{'pending', 'acknowledged'}.contains(command['state'])) {
      throw const FormatException('Invalid group command state');
    }
    if (!{'POST', 'PUT', 'PATCH'}.contains(command['method']) ||
        command['path'] == '/v1/group-join-codes/preview' ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        ).hasMatch(command['key'])) {
      throw const FormatException('Invalid group command identity');
    }
    GroupContract.operation(command['method'], command['path']);
    if (command['state'] == 'pending') {
      GroupContract.request(
        command['method'],
        command['path'],
        const {},
        jsonDecode(command['raw_body']),
      );
    }
    return command;
  }

  Future<Map<String, dynamic>> command(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    if (_busy) throw const AccountReadException('REQUEST_IN_PROGRESS');
    _busy = true;
    try {
      final scope = storageScope, binding = readScope;
      if (!{'POST', 'PUT', 'PATCH'}.contains(method) ||
          path == '/v1/group-join-codes/preview') {
        throw const FormatException('Not a group command');
      }
      if (await pending() != null) {
        throw const AccountReadException('GROUP_COMMAND_PENDING');
      }
      if (binding != readScope) throw const AccountReadException('STALE_READ');
      GroupContract.request(method, path, const {}, body);
      final command = <String, dynamic>{
        'version': 1,
        'scope': scope,
        'method': method,
        'path': path,
        'raw_body': jsonEncode(body),
        'key': newScopedCommandKey(),
        'state': 'pending',
        'retry_at': null,
      };
      await journal.write(scope, jsonEncode(command));
      if (binding != readScope) throw const AccountReadException('STALE_READ');
      return await _send(command, scope);
    } finally {
      _busy = false;
    }
  }

  Future<Map<String, dynamic>?> recover() async {
    if (_busy) throw const AccountReadException('REQUEST_IN_PROGRESS');
    _busy = true;
    try {
      final scope = storageScope, binding = readScope;
      final c = await pending();
      if (c == null) return null;
      if (binding != readScope) throw const AccountReadException('STALE_READ');
      if (c['state'] == 'acknowledged') {
        await journal.write(scope, null);
        if (binding != readScope) {
          throw const AccountReadException('STALE_READ');
        }
        changes.applied();
        return null;
      }
      final retry = DateTime.tryParse(c['retry_at'] as String? ?? '');
      if (retry != null && retry.isAfter(DateTime.now().toUtc())) {
        throw const AccountReadException('REQUEST_IN_PROGRESS');
      }
      return await _send(c, scope);
    } finally {
      _busy = false;
    }
  }

  Future<Map<String, dynamic>> _send(
    Map<String, dynamic> command,
    String scope,
  ) async {
    final binding = readScope;
    late final Map<String, dynamic> result;
    try {
      result = await request(
        command['method'],
        command['path'],
        rawBody: command['raw_body'],
        key: command['key'],
      );
    } on AccountReadException catch (e) {
      if (e.status != null &&
          e.status! < 500 &&
          e.status != 429 &&
          !{
            'REQUEST_IN_PROGRESS',
            'IDEMPOTENCY_IN_PROGRESS',
          }.contains(e.code)) {
        await journal.write(scope, null);
      } else {
        command['retry_at'] = DateTime.now()
            .toUtc()
            .add(e.retryAfter ?? const Duration(seconds: 2))
            .toIso8601String();
        await journal.write(scope, jsonEncode(command));
      }
      rethrow;
    }
    // Persist resolution before releasing, including when the active member changes during storage I/O.
    command['state'] = 'acknowledged';
    command['raw_body'] = '{}';
    await journal.write(scope, jsonEncode(command));
    await journal.write(scope, null);
    if (binding != readScope) throw const AccountReadException('STALE_READ');
    changes.applied();
    return result;
  }
}

String groupFailure(Object error) {
  if (error is! AccountReadException) return '그룹 정보를 처리하지 못했습니다. 다시 확인해 주세요.';
  return switch (error.code) {
    'GROUP_FEATURE_NOT_READY' => '그룹 기능을 준비 중입니다. 서버 반영 후 다시 이용해 주세요.',
    'GROUP_COMMAND_PENDING' => '처리 결과가 확인되지 않은 요청이 있습니다. 원요청 결과를 확인해 주세요.',
    'NETWORK_UNAVAILABLE' => '연결을 확인하지 못했습니다. 다시 시도해 주세요.',
    'LOGIN_REQUIRED' => '로그인이 필요합니다.',
    'NO_ACTIVITY_CHARACTERS' => '내 계정에서 인증된 활동 캐릭터를 먼저 선택해 주세요.',
    'GROUP_FULL' || 'GROUP_CAPACITY_EXCEEDED' => '그룹 정원을 확인해 주세요.',
    'GROUP_ALREADY_JOINED' || 'ALREADY_MEMBER' => '이미 가입한 그룹입니다.',
    'GROUP_JOIN_BLOCKED' => '이 그룹에 가입할 수 없습니다.',
    'GROUP_RELATION_EXISTS' ||
    'GROUP_INVITATION_EXISTS' ||
    'GROUP_APPLICATION_EXISTS' => '기존 초대 또는 가입 신청이 있습니다. 요청 현황에서 확인해 주세요.',
    'STALE_READ' ||
    'SESSION_CHANGED' ||
    'ENVIRONMENT_CHANGED' => '회원 정보가 변경되었습니다. 다시 열어 주세요.',
    'CURSOR_STALE' => '목록이 변경되었습니다. 새로고침해 주세요.',
    'REQUEST_IN_PROGRESS' ||
    'IDEMPOTENCY_IN_PROGRESS' => '요청 처리 중입니다. 잠시 후 결과를 확인해 주세요.',
    _ => '현재 상태에서 처리할 수 없습니다. 새로고침 후 다시 확인해 주세요.',
  };
}

String groupDisbandReason(Object? reason) {
  if (reason is! String) return '해산 조건을 확인하지 못했습니다.';
  if (reason.contains('MEMBER')) return '그룹장 한 명만 남아 있어야 합니다.';
  if (reason.contains('PENDING') || reason.contains('RELATION')) {
    return '처리 중인 초대·가입 신청을 먼저 정리해 주세요.';
  }
  if (reason.contains('UNAVAILABLE')) {
    return '연결된 레이드 상태를 확인하지 못했습니다. 새로고침해 주세요.';
  }
  if (reason.contains('RECRUITMENT') ||
      reason.contains('RAID') ||
      reason.contains('ROOM')) {
    return '활성 그룹 전용 레이드가 있습니다. 해당 공대장이 정리한 뒤 다시 시도해 주세요.';
  }
  return '현재는 그룹을 해산할 수 없습니다. 멤버·요청·연결 레이드 상태를 확인해 주세요.';
}
