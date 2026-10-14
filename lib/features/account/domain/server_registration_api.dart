import 'server_account_models.dart';

abstract interface class BackendRegistrationApi {
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  });
}

class ServerRegistrationPreview {
  ServerRegistrationPreview.fromJson(Map<String, dynamic> json) {
    const keys = {'characters', 'server_fetched_at', 'expires_at'};
    if (json.keys.toSet().difference(keys).isNotEmpty ||
        !keys.every(json.containsKey)) {
      throw const FormatException('Invalid preview.');
    }
    final items = json['characters'];
    if (items is! List || items.isEmpty || items.length > 200) {
      throw const FormatException('Invalid preview.');
    }
    characters = List.unmodifiable(
      items.map(
        (item) => ServerCharacterSummary.fromJson(item as Map<String, dynamic>),
      ),
    );
    final identities = characters
        .map((c) => (c.serverName, c.characterName))
        .toSet();
    if (identities.length != characters.length) {
      throw const FormatException('Duplicate preview.');
    }
    DateTime utc(Object? value) {
      if (value is! String || !value.endsWith('Z')) {
        throw const FormatException('Invalid time.');
      }
      return DateTime.parse(value).toUtc();
    }

    fetchedAt = utc(json['server_fetched_at']);
    expiresAt = utc(json['expires_at']);
    if (!expiresAt.isAfter(fetchedAt)) {
      throw const FormatException('Invalid expiry.');
    }
  }
  late final List<ServerCharacterSummary> characters;
  late final DateTime fetchedAt, expiresAt;
}

class ServerRegistrationRefresh {
  ServerRegistrationRefresh.fromJson(Map<String, dynamic> json) {
    const keys = {
      'registration',
      'added_count',
      'suspect_count',
      'requires_refresh',
    };
    if (json.length != keys.length ||
        !keys.every(json.containsKey) ||
        json['registration'] is! Map<String, dynamic> ||
        json['added_count'] is! int ||
        json['suspect_count'] is! int ||
        json['requires_refresh'] is! bool) {
      throw const FormatException('Invalid refresh response.');
    }
    registration = ServerAccountRegistration.fromJson(
      json['registration'] as Map<String, dynamic>,
    );
    addedCount = json['added_count'] as int;
    suspectCount = json['suspect_count'] as int;
    requiresRefresh = json['requires_refresh'] as bool;
    if (addedCount < 0 || suspectCount < 0) {
      throw const FormatException('Invalid refresh counts.');
    }
  }
  late final ServerAccountRegistration registration;
  late final int addedCount, suspectCount;
  late final bool requiresRefresh;
}
