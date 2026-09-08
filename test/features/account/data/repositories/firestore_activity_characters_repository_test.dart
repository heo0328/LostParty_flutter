import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/repositories/firestore_activity_characters_repository.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';

import '../../../../support/firestore_transaction_fake.dart';

void main() {
  late TransactionFirestoreFake firestore;
  late FirestoreActivityCharactersRepository repository;

  setUp(() {
    firestore = TransactionFirestoreFake();
    firestore.documents.addAll({
      'authBindings/auth-1': {'playerId': 'player-1', 'status': 'active'},
      'players/player-1': {'status': 'active'},
      'playerGameAccounts/player-1_account-1': {
        'playerId': 'player-1',
        'gameAccountId': 'account-1',
        'status': 'active',
        'representativeCharacterId': 'char-1',
      },
      'characters/char-1': {
        'schemaVersion': 1,
        'ownerPlayerId': 'player-1',
        'gameAccountId': 'account-1',
        'status': 'active',
        'characterName': '대표',
        'serverName': '루페온',
        'characterClassName': '바드',
        'itemAvgLevel': '1,680.00',
        'combatPower': 2100,
      },
      'characters/char-2': {
        'schemaVersion': 1,
        'ownerPlayerId': 'player-1',
        'gameAccountId': 'account-1',
        'status': 'active',
        'characterName': '부캐',
        'serverName': '루페온',
        'characterClassName': '바드',
      },
    });
    repository = FirestoreActivityCharactersRepository(
      firestore: firestore,
      firebaseAuth: TransactionAuthFake(),
    );
  });

  test(
    'saves one activity document per character without changing identity',
    () async {
      final saved = await repository.save(
        SaveActivityCharactersCommand(
          activityCharacterIds: {'char-1', 'char-2'},
          ownedCharacterIds: {'char-1', 'char-2'},
        ),
      );

      expect(saved.characterIds, {'char-1', 'char-2'});
      final loaded = await repository.load(playerId: 'player-1');
      expect(loaded.characterIds, {'char-1', 'char-2'});
      expect(
        firestore.documents['players/player-1/characterActivity/char-1'],
        containsPair('characterId', 'char-1'),
      );
      expect(
        firestore.documents['players/player-1/characterActivity/char-2'],
        containsPair('gameAccountId', 'account-1'),
      );
      expect(
        firestore.documents.containsKey(
          'players/player-1/activityCharacterProjections/char-1',
        ),
        isFalse,
      );
      expect(
        firestore.documents.containsKey(
          'players/player-1/characterActivity/current',
        ),
        isFalse,
      );
      expect(
        firestore.documents['characters/char-1']!['ownerPlayerId'],
        'player-1',
      );
      expect(firestore.documents['characters/char-1']!['status'], 'active');
      expect(firestore.documents['characters/char-1']!['characterName'], '대표');
    },
  );

  test('removes activity documents for characters that left the set', () async {
    firestore.documents['players/player-1/characterActivity/char-2'] = {
      'schemaVersion': 1,
      'playerId': 'player-1',
      'characterId': 'char-2',
      'gameAccountId': 'account-1',
    };

    await repository.save(
      const SaveActivityCharactersCommand(
        activityCharacterIds: {'char-1'},
        ownedCharacterIds: {'char-1', 'char-2'},
      ),
    );

    expect(
      firestore.documents.containsKey(
        'players/player-1/characterActivity/char-1',
      ),
      isTrue,
    );
    expect(
      firestore.documents.containsKey(
        'players/player-1/characterActivity/char-2',
      ),
      isFalse,
    );
  });

  test('loads an empty set when no activity documents exist', () async {
    final loaded = await repository.load(playerId: 'player-1');
    expect(loaded.characterIds, isEmpty);
  });

  test('rejects zero activity characters before writing', () async {
    await expectLater(
      repository.save(
        const SaveActivityCharactersCommand(
          activityCharacterIds: {},
          ownedCharacterIds: {'char-1', 'char-2'},
        ),
      ),
      throwsA(
        isA<ActivityCharactersSaveException>().having(
          (error) => error.failure,
          'failure',
          ActivityCharactersSaveFailure.emptySelection,
        ),
      ),
    );
    expect(
      firestore.documents.keys.where(
        (path) => path.startsWith('players/player-1/characterActivity/'),
      ),
      isEmpty,
    );
  });

  test('rejects a save that leaves the representative inactive', () async {
    await expectLater(
      repository.save(
        const SaveActivityCharactersCommand(
          activityCharacterIds: {'char-2'},
          ownedCharacterIds: {'char-1', 'char-2'},
        ),
      ),
      throwsA(
        isA<ActivityCharactersSaveException>().having(
          (error) => error.failure,
          'failure',
          ActivityCharactersSaveFailure.representativeRequired,
        ),
      ),
    );
    expect(firestore.writes, isEmpty);
  });

  test('maps permission-denied to a rules-deploy guidance message', () async {
    firestore.commitError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );

    await expectLater(
      repository.save(
        const SaveActivityCharactersCommand(
          activityCharacterIds: {'char-1'},
          ownedCharacterIds: {'char-1', 'char-2'},
        ),
      ),
      throwsA(
        isA<ActivityCharactersSaveException>()
            .having(
              (error) => error.failure,
              'failure',
              ActivityCharactersSaveFailure.permissionDenied,
            )
            .having(
              (error) => error.message,
              'message',
              contains('Firestore Rules'),
            ),
      ),
    );
    expect(firestore.writes, isEmpty);
  });

  test('rejects characters that are not actively owned', () async {
    firestore.documents['characters/char-2']!['ownerPlayerId'] = 'player-2';
    await expectLater(
      repository.save(
        const SaveActivityCharactersCommand(
          activityCharacterIds: {'char-1', 'char-2'},
          ownedCharacterIds: {'char-1', 'char-2'},
        ),
      ),
      throwsA(
        isA<ActivityCharactersSaveException>().having(
          (error) => error.failure,
          'failure',
          ActivityCharactersSaveFailure.notOwned,
        ),
      ),
    );
    expect(firestore.writes, isEmpty);
  });

  test('loads activity documents without writing a projection collection', () async {
    await repository.save(
      const SaveActivityCharactersCommand(
        activityCharacterIds: {'char-1', 'char-2'},
        ownedCharacterIds: {'char-1', 'char-2'},
        orderedActivityCharacterIds: ['char-2', 'char-1'],
      ),
    );

    final loaded = await repository.load(playerId: 'player-1');
    expect(loaded.characterIds, {'char-1', 'char-2'});
    expect(
      firestore.documents.keys.where(
        (path) => path.contains('activityCharacterProjections'),
      ),
      isEmpty,
    );
  });

  test('loads an empty projection list when none are saved', () async {
    final projections = await repository.loadProjections(playerId: 'player-1');
    expect(projections, isEmpty);
  });
}
