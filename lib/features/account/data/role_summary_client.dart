import 'dart:convert';

import '../domain/account_read_session.dart';
import '../domain/entities/character_build_role.dart';
import '../domain/role_summary.dart';
import '../domain/scoped_cache_models.dart';
import 'backend_account_read_api.dart';

/// P1 role wire with P2 personal-profile preferences. Explicit calls only.
class RoleSummaryClient {
  RoleSummaryClient(this.api) : baseUrl = api.dio.options.baseUrl;
  final DioBackendAccountReadApi api;
  final String baseUrl;

  void requireScope(ScopedCharacterRef ref, AccountReadScope captured) {
    requireStorageScope(ref.scope, captured);
  }

  void requireStorageScope(StorageScope scope, AccountReadScope captured) {
    requireAccountReadScope(api.session, captured);
    if (api.dio.options.baseUrl != baseUrl ||
        scope !=
            StorageScope(
              baseUrl: baseUrl,
              userId: captured.userId,
              allowHttp: true,
            )) {
      throw const AccountReadException('ENVIRONMENT_CHANGED');
    }
  }

  Future<T> _decode<T>(
    ScopedCharacterRef ref,
    Future<T> Function() action,
  ) async {
    final captured = accountReadScope(api.session);
    requireScope(ref, captured);
    try {
      final result = await action();
      requireScope(ref, captured);
      return result;
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  Future<PersonalProfile> get(ScopedCharacterRef ref) => _decode(ref, () async {
    final value = PersonalProfile.fromJson(
      (await api.request(
        '/v2/me/characters/${ref.characterId}/personal-profile',
      ))!,
    );
    roleCheck(
      value.characterId == ref.characterId && value.accountId == ref.accountId,
    );
    return value;
  });

  Future<RoleSummaryAck> put(
    ScopedCharacterRef ref,
    CharacterBuildRole role,
    String key,
    Map<String, dynamic> body,
  ) => _decode(ref, () async {
    roleShape(
      body,
      'expected_version expected_ownership_revision expected_lifecycle_revision summary',
    );
    final version = rolePositive(body['expected_version']);
    final owner = rolePositive(body['expected_ownership_revision']);
    final life = rolePositive(body['expected_lifecycle_revision']);
    final summary = RoleSummary.fromJson(roleMap(body['summary']));
    roleCheck(summary.lifecycleRevision == life);
    roleCheck(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(key),
    );
    roleCheck(utf8.encode(jsonEncode(body)).length <= 32768);
    final value = RoleSummaryAck.fromJson(
      (await api.request(
        '/v2/me/characters/${ref.characterId}/role-summaries/${role.name}',
        method: 'PUT',
        body: body,
        idempotencyKey: key,
      ))!,
    );
    roleCheck(
      value.characterId == ref.characterId &&
          value.role == role &&
          value.ownershipRevision == owner &&
          value.lifecycleRevision == life &&
          value.stored.summary!.same(summary),
    );
    roleCheck(
      value.stored.version == version || value.stored.version == version + 1,
    );
    return value;
  });
}
