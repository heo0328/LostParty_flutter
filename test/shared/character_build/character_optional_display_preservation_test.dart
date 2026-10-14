import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/character_build/character_optional_display_preservation.dart';

void main() {
  test('유효한 combatPower와 buildIntegritySnapshot을 보존한다', () {
    final checkedAt = (DateTime.utc(2026, 9, 11)).toUtc();
    final preserved = preservedOptionalCharacterDisplayFields({
      'characterName': '캐릭터',
      'combatPower': 320000.5,
      'buildIntegritySnapshot': {
        'schemaVersion': 1,
        'status': 'error',
        'issueCodes': ['foreignClassGem'],
        'role': 'dealer',
        'checkedAt': checkedAt,
        'catalogVersion': 'v1',
      },
    });

    expect(preserved['combatPower'], 320000.5);
    expect(
      (preserved['buildIntegritySnapshot'] as Map)['checkedAt'],
      checkedAt,
    );
    expect((preserved['buildIntegritySnapshot'] as Map)['status'], 'error');
  });

  test('신규·부재·손상 필드는 보존하지 않는다', () {
    expect(preservedOptionalCharacterDisplayFields(null), isEmpty);
    expect(preservedOptionalCharacterDisplayFields(const {}), isEmpty);
    expect(
      preservedOptionalCharacterDisplayFields({
        'combatPower': double.nan,
        'buildIntegritySnapshot': {
          'schemaVersion': 1,
          'status': 'broken',
          'issueCodes': <String>[],
          'role': 'dealer',
          'checkedAt': (DateTime.utc(2026, 9, 11)).toUtc(),
          'catalogVersion': null,
        },
      }),
      isEmpty,
    );
    expect(
      preservedOptionalCharacterDisplayFields({'combatPower': -1}),
      isEmpty,
    );
  });

  test('한쪽만 유효해도 그 필드만 보존한다', () {
    final onlyPower = preservedOptionalCharacterDisplayFields({
      'combatPower': 1000,
      'buildIntegritySnapshot': 'bad',
    });
    expect(onlyPower, {'combatPower': 1000});

    final onlyIntegrity = preservedOptionalCharacterDisplayFields({
      'combatPower': 'bad',
      'buildIntegritySnapshot': {
        'schemaVersion': 1,
        'status': 'clean',
        'issueCodes': <String>[],
        'role': 'support',
        'checkedAt': DateTime.utc(2026, 9, 1),
        'catalogVersion': null,
      },
    });
    expect(onlyIntegrity.containsKey('combatPower'), isFalse);
    expect((onlyIntegrity['buildIntegritySnapshot'] as Map)['status'], 'clean');
  });
}
