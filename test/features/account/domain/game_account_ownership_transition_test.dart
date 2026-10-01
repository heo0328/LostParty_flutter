import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/game_account_ownership_transition.dart';

void main() {
  Map<String, dynamic> account(String owner, int revision) => {
    'ownerPlayerId': owner,
    'ownershipRevision': revision,
  };

  test('reauth keeps generation but A-B-A cannot revive generation one', () {
    final first = GameAccountOwnershipTransition.fromAccount(
      account: null,
      nextOwnerPlayerId: 'A',
    );
    expect(first.nextRevision, 1);
    final same = GameAccountOwnershipTransition.fromAccount(
      account: account('A', first.nextRevision),
      nextOwnerPlayerId: 'A',
    );
    expect(same.nextRevision, 1);
    final second = GameAccountOwnershipTransition.fromAccount(
      account: account('A', same.nextRevision),
      nextOwnerPlayerId: 'B',
    );
    final returned = GameAccountOwnershipTransition.fromAccount(
      account: account('B', second.nextRevision),
      nextOwnerPlayerId: 'A',
    );
    expect(second.nextRevision, 2);
    expect(returned.nextRevision, 3);
  });

  test('legacy same owner retains zero and transfer invalidates legacy', () {
    for (final owner in ['A', 'B']) {
      final transition = GameAccountOwnershipTransition.fromAccount(
        account: {'ownerPlayerId': 'A'},
        nextOwnerPlayerId: owner,
      );
      expect(transition.nextRevision, owner == 'A' ? 0 : 1);
      transition.validateExistingCharacter(
        character: {'ownerPlayerId': 'A', 'gameAccountId': 'roster'},
        gameAccountId: 'roster',
      );
    }
  });

  test('malformed generation is not silently reset to legacy', () {
    for (final value in [null, -1, 1.5, '1', true, 9007199254740992]) {
      expect(
        () => GameAccountOwnershipTransition.fromAccount(
          account: {'ownerPlayerId': 'A', 'ownershipRevision': value},
          nextOwnerPlayerId: 'B',
        ),
        throwsFormatException,
      );
    }
    for (final owner in [null, '', 1]) {
      expect(
        () => GameAccountOwnershipTransition.fromAccount(
          account: {'ownerPlayerId': owner},
          nextOwnerPlayerId: 'B',
        ),
        throwsFormatException,
      );
    }
    expect(
      () => GameAccountOwnershipTransition.fromAccount(
        account: account('A', 9007199254740991),
        nextOwnerPlayerId: 'B',
      ),
      throwsFormatException,
    );
  });

  test('mismatched Character cannot be moved with an unrelated roster', () {
    final transition = GameAccountOwnershipTransition.fromAccount(
      account: account('A', 2),
      nextOwnerPlayerId: 'B',
    );
    final valid = {...account('A', 2), 'gameAccountId': 'roster'};
    transition.validateExistingCharacter(
      character: valid,
      gameAccountId: 'roster',
    );
    transition.validateExistingCharacter(
      character: null,
      gameAccountId: 'roster',
    );
    for (final patch in [
      {'gameAccountId': 'other'},
      {'ownerPlayerId': 'B'},
      {'ownershipRevision': 1},
      {'ownershipRevision': null},
    ]) {
      expect(
        () => transition.validateExistingCharacter(
          character: {...valid, ...patch},
          gameAccountId: 'roster',
        ),
        throwsFormatException,
      );
    }
    final fresh = GameAccountOwnershipTransition.fromAccount(
      account: null,
      nextOwnerPlayerId: 'B',
    );
    expect(
      () => fresh.validateExistingCharacter(
        character: valid,
        gameAccountId: 'roster',
      ),
      throwsFormatException,
    );
  });
}
