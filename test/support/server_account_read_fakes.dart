import 'package:flutter/foundation.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/auth/domain/backend_auth_models.dart';

const registrationId = '11111111-1111-4111-8111-111111111111';
const characterId = '22222222-2222-4222-8222-222222222222';
const secondCharacterId = '33333333-3333-4333-8333-333333333333';
const serverTime = '2026-10-14T00:00:00Z';

Map<String, dynamic> settingsJson() => {
  'configuration_state': 'configured',
  'activity_character_ids': [characterId],
  'representative_character_id': characterId,
  'settings_version': 1,
  'ownership_revision': 1,
  'next_change_at': null,
  'selection_complete': true,
  'ineligible_character_ids': <String>[],
};
Map<String, dynamic> characterJson({
  String id = characterId,
  String name = 'sample',
}) => {
  'server_name': 'sample-server',
  'character_name': name,
  'class_name': 'sample-class',
  'character_level': 70,
  'item_level': '1700.00',
  'combat_power': null,
  'character_id': id,
  'roster_status': 'confirmed',
  'summary_fetched_at': serverTime,
  'last_confirmed_at': serverTime,
  'requires_refresh': false,
  'eligible': true,
  'power_stale': true,
  'power_fetched_at': null,
};
Map<String, dynamic> charactersJson({
  String? cursor,
  String id = characterId,
  String name = 'sample',
}) => {
  'characters': {
    'items': [characterJson(id: id, name: name)],
    'next_cursor': cursor,
  },
  'settings': settingsJson(),
  'ownership_status': 'owned',
  'roster_revision': 2,
  'server_fetched_at': serverTime,
};
Map<String, dynamic> registrationJson() => {
  'registration_id': registrationId,
  'label': 'sample-account',
  'is_main': true,
  'version': 1,
  'game_account_id': '44444444-4444-4444-8444-444444444444',
  'verification_status': 'verified',
  'ownership_status': 'owned',
  'ownership_revision': 1,
  'roster_revision': 2,
  'settings': settingsJson(),
  'representative_summary': null,
  'character_count': 2,
  'server_fetched_at': serverTime,
};
Map<String, dynamic> registrationPageJson({
  String? cursor,
  bool empty = false,
}) => {
  'items': empty ? <Object>[] : [registrationJson()],
  'next_cursor': cursor,
};

class ReadSessionFake extends ChangeNotifier implements AccountReadSession {
  @override
  bool isAuthenticated = true;
  @override
  String? userId = 'sample-user';
  @override
  int generation = 1;
  int accessCalls = 0, refreshCalls = 0, rejects = 0;
  String access = 'test-access';
  @override
  Future<String> accessToken() async {
    accessCalls++;
    return access;
  }

  @override
  Future<void> refresh() async {
    refreshCalls++;
    access = 'refreshed-access';
  }

  @override
  Future<void> reject(int generation, AuthApiException error) async {
    if (generation == this.generation) {
      rejects++;
      isAuthenticated = false;
      notifyListeners();
    }
  }

  void change({required bool authenticated, String? user}) {
    generation++;
    isAuthenticated = authenticated;
    if (user != null) userId = user;
    notifyListeners();
  }
}

class ReadApiFake implements BackendAccountReadApi {
  Future<ServerRegistrationPage> Function(String?)? onRegistrations;
  Future<ServerCharactersResponse> Function(String?)? onCharacters;
  int registrationCalls = 0, characterCalls = 0;
  @override
  Future<ServerRegistrationPage> registrations({String? cursor}) async {
    registrationCalls++;
    return onRegistrations == null
        ? ServerRegistrationPage.fromJson(registrationPageJson(empty: true))
        : onRegistrations!(cursor);
  }

  @override
  Future<ServerCharactersResponse> characters(
    String registrationId, {
    String? cursor,
  }) async {
    characterCalls++;
    return onCharacters == null
        ? ServerCharactersResponse.fromJson(charactersJson())
        : onCharacters!(cursor);
  }
}
