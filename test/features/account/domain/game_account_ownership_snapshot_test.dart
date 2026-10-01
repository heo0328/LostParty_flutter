import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/game_account_ownership_snapshot.dart';

void main() {
  Map<String, dynamic> data({int? revision, String owner = 'A'}) => {
    'ownerPlayerId': owner,
    'status': 'active',
    'ownershipRevision': ?revision,
  };
  GameAccountOwnershipSnapshot inspect({int? revision, String owner = 'A'}) =>
      GameAccountOwnershipSnapshot.inspect(
        playerId: 'A',
        gameAccountId: 'roster',
        account: data(revision: revision, owner: owner),
        character: {
          ...data(revision: revision, owner: owner),
          'gameAccountId': 'roster',
        },
      );

  test(
    'legacy relation stays valid only while current ownership is legacy',
    () {
      expect(
        inspect().classifyParticipation({}),
        GameAccountOwnershipCondition.current,
      );
      expect(
        inspect(revision: 1).classifyParticipation({}),
        GameAccountOwnershipCondition.ownershipChanged,
      );
    },
  );
  test('A-B-A cannot approve the original application again', () {
    final returned = inspect(revision: 3);
    expect(returned.condition, GameAccountOwnershipCondition.current);
    expect(
      returned.classifyParticipation({'ownershipRevision': 1}),
      GameAccountOwnershipCondition.ownershipChanged,
    );
    expect(
      returned.classifyParticipation({'ownershipRevision': 3}),
      GameAccountOwnershipCondition.current,
    );
    expect(
      inspect(owner: 'B', revision: 2).condition,
      GameAccountOwnershipCondition.ownershipChanged,
    );
  });
  test('missing or mismatched authority is unknown, never a cleanup proof', () {
    for (final account in <Map<String, dynamic>?>[
      null,
      data(revision: 2),
      {...data(revision: 1), 'status': 'archived'},
    ]) {
      final result = GameAccountOwnershipSnapshot.inspect(
        playerId: 'A',
        gameAccountId: 'roster',
        account: account,
        character: {...data(revision: 1), 'gameAccountId': 'roster'},
      );
      expect(result.condition, GameAccountOwnershipCondition.unknown);
    }
  });
  test('invalid and future participation generations are unknown', () {
    for (final value in [null, -1, 1.5, '1', 4]) {
      expect(
        inspect(
          revision: 3,
        ).classifyParticipation({'ownershipRevision': value}),
        GameAccountOwnershipCondition.unknown,
      );
    }
  });
}
