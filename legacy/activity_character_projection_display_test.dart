import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/activity_character_projection.dart';
import 'package:lost_party/features/group/domain/mappers/activity_character_projection_display.dart';

void main() {
  test('Projection을 그룹 표시 Character로 옮기고 소유권 필드는 만들지 않는다', () {
    const projection = ActivityCharacterProjection(
      playerId: 'player-2',
      characterId: 'char-21',
      characterName: '딜러A',
      serverName: '루페온',
      characterClassName: '블레이드',
      displayOrder: 0,
      isRepresentative: false,
      itemLevel: 1680,
      combatPower: 2100,
    );

    final character = groupRequestCharacterFromProjection(projection);
    expect(character.characterId, 'char-21');
    expect(character.ownerPlayerId, 'player-2');
    expect(character.characterName, '딜러A');
    expect(character.itemLevel, 1680);
    expect(character.combatPower, 2100);
  });
}
