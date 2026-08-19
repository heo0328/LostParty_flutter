import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';

void main() {
  test('shows fewer than six when the account has fewer characters', () {
    final account = _account([
      _character(1, '첫째', 1700),
      _character(2, '둘째', 1600),
      _character(3, '셋째', 1500),
    ]);

    expect(account.visibleCharacters, hasLength(3));
  });

  test('shows the top six characters by item level by default', () {
    final account = _account([
      _character(1, '레벨1', 1500),
      _character(2, '레벨2', 1800),
      _character(3, '레벨3', 1700),
      _character(4, '레벨4', 1600),
      _character(5, '레벨5', 1400),
      _character(6, '레벨6', 1300),
      _character(7, '레벨7', 1200),
    ]);

    expect(account.visibleCharacters.map((character) => character.itemLevel), [
      1800,
      1700,
      1600,
      1500,
      1400,
      1300,
    ]);
  });

  test('uses a custom display order before item level', () {
    final account = _account([
      _character(1, '고레벨', 1800, displayOrder: 1),
      _character(2, '저레벨', 1500, displayOrder: 0),
    ]);

    expect(
      account.visibleCharacters.map((character) => character.characterName),
      ['저레벨', '고레벨'],
    );
  });
}

LocalGameAccount _account(List<LocalAccountCharacter> characters) {
  return LocalGameAccount(
    id: 1,
    label: '메인 계정',
    isMain: true,
    lookupCharacterName: characters.first.characterName,
    representativeCharacterId: characters.first.id,
    displayLimit: 6,
    characters: characters,
  );
}

LocalAccountCharacter _character(
  int id,
  String name,
  double itemLevel, {
  int? displayOrder,
}) {
  return LocalAccountCharacter(
    id: id,
    serverName: '루페온',
    characterName: name,
    characterLevel: 70,
    characterClassName: '바드',
    itemLevel: itemLevel,
    combatPower: null,
    isVisible: true,
    displayOrder: displayOrder,
  );
}
