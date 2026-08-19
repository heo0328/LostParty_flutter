import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/dtos/sibling_character_dto.dart';
import 'package:lost_party/features/account/data/mappers/sibling_character_mapper.dart';

void main() {
  SiblingCharacterDto createDto({String? itemAvgLevel = '1,766.66'}) {
    return SiblingCharacterDto(
      serverName: '루페온',
      characterName: '이슈아이',
      characterLevel: 70,
      characterClassName: '바드',
      itemAvgLevel: itemAvgLevel,
    );
  }

  test('maps a sibling DTO to a character summary', () {
    final summary = createDto().toDomain();

    expect(summary.serverName, '루페온');
    expect(summary.characterName, '이슈아이');
    expect(summary.characterLevel, 70);
    expect(summary.characterClassName, '바드');
    expect(summary.itemLevel, 1766.66);
  });

  test('maps a missing item level to null', () {
    expect(createDto(itemAvgLevel: null).toDomain().itemLevel, isNull);
  });

  test('rejects a malformed item level', () {
    expect(
      () => createDto(itemAvgLevel: 'not-a-number').toDomain(),
      throwsFormatException,
    );
  });
}
