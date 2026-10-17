import '../domain/account_read_session.dart';
import '../domain/scoped_cache_models.dart';
import 'backend_account_read_api.dart';
import 'local/scoped_command_key.dart';

/// Dedicated representative contract from the published P2 OpenAPI.
class RepresentativeState {
  RepresentativeState.fromJson(Map<String, dynamic> json) {
    const fields =
        'registration_id game_account_id is_main registration_version settings_version ownership_revision roster_revision representative_character_id configuration_state next_change_at';
    final keys = fields.split(' ');
    if (json.length != keys.length || !keys.every(json.containsKey)) {
      throw const FormatException('Invalid representative fields');
    }
    registrationId = cacheUuid(json['registration_id'] as String);
    accountId = cacheUuid(json['game_account_id'] as String);
    isMain = json['is_main'] as bool;
    registrationVersion = json['registration_version'] as int;
    settingsVersion = json['settings_version'] as int;
    ownershipRevision = json['ownership_revision'] as int;
    rosterRevision = json['roster_revision'] as int;
    characterId = json['representative_character_id'] == null
        ? null
        : cacheUuid(json['representative_character_id'] as String);
    state = json['configuration_state'] as String;
    if ([
          registrationVersion,
          settingsVersion,
          ownershipRevision,
          rosterRevision,
        ].any((v) => v < 1) ||
        !{
          'unconfigured',
          'configured',
          'needs_reconfiguration',
        }.contains(state) ||
        json['next_change_at'] != null) {
      throw const FormatException('Invalid representative state');
    }
  }
  late final String registrationId, accountId, state;
  late final String? characterId;
  late final bool isMain;
  late final int registrationVersion,
      settingsVersion,
      ownershipRevision,
      rosterRevision;

  bool matches(CacheRegistrationSnapshot r) =>
      registrationId == r.registrationId &&
      accountId == r.accountId &&
      isMain == r.isMain &&
      registrationVersion == r.version &&
      settingsVersion == r.settings.version &&
      ownershipRevision == r.ownershipRevision &&
      rosterRevision == r.rosterRevision &&
      characterId == r.settings.representativeId &&
      state == r.settings.state;
}

/// Frozen at confirmation; retries never create a different body or key.
class RepresentativeCommand {
  RepresentativeCommand(this.before, String target)
    : characterId = cacheUuid(target),
      key = newScopedCommandKey();
  final RepresentativeState before;
  final String characterId, key;
  Map<String, dynamic> get body => Map.unmodifiable({
    'character_id': characterId,
    'expected_registration_version': before.registrationVersion,
    'expected_settings_version': before.settingsVersion,
    'expected_ownership_revision': before.ownershipRevision,
    'expected_roster_revision': before.rosterRevision,
  });
}

class RepresentativeClient {
  RepresentativeClient(this.api) : _baseUrl = api.dio.options.baseUrl;
  final DioBackendAccountReadApi api;
  final String _baseUrl;
  Future<RepresentativeState> _request(
    ScopedRegistrationRef ref, {
    RepresentativeCommand? command,
    required void Function() guard,
  }) async {
    final session = accountReadScope(api.session);
    void current() {
      requireAccountReadScope(api.session, session);
      if (api.dio.options.baseUrl != _baseUrl ||
          ref.scope !=
              StorageScope(
                baseUrl: _baseUrl,
                userId: session.userId,
                allowHttp: true,
              )) {
        throw const AccountReadException('ENVIRONMENT_CHANGED');
      }
      guard();
    }

    current();
    if (command != null &&
        command.before.registrationId != ref.registrationId) {
      throw const AccountReadException('SCOPE_MISMATCH');
    }
    try {
      final json = await api.request(
        '/v1/me/game-accounts/${ref.registrationId}/representative',
        method: command == null ? 'GET' : 'PUT',
        body: command?.body,
        idempotencyKey: command?.key,
      );
      current();
      final result = RepresentativeState.fromJson(json!);
      if (result.registrationId != ref.registrationId ||
          (command != null &&
              (result.accountId != command.before.accountId ||
                  result.characterId != command.characterId ||
                  !result.isMain ||
                  result.registrationVersion !=
                      command.before.registrationVersion ||
                  result.ownershipRevision !=
                      command.before.ownershipRevision ||
                  result.rosterRevision != command.before.rosterRevision ||
                  result.state != command.before.state ||
                  (result.settingsVersion != command.before.settingsVersion &&
                      result.settingsVersion !=
                          command.before.settingsVersion + 1)))) {
        throw const FormatException('Mismatched representative');
      }
      return result;
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    } on ScopedCacheException {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  Future<RepresentativeState> get(
    ScopedRegistrationRef ref, {
    required void Function() guard,
  }) => _request(ref, guard: guard);
  Future<RepresentativeState> put(
    ScopedRegistrationRef ref,
    RepresentativeCommand command, {
    required void Function() guard,
  }) => _request(ref, command: command, guard: guard);
}
