import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/mappers/character_activity_write_plan.dart';
import 'package:lost_party/features/account/domain/entities/owned_activity_character.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';

void main() {
  test(
    'writes the complete activity set without character identity fields',
    () {
      const timestamp = Object();
      final plan = CharacterActivityWritePlan.fromValidated(
        playerId: 'player-1',
        command: SaveActivityCharactersCommand(
          activityCharacterIds: {'char-2', 'char-1'},
          ownedCharacterIds: {'char-1', 'char-2'},
        ),
        ownedCharacters: const [
          OwnedActivityCharacter(
            characterId: 'char-1',
            gameAccountId: 'account-1',
            ownerPlayerId: 'player-1',
            status: 'active',
            ownershipStatus: 'active',
            representativeCharacterId: 'char-1',
          ),
          OwnedActivityCharacter(
            characterId: 'char-2',
            gameAccountId: 'account-2',
            ownerPlayerId: 'player-1',
            status: 'active',
            ownershipStatus: 'active',
          ),
        ],
        serverTimestamp: timestamp,
      );

      expect(plan.document.keys, {
        'schemaVersion',
        'playerId',
        'activityCharacterIds',
        'gameAccountIds',
        'updatedAt',
      });
      expect(plan.document['schemaVersion'], 1);
      expect(plan.document['playerId'], 'player-1');
      expect(plan.document['activityCharacterIds'], ['char-1', 'char-2']);
      expect(plan.document['gameAccountIds'], ['account-1', 'account-2']);
      expect(plan.document['updatedAt'], same(timestamp));
      expect(plan.document.containsKey('ownerPlayerId'), isFalse);
      expect(plan.document.containsKey('status'), isFalse);
    },
  );

  test('rejects zero activity characters before creating a write plan', () {
    expect(
      () => CharacterActivityWritePlan.fromValidated(
        playerId: 'player-1',
        command: const SaveActivityCharactersCommand(
          activityCharacterIds: {},
          ownedCharacterIds: {'char-1'},
        ),
        ownedCharacters: const [
          OwnedActivityCharacter(
            characterId: 'char-1',
            gameAccountId: 'account-1',
            ownerPlayerId: 'player-1',
            status: 'active',
            ownershipStatus: 'active',
            representativeCharacterId: 'char-1',
          ),
        ],
        serverTimestamp: Object(),
      ),
      throwsA(
        isA<ActivityCharactersSaveException>().having(
          (error) => error.failure,
          'failure',
          ActivityCharactersSaveFailure.emptySelection,
        ),
      ),
    );
  });
}
