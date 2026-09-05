import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/services/startup_character_refresh_eligibility_policy.dart';

void main() {
  const policy = StartupCharacterRefreshEligibilityPolicy();

  test('본계정과 부계정의 인증된 1700 이상 등록 Character를 포함한다', () {
    final result = policy.eligibleCharacters([
      _account(1, active: true, characters: [_character(1, 1700)]),
      _account(2, active: true, characters: [_character(2, 1750)]),
    ]);

    expect(result.map((character) => character.id), [1, 2]);
  });

  test('미인증, 1700 미만, 원정대 이탈, 비활성 소유권을 제외한다', () {
    final result = policy.eligibleCharacters([
      _account(
        1,
        active: true,
        characters: [
          _character(1, 1699.99),
          _character(2, 1700, authenticated: false),
          _character(3, 1700, rosterMissing: true),
          _character(4, 1700),
        ],
      ),
      _account(2, active: false, characters: [_character(5, 1800)]),
    ]);

    expect(result.map((character) => character.id), [4]);
  });
}

LocalGameAccount _account(
  int id, {
  required bool active,
  required List<LocalAccountCharacter> characters,
}) => LocalGameAccount(
  id: id,
  label: '계정$id',
  isMain: id == 1,
  lookupCharacterName: '캐릭터$id',
  representativeCharacterId: characters.first.id,
  displayLimit: 6,
  serverOwnershipStatus: active ? 'active' : 'released',
  characters: characters,
);

LocalAccountCharacter _character(
  int id,
  double? itemLevel, {
  bool authenticated = true,
  bool rosterMissing = false,
}) => LocalAccountCharacter(
  id: id,
  serverCharacterId: authenticated ? 'server-$id' : null,
  serverName: '루페온',
  characterName: '캐릭터$id',
  characterLevel: 70,
  characterClassName: '바드',
  itemLevel: itemLevel,
  combatPower: 100000,
  isVisible: true,
  displayOrder: id,
  isRosterMissing: rosterMissing,
);
