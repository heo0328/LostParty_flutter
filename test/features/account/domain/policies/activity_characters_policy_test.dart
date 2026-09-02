import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/owned_activity_character.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/policies/activity_characters_policy.dart';

void main() {
  const policy = ActivityCharactersPolicy();

  test(
    'accepts owned activity characters that include every representative',
    () {
      expect(
        policy.validate(
          playerId: 'player-1',
          command: SaveActivityCharactersCommand(
            activityCharacterIds: {'char-1', 'char-2'},
            ownedCharacterIds: {'char-1', 'char-2', 'char-3'},
          ),
          ownedCharacters: [
            _character('char-1', representativeCharacterId: 'char-1'),
            _character('char-2'),
            _character('char-3'),
          ],
        ),
        isNull,
      );
    },
  );

  test('rejects an empty activity selection', () {
    expect(
      policy.validate(
        playerId: 'player-1',
        command: const SaveActivityCharactersCommand(
          activityCharacterIds: {},
          ownedCharacterIds: {'char-1'},
        ),
        ownedCharacters: [_character('char-1')],
      ),
      ActivityCharactersSaveFailure.emptySelection,
    );
  });

  test('rejects a representative that is not in the activity set', () {
    expect(
      policy.validate(
        playerId: 'player-1',
        command: const SaveActivityCharactersCommand(
          activityCharacterIds: {'char-2'},
          ownedCharacterIds: {'char-1', 'char-2'},
        ),
        ownedCharacters: [
          _character('char-1', representativeCharacterId: 'char-1'),
          _character('char-2'),
        ],
      ),
      ActivityCharactersSaveFailure.representativeRequired,
    );
  });

  test('rejects characters owned by another player', () {
    expect(
      policy.validate(
        playerId: 'player-1',
        command: const SaveActivityCharactersCommand(
          activityCharacterIds: {'char-1'},
          ownedCharacterIds: {'char-1'},
        ),
        ownedCharacters: [_character('char-1', ownerPlayerId: 'player-2')],
      ),
      ActivityCharactersSaveFailure.notOwned,
    );
  });

  test('rejects inactive characters and lost ownership', () {
    expect(
      policy.validate(
        playerId: 'player-1',
        command: const SaveActivityCharactersCommand(
          activityCharacterIds: {'char-1'},
          ownedCharacterIds: {'char-1'},
        ),
        ownedCharacters: [_character('char-1', status: 'archived')],
      ),
      ActivityCharactersSaveFailure.inactiveCharacter,
    );
    expect(
      policy.validate(
        playerId: 'player-1',
        command: const SaveActivityCharactersCommand(
          activityCharacterIds: {'char-1'},
          ownedCharacterIds: {'char-1'},
        ),
        ownedCharacters: [
          _character('char-1', ownershipStatus: 'ownershipLost'),
        ],
      ),
      ActivityCharactersSaveFailure.inactiveOwnership,
    );
  });

  test('rejects invalid or unowned character ids', () {
    expect(
      policy.validate(
        playerId: 'player-1',
        command: const SaveActivityCharactersCommand(
          activityCharacterIds: {'char/1'},
          ownedCharacterIds: {'char/1'},
        ),
        ownedCharacters: const [],
      ),
      ActivityCharactersSaveFailure.invalidCharacterId,
    );
    expect(
      policy.validate(
        playerId: 'player-1',
        command: const SaveActivityCharactersCommand(
          activityCharacterIds: {'char-9'},
          ownedCharacterIds: {'char-1'},
        ),
        ownedCharacters: [_character('char-1')],
      ),
      ActivityCharactersSaveFailure.notOwned,
    );
  });
}

OwnedActivityCharacter _character(
  String id, {
  String ownerPlayerId = 'player-1',
  String status = 'active',
  String ownershipStatus = 'active',
  String? representativeCharacterId,
}) {
  return OwnedActivityCharacter(
    characterId: id,
    gameAccountId: 'account-1',
    ownerPlayerId: ownerPlayerId,
    status: status,
    ownershipStatus: ownershipStatus,
    representativeCharacterId: representativeCharacterId,
  );
}
