import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/dtos/character_profile_dto.dart';
import 'package:lost_party/features/account/data/mappers/character_profile_mapper.dart';

void main() {
  test('maps profile numbers after removing thousands separators', () {
    const dto = CharacterProfileDto(
      serverName: '루페온',
      characterName: '이슈아이',
      characterLevel: 70,
      characterClassName: '바드',
      itemAvgLevel: '1,766.66',
      combatPower: '338,229.42',
    );

    final result = dto.toDomain();

    expect(result.itemLevel, 1766.66);
    expect(result.combatPower, 338229.42);
  });

  test('keeps missing optional profile numbers as null', () {
    const dto = CharacterProfileDto(
      serverName: '루페온',
      characterName: '이슈아이',
      characterLevel: 70,
      characterClassName: '바드',
      itemAvgLevel: null,
      combatPower: null,
    );

    final result = dto.toDomain();

    expect(result.itemLevel, isNull);
    expect(result.combatPower, isNull);
  });

  test('rejects malformed combat power', () {
    const dto = CharacterProfileDto(
      serverName: '루페온',
      characterName: '이슈아이',
      characterLevel: 70,
      characterClassName: '바드',
      itemAvgLevel: '1,766.66',
      combatPower: 'invalid',
    );

    expect(dto.toDomain, throwsFormatException);
  });
}
