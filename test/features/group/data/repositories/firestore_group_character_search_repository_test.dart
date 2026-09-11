import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/data/repositories/firestore_group_character_search_repository.dart';
import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

void main() {
  Map<String, dynamic> baseData() => {
    'ownerPlayerId': 'player-1',
    'characterName': '캐릭터',
    'serverName': '서버',
    'characterClassName': '바드',
    'itemAvgLevel': '1,700.00',
    'combatPower': 3000,
  };

  test('유효한 buildIntegritySnapshot을 함께 매핑한다', () {
    final character = mapGroupRequestCharacter(
      characterId: 'character-1',
      data: {
        ...baseData(),
        'buildIntegritySnapshot': {
          'schemaVersion': 1,
          'status': 'error',
          'issueCodes': ['foreignClassGem', 'arkGridMinimum'],
          'role': 'dealer',
          'checkedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 11)),
          'catalogVersion': 'v1',
        },
      },
    );

    expect(character, isNotNull);
    expect(character!.itemLevel, 1700);
    expect(character.buildIntegritySnapshot?.status, BuildIntegrityStatus.error);
    expect(character.buildIntegritySnapshot?.issueCodes, [
      BuildIntegrityIssueCode.foreignClassGem,
      BuildIntegrityIssueCode.arkGridMinimum,
    ]);
  });

  test('무결성 맵이 없거나 손상되면 Character 행만 유지한다', () {
    expect(
      mapGroupRequestCharacter(
        characterId: 'character-1',
        data: baseData(),
      )!.buildIntegritySnapshot,
      isNull,
    );
    expect(
      mapGroupRequestCharacter(
        characterId: 'character-1',
        data: {
          ...baseData(),
          'buildIntegritySnapshot': {
            'schemaVersion': 1,
            'status': 'unknown',
            'issueCodes': <String>[],
            'role': 'dealer',
            'checkedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 11)),
            'catalogVersion': null,
          },
        },
      )!.characterName,
      '캐릭터',
    );
    expect(
      mapGroupRequestCharacter(
        characterId: 'character-1',
        data: {
          ...baseData(),
          'buildIntegritySnapshot': {
            'schemaVersion': 1,
            'status': 'unknown',
            'issueCodes': <String>[],
            'role': 'dealer',
            'checkedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 11)),
            'catalogVersion': null,
          },
        },
      )!.buildIntegritySnapshot,
      isNull,
    );
  });
}
