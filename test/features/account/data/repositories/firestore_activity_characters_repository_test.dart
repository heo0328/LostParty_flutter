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
      },
      'characters/char-2': {
        'schemaVersion': 1,
        'ownerPlayerId': 'player-1',
        'gameAccountId': 'account-1',
        'status': 'active',
        'characterName': '부캐',
      },
    });
    repository = FirestoreActivityCharactersRepository(
      firestore: firestore,
      firebaseAuth: TransactionAuthFake(),
    );
  });

  test(
    'saves the complete activity set without changing character identity',
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
      final activity =
          firestore.documents['players/player-1/characterActivity/current']!;
      expect(activity['playerId'], 'player-1');
      expect(activity['activityCharacterIds'], ['char-1', 'char-2']);
      expect(activity['gameAccountIds'], ['account-1']);
      expect(activity.containsKey('ownerPlayerId'), isFalse);
      expect(
        firestore.documents['characters/char-1']!['ownerPlayerId'],
        'player-1',
      );
      expect(firestore.documents['characters/char-1']!['status'], 'active');
      expect(firestore.documents['characters/char-1']!['characterName'], '대표');
      expect(
        firestore.documents['playerGameAccounts/player-1_account-1']!['status'],
        'active',
      );
    },
  );

  test('loads an empty set when the activity document is missing', () async {
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
      firestore.documents.containsKey(
        'players/player-1/characterActivity/current',
      ),
      isFalse,
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
}
