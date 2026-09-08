import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/services/nice_group_policy.dart';

void main() {
  const policy = NiceGroupPolicy();

  test('uses 1700 as the inclusive boundary', () {
    final result = policy.evaluate([
      _account(1, [
        _character(1, '바드', 1700),
        _character(2, '바드', 1700),
        _character(3, '도화가', 1699.99),
        _character(4, '도화가', 1700),
      ]),
    ]);

    expect(result.classNames, {'바드'});
  });

  test('combines main and secondary accounts without mixing classes', () {
    final result = policy.evaluate([
      _account(1, [_character(1, '발키리', 1710)]),
      _account(2, [_character(2, ' 발키리 ', 1700), _character(3, '홀리나이트', 1750)]),
    ]);

    expect(result.classNames, {'발키리'});
    expect(result.containsClass(' 발키리 '), isTrue);
    expect(result.containsClass('홀리나이트'), isFalse);
  });

  test('excludes roster-missing characters from the current condition', () {
    final result = policy.evaluate([
      _account(1, [
        _character(1, '도화가', 1700),
        _character(2, '도화가', 1750, isRosterMissing: true),
      ]),
    ]);

    expect(result.isEmpty, isTrue);
  });
}

LocalGameAccount _account(int id, List<LocalAccountCharacter> characters) {
  return LocalGameAccount(
    id: id,
    label: '계정 $id',
    isMain: id == 1,
    lookupCharacterName: characters.first.characterName,
    representativeCharacterId: characters.first.id,
    displayLimit: 6,
    characters: characters,
  );
}

LocalAccountCharacter _character(
  int id,
  String className,
  double itemLevel, {
  bool isRosterMissing = false,
}) {
  return LocalAccountCharacter(
    id: id,
    serverName: '루페온',
    characterName: '캐릭터$id',
    characterLevel: 70,
    characterClassName: className,
    itemLevel: itemLevel,
    combatPower: null,
    isVisible: true,
    isRosterMissing: isRosterMissing,
    displayOrder: id,
  );
}
