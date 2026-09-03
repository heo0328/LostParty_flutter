import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/mappers/character_activity_write_plan.dart';
import 'package:lost_party/features/account/domain/entities/owned_activity_character.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';

void main() {
  test(
    'writes one activity document per owned character without identity fields',
    () {
      const timestamp = Object();
      final plan = CharacterActivityWritePlan.fromValidated(
        playerId: 'player-1',
        command: SaveActivityCharactersCommand(
          activityCharacterIds: {'char-1'},
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
            characterName: '대표',
            serverName: '루페온',
            characterClassName: '바드',
            itemLevel: 1680,
            combatPower: 2100,
          ),
          OwnedActivityCharacter(
            characterId: 'char-2',
            gameAccountId: 'account-1',
            ownerPlayerId: 'player-1',
            status: 'active',
            ownershipStatus: 'active',
            representativeCharacterId: 'char-1',
            characterName: '부캐',
            serverName: '루페온',
            characterClassName: '바드',
          ),
        ],
        serverTimestamp: timestamp,
      );

      expect(plan.activityCharacterIds, ['char-1']);
      expect(plan.characterIdsToRemove, ['char-2']);
      expect(plan.documentsByCharacterId.keys, {'char-1'});
      expect(plan.documentsByCharacterId['char-1'], {
        'schemaVersion': 1,
        'playerId': 'player-1',
        'characterId': 'char-1',
        'gameAccountId': 'account-1',
        'updatedAt': timestamp,
      });
      expect(plan.projectionDocumentsByCharacterId['char-1'], {
        'schemaVersion': 1,
        'playerId': 'player-1',
        'characterId': 'char-1',
        'characterName': '대표',
        'serverName': '루페온',
        'characterClassName': '바드',
        'itemLevel': 1680,
        'combatPower': 2100,
        'displayOrder': 0,
        'isRepresentative': true,
        'updatedAt': timestamp,
      });
      expect(
        plan.projectionDocumentsByCharacterId['char-1']!.containsKey(
          'gameAccountId',
        ),
        isFalse,
      );
      expect(
        plan.documentsByCharacterId['char-1']!.containsKey('ownerPlayerId'),
        isFalse,
      );
      expect(
        plan.documentsByCharacterId['char-1']!.containsKey('status'),
        isFalse,
      );
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

  test(
    'keeps caller display order and representative flags on projections',
    () {
      const timestamp = Object();
      final plan = CharacterActivityWritePlan.fromValidated(
        playerId: 'player-1',
        command: SaveActivityCharactersCommand(
          activityCharacterIds: {'char-1', 'char-2'},
          ownedCharacterIds: {'char-1', 'char-2'},
          orderedActivityCharacterIds: const ['char-2', 'char-1'],
        ),
        ownedCharacters: const [
          OwnedActivityCharacter(
            characterId: 'char-1',
            gameAccountId: 'account-1',
            ownerPlayerId: 'player-1',
            status: 'active',
            ownershipStatus: 'active',
            representativeCharacterId: 'char-1',
            characterName: '대표',
            serverName: '루페온',
            characterClassName: '바드',
          ),
          OwnedActivityCharacter(
            characterId: 'char-2',
            gameAccountId: 'account-1',
            ownerPlayerId: 'player-1',
            status: 'active',
            ownershipStatus: 'active',
            representativeCharacterId: 'char-1',
            characterName: '부캐',
            serverName: '루페온',
            characterClassName: '바드',
          ),
        ],
        serverTimestamp: timestamp,
      );

      expect(plan.activityCharacterIds, ['char-2', 'char-1']);
      expect(
        plan.projectionDocumentsByCharacterId['char-2']!['displayOrder'],
        0,
      );
      expect(
        plan.projectionDocumentsByCharacterId['char-1']!['displayOrder'],
        1,
      );
      expect(
        plan.projectionDocumentsByCharacterId['char-2']!['isRepresentative'],
        isFalse,
      );
    },
  );
}
