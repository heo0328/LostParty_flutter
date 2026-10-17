import 'dart:convert';

import '../domain/account_read_session.dart';
import '../domain/personal_settings.dart';
import '../domain/role_summary.dart';
import '../domain/scoped_cache_models.dart';
import 'backend_account_read_api.dart';
import 'role_summary_client.dart';

/// P2 only. Reuses the authenticated transport and its error/cooldown mapping.
class PersonalSettingsClient {
  PersonalSettingsClient(this.api) : roles = RoleSummaryClient(api);
  final DioBackendAccountReadApi api;
  final RoleSummaryClient roles;

  Future<T> _request<T>(StorageScope scope, Future<T> Function() action) async {
    final session = accountReadScope(api.session);
    void current() => roles.requireStorageScope(scope, session);
    current();
    try {
      final result = await action();
      current();
      return result;
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  void _body(String key, Map<String, dynamic> body) {
    roleCheck(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(key),
    );
    roleCheck(utf8.encode(jsonEncode(body)).length <= 4096);
    rolePositive(body['expected_version']);
    rolePositive(body['expected_ownership_revision']);
  }

  Future<PersonalProfile> profile(ScopedCharacterRef ref) => roles.get(ref);

  Future<PersonalPreferences> putPreferences(
    ScopedCharacterRef ref,
    String key,
    Map<String, dynamic> body,
  ) => _request(ref.scope, () async {
    roleShape(
      body,
      'expected_version expected_ownership_revision expected_lifecycle_revision preferred_role visible display_order',
    );
    _body(key, body);
    rolePositive(body['expected_lifecycle_revision']);
    final values = PreferenceValues.fromJson({
      for (final k in ['preferred_role', 'visible', 'display_order'])
        k: body[k],
    });
    final json = (await api.request(
      '/v2/me/characters/${ref.characterId}/personal-preferences',
      method: 'PUT',
      body: body,
      idempotencyKey: key,
    ))!;
    roleShape(
      json,
      'character_id ownership_revision lifecycle_revision version preferred_role visible display_order saved_at',
    );
    roleCheck(
      roleId(json['character_id']) == ref.characterId &&
          json['ownership_revision'] is int &&
          json['ownership_revision'] == body['expected_ownership_revision'] &&
          json['lifecycle_revision'] is int &&
          json['lifecycle_revision'] == body['expected_lifecycle_revision'],
    );
    final value = PersonalPreferences.fromJson({
      for (final k in [
        'version',
        'preferred_role',
        'visible',
        'display_order',
        'saved_at',
      ])
        k: json[k],
    });
    roleCheck(jsonEncode(value.values.toJson()) == jsonEncode(values.toJson()));
    roleCheck(
      value.version == body['expected_version'] ||
          value.version == (body['expected_version'] as int) + 1,
    );
    return value;
  });

  Future<AccountPresentation> presentation(ScopedRegistrationRef ref) =>
      _request(ref.scope, () async {
        final value = AccountPresentation.fromJson(
          (await api.request(
            '/v2/me/game-accounts/${ref.registrationId}/presentation-settings',
          ))!,
        );
        roleCheck(value.registrationId == ref.registrationId);
        return value;
      });

  Future<AccountPresentation> putPresentation(
    ScopedRegistrationRef ref,
    String key,
    Map<String, dynamic> body,
  ) => _request(ref.scope, () async {
    roleShape(
      body,
      'expected_version expected_registration_version expected_ownership_revision visible_count',
    );
    _body(key, body);
    rolePositive(body['expected_registration_version']);
    presentationCount(body['visible_count']);
    final value = AccountPresentation.fromJson(
      (await api.request(
        '/v2/me/game-accounts/${ref.registrationId}/presentation-settings',
        method: 'PUT',
        body: body,
        idempotencyKey: key,
      ))!,
    );
    roleCheck(
      value.registrationId == ref.registrationId &&
          value.ownershipRevision == body['expected_ownership_revision'] &&
          value.visibleCount == body['visible_count'],
    );
    // A replay may carry the original registration version after a label edit.
    roleCheck(
      value.registrationVersion == body['expected_registration_version'],
    );
    roleCheck(
      value.version == body['expected_version'] ||
          value.version == (body['expected_version'] as int) + 1,
    );
    return value;
  });
}
