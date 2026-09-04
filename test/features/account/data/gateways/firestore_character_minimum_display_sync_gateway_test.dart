import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/gateways/firestore_character_minimum_display_sync_gateway.dart';
import 'package:lost_party/features/account/domain/repositories/character_minimum_display_sync_gateway.dart';

import '../../../../support/firestore_transaction_fake.dart';

void main() {
  late TransactionFirestoreFake firestore;
  late FirestoreCharacterMinimumDisplaySyncGateway gateway;

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
        'characterName': '캐릭터',
        'itemAvgLevel': '1700',
        'combatPower': 2500.0,
      },
    });
    gateway = FirestoreCharacterMinimumDisplaySyncGateway(
      firestore: firestore,
      firebaseAuth: TransactionAuthFake(),
    );
  });

  test('값이 달라진 itemAvgLevel과 combatPower만 갱신한다', () async {
    final wrote = await gateway.syncMinimumDisplay(
      const CharacterMinimumDisplayPatch(
        serverCharacterId: 'character-1',
        itemLevel: 1720.5,
        combatPower: 3100,
      ),
    );
    expect(wrote, isTrue);
    final character = firestore.documents['characters/character-1']!;
    expect(character['itemAvgLevel'], '1720.5');
    expect(character['combatPower'], 3100);
    expect(character['characterName'], '캐릭터');
  });

  test('동일값이면 쓰기를 생략한다', () async {
    final wrote = await gateway.syncMinimumDisplay(
      const CharacterMinimumDisplayPatch(
        serverCharacterId: 'character-1',
        itemLevel: 1700,
        combatPower: 2500,
      ),
    );
    expect(wrote, isFalse);
    expect(firestore.writes, isEmpty);
  });

  test('천 단위 구분 문자열도 동일 itemLevel로 취급한다', () async {
    firestore.documents['characters/character-1']!['itemAvgLevel'] = '1,700.00';
    final wrote = await gateway.syncMinimumDisplay(
      const CharacterMinimumDisplayPatch(
        serverCharacterId: 'character-1',
        itemLevel: 1700,
      ),
    );
    expect(wrote, isFalse);
    expect(firestore.writes, isEmpty);
  });

  test('null 필드는 기존 서버 값을 지우지 않는다', () async {
    await gateway.syncMinimumDisplay(
      const CharacterMinimumDisplayPatch(
        serverCharacterId: 'character-1',
        itemLevel: 1710,
      ),
    );
    final character = firestore.documents['characters/character-1']!;
    expect(character['itemAvgLevel'], '1710');
    expect(character['combatPower'], 2500.0);
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
        gateway.syncMinimumDisplay(
          const CharacterMinimumDisplayPatch(
            serverCharacterId: 'character-1',
            combatPower: 3100,
          ),
        ),
        throwsStateError,
      );
      expect(firestore.writes, isEmpty);
    });
  }
}
