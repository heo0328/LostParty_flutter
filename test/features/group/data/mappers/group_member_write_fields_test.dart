import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/data/mappers/group_member_write_fields.dart';
import 'package:lost_party/features/group/domain/entities/group_join_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_request_character.dart';
import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

void main() {
  final gem = PartyGemValidationSnapshot(
    status: PartyGemValidationStatus.foreignClass,
    foreignClassGemCount: 2,
    unverifiedSameClassGemCount: 0,
    validatedAt: DateTime.utc(2026, 9, 10),
    catalogVersion: '2026.09.08',
  );

  const character = GroupRequestCharacter(
    characterId: 'character-1',
    ownerPlayerId: 'player-1',
    characterName: '테스트',
    serverName: '루페온',
    characterClassName: '버서커',
    itemLevel: 1700,
    combatPower: 320,
  );

  test('Character Snapshot 필드를 membership 문서 맵으로 만든다', () {
    expect(GroupMemberWriteFields.fromCharacter(character), {
      'displayClassNameSnapshot': '버서커',
      'itemLevelSnapshot': 1700.0,
      'combatPowerSnapshot': 320.0,
      'gemValidationSnapshot': null,
    });
  });

  test('보석 요약을 Character Snapshot에 포함한다', () {
    final withGem = GroupRequestCharacter(
      characterId: character.characterId,
      ownerPlayerId: character.ownerPlayerId,
      characterName: character.characterName,
      serverName: character.serverName,
      characterClassName: character.characterClassName,
      itemLevel: character.itemLevel,
      combatPower: character.combatPower,
      gemValidation: gem,
    );
    expect(
      GroupMemberWriteFields.fromCharacter(withGem)['gemValidationSnapshot'],
      gem.toFields(),
    );
  });

  test('join relation Snapshot을 membership 문서 맵으로 복사한다', () {
    final relation = GroupJoinRelation(
      groupId: 'group-1',
      targetPlayerId: 'player-2',
      kind: GroupJoinRelationKind.application,
      status: GroupRequestStatus.accepted,
      requestedByPlayerId: 'player-2',
      characterIdSnapshot: 'character-1',
      characterNameSnapshot: '테스트',
      serverNameSnapshot: '루페온',
      characterClassNameSnapshot: '버서커',
      itemLevelSnapshot: 1700,
      combatPowerSnapshot: null,
      gemValidationSnapshot: gem,
      applicationAttempt: 1,
      revision: 2,
      createdAt: DateTime.utc(2026),
      expiresAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026),
    );

    expect(GroupMemberWriteFields.fromJoinRelation(relation), {
      'displayClassNameSnapshot': '버서커',
      'itemLevelSnapshot': 1700.0,
      'combatPowerSnapshot': null,
      'gemValidationSnapshot': gem.toFields(),
    });
  });
}
