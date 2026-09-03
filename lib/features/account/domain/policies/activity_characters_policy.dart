import '../entities/owned_activity_character.dart';
import '../entities/save_activity_characters_command.dart';

class ActivityCharactersPolicy {
  const ActivityCharactersPolicy();

  static final _invalidIdPattern = RegExp(r'[/]');

  ActivityCharactersSaveFailure? validate({
    required String playerId,
    required SaveActivityCharactersCommand command,
    required List<OwnedActivityCharacter> ownedCharacters,
  }) {
    if (playerId.trim().isEmpty) {
      return ActivityCharactersSaveFailure.unauthenticated;
    }

    final activityIds = _normalized(command.activityCharacterIds);
    final ownedIds = _normalized(command.ownedCharacterIds);
    if (activityIds.length != command.activityCharacterIds.length ||
        ownedIds.length != command.ownedCharacterIds.length) {
      return ActivityCharactersSaveFailure.invalidCharacterId;
    }
    if (activityIds.isEmpty) {
      return ActivityCharactersSaveFailure.emptySelection;
    }
    if (ownedIds.isEmpty || !ownedIds.containsAll(activityIds)) {
      return ActivityCharactersSaveFailure.notOwned;
    }
    final orderedIds = command.orderedActivityCharacterIds;
    if (orderedIds.isNotEmpty) {
      if (orderedIds.length != activityIds.length ||
          orderedIds.toSet().length != orderedIds.length ||
          !activityIds.containsAll(orderedIds) ||
          orderedIds.any((id) => id.trim() != id || id.isEmpty)) {
        return ActivityCharactersSaveFailure.invalidCharacterId;
      }
    }

    final byId = <String, OwnedActivityCharacter>{};
    for (final character in ownedCharacters) {
      if (byId.containsKey(character.characterId)) {
        return ActivityCharactersSaveFailure.invalidCharacterId;
      }
      byId[character.characterId] = character;
    }
    if (byId.length != ownedIds.length) {
      return ActivityCharactersSaveFailure.notOwned;
    }

    final requiredRepresentatives = <String>{};
    for (final characterId in ownedIds) {
      final character = byId[characterId];
      if (character == null) {
        return ActivityCharactersSaveFailure.notOwned;
      }
      if (character.ownerPlayerId != playerId) {
        return ActivityCharactersSaveFailure.notOwned;
      }
      if (!character.isActiveCharacter) {
        return ActivityCharactersSaveFailure.inactiveCharacter;
      }
      if (!character.isActiveOwnership) {
        return ActivityCharactersSaveFailure.inactiveOwnership;
      }
      final representativeId = character.representativeCharacterId;
      if (representativeId != null && representativeId.isNotEmpty) {
        requiredRepresentatives.add(representativeId);
      }
    }

    if (!activityIds.containsAll(requiredRepresentatives)) {
      return ActivityCharactersSaveFailure.representativeRequired;
    }

    for (final characterId in activityIds) {
      if (!byId[characterId]!.hasDisplayFields) {
        return ActivityCharactersSaveFailure.incompleteDisplay;
      }
    }
    return null;
  }

  Set<String> _normalized(Set<String> ids) {
    final normalized = <String>{};
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || _invalidIdPattern.hasMatch(trimmed)) {
        return const {};
      }
      normalized.add(trimmed);
    }
    return normalized;
  }
}
