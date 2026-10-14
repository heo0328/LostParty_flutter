import 'account_read_session.dart';
import 'server_account_models.dart';

abstract interface class BackendAccountReadApi {
  Future<ServerRegistrationPage> registrations({String? cursor});
  Future<ServerCharactersResponse> characters(
    String registrationId, {
    String? cursor,
  });
}

class ServerAccountReadRepository {
  const ServerAccountReadRepository(this.api, this.session);
  final BackendAccountReadApi api;
  final AccountReadSession session;

  Future<List<ServerAccountRegistration>> loadRegistrations() async {
    final scope = accountReadScope(session);
    final items = <ServerAccountRegistration>[];
    final ids = <String>{};
    final cursors = <String>{};
    String? cursor;
    for (var page = 0; page < 21; page++) {
      final result = await api.registrations(cursor: cursor);
      requireAccountReadScope(session, scope);
      for (final item in result.items) {
        if (!ids.add(item.registrationId) || item.characterCount > 200) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        items.add(item);
      }
      if (items.length > 20 || items.where((item) => item.isMain).length > 1) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
      cursor = _next(result.nextCursor, cursors);
      if (cursor == null) return List.unmodifiable(items);
      if (result.items.isEmpty) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
    }
    throw const AccountReadException('INVALID_RESPONSE');
  }

  Future<ServerAccountRoster> loadCharacters(String registrationId) async {
    final scope = accountReadScope(session);
    final items = <ServerAccountCharacter>[];
    final identities = <String>{};
    final cursors = <String>{};
    ServerCharactersResponse? first;
    String? cursor;
    for (var page = 0; page < 201; page++) {
      final result = await api.characters(registrationId, cursor: cursor);
      requireAccountReadScope(session, scope);
      first ??= result;
      if (result.rosterRevision != first.rosterRevision ||
          result.settings.settingsVersion != first.settings.settingsVersion ||
          result.settings.ownershipRevision !=
              first.settings.ownershipRevision ||
          result.ownershipStatus != first.ownershipStatus ||
          !_sameSettings(result.settings, first.settings)) {
        throw const AccountReadException('CURSOR_STALE', status: 409);
      }
      for (final item in result.characters.items) {
        final identity = '${item.serverName}\u0000${item.characterName}';
        if (!identities.add(identity) ||
            (item.characterId != null &&
                items.any((old) => old.characterId == item.characterId))) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        items.add(item);
      }
      if (items.length > 200) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
      cursor = _next(result.characters.nextCursor, cursors);
      if (cursor == null) {
        // Preserve the exact first-page settings after checking every page.
        final combined = ServerAccountRoster(first, items);
        return combined;
      }
      if (result.characters.items.isEmpty) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
    }
    throw const AccountReadException('INVALID_RESPONSE');
  }

  String? _next(String? cursor, Set<String> seen) {
    if (cursor == null) return null;
    if (cursor.isEmpty || cursor.length > 2048 || !seen.add(cursor)) {
      throw const AccountReadException('INVALID_RESPONSE');
    }
    return cursor;
  }

  bool _sameSettings(ServerCharacterSettings a, ServerCharacterSettings b) =>
      a.configurationState == b.configurationState &&
      a.representativeCharacterId == b.representativeCharacterId &&
      a.nextChangeAt == b.nextChangeAt &&
      _sameIds(a.activityCharacterIds, b.activityCharacterIds) &&
      _sameIds(a.ineligibleCharacterIds, b.ineligibleCharacterIds);

  bool _sameIds(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}
