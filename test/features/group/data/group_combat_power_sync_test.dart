import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/gateways/firestore_character_combat_power_sync_gateway.dart';
import 'package:lost_party/features/group/data/repositories/firestore_group_join_command_repository.dart';
import 'package:lost_party/features/group/domain/entities/group_member_display_snapshot.dart';
import 'package:lost_party/features/group/domain/entities/group_member_display_snapshot_refresh_command.dart';
import '../../../support/firestore_transaction_fake.dart';

void main() {
  late TransactionFirestoreFake firestore;
  late FirestoreCharacterCombatPowerSyncGateway gateway;
  setUp(() {
    firestore = TransactionFirestoreFake();
    firestore.documents.addAll({
      'authBindings/auth-1': {'playerId': 'player-1', 'status': 'active'},
      'players/player-1': {'status': 'active'},
      'playerGameAccounts/player-1_account-1': {'status': 'active'},
      'characters/character-1': {
        'status': 'active',
        'ownerPlayerId': 'player-1',
        'gameAccountId': 'account-1',
        'characterClassName': '바드',
        'characterName': '대표',
      },
      'characters/character-2': {
        'status': 'active',
        'ownerPlayerId': 'player-1',
        'gameAccountId': 'account-1',
        'characterClassName': '바드',
        'characterName': '부캐',
        'combatPower': 2000.0,
      },
      'groups/group-1/members/player-1': {
        'displayCharacterIdSnapshot': 'character-1',
        'displayClassNameSnapshot': '바드',
        'combatPowerSnapshot': 2500.0,
        'itemLevelSnapshot': 1700.0,
      },
    });
    gateway = FirestoreCharacterCombatPowerSyncGateway(
      firestore: firestore,
      firebaseAuth: TransactionAuthFake(),
    );
  });
  test('서버 전투력 없는 대표와 부캐를 각각 자신의 값으로 갱신한다', () async {
    await gateway.updateCombatPowers({
      'character-1': 3100,
      'character-2': 2400,
    });
    expect(firestore.documents['characters/character-1']!['combatPower'], 3100);
    expect(firestore.documents['characters/character-2']!['combatPower'], 2400);
    expect(
      firestore.documents['characters/character-1']!['characterName'],
      '대표',
    );
    firestore.writes.clear();
    await gateway.updateCombatPowers({
      'character-1': 3100,
      'character-2': 2400,
    });
    expect(firestore.writes, isEmpty);
  });
  test('값 없는 캐릭터와 빈 입력은 기존 전투력을 삭제하지 않는다', () async {
    await gateway.updateCombatPowers({});
    await gateway.updateCombatPowers({'character-1': 3100});
    expect(firestore.documents['characters/character-2']!['combatPower'], 2000);
  });
  for (final invalid in [
    'foreignOwner',
    'lostAccount',
    'inactiveCharacter',
    'inactiveBinding',
    'inactivePlayer',
  ]) {
    test('$invalid 는 쓰기 전에 거부한다', () async {
      switch (invalid) {
        case 'foreignOwner':
          firestore.documents['characters/character-1']!['ownerPlayerId'] =
              'player-2';
        case 'lostAccount':
          firestore
                  .documents['playerGameAccounts/player-1_account-1']!['status'] =
              'ownershipLost';
        case 'inactiveCharacter':
          firestore.documents['characters/character-1']!['status'] = 'inactive';
        case 'inactiveBinding':
          firestore.documents['authBindings/auth-1']!['status'] = 'inactive';
        case 'inactivePlayer':
          firestore.documents['players/player-1']!['status'] = 'inactive';
      }
      await expectLater(
        gateway.updateCombatPowers({'character-1': 3100}),
        throwsStateError,
      );
      expect(firestore.writes, isEmpty);
    });
  }
  test('본인 Snapshot 갱신에서 로컬 null은 기존 서버 숫자를 유지한다', () async {
    final repository = FirestoreGroupJoinCommandRepository(
      firestore: firestore,
      firebaseAuth: TransactionAuthFake(),
    );
    await repository.refreshMyDisplaySnapshot(
      const GroupMemberDisplaySnapshotRefreshCommand(
        groupId: 'group-1',
        snapshot: GroupMemberDisplaySnapshot(className: '바드', itemLevel: 1720),
      ),
    );
    final member = firestore.documents['groups/group-1/members/player-1']!;
    expect(member['combatPowerSnapshot'], 2500);
    expect(member['itemLevelSnapshot'], 1720);
  });
  test('본인 갱신 실패를 호출자에게 전달한다', () async {
    firestore.documents.remove('groups/group-1/members/player-1');
    final repository = FirestoreGroupJoinCommandRepository(
      firestore: firestore,
      firebaseAuth: TransactionAuthFake(),
    );
    await expectLater(
      repository.refreshMyDisplaySnapshot(
        const GroupMemberDisplaySnapshotRefreshCommand(
          groupId: 'group-1',
          snapshot: GroupMemberDisplaySnapshot(
            className: '바드',
            combatPower: 3100,
          ),
        ),
      ),
      throwsStateError,
    );
    expect(firestore.writes, isEmpty);
  });
}
