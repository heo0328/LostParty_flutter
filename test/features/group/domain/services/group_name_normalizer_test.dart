import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/domain/services/group_name_normalizer.dart';

void main() {
  const normalizer = GroupNameNormalizer();

  test('앞뒤 공백을 제거하고 영문을 소문자로 낮춘다', () {
    expect(normalizer.normalize('  LostParty Guild  '), 'lostparty guild');
    expect(normalizer.normalize('ABC'), 'abc');
  });

  test('분리된 한글 자모를 NFC 음절로 합성한다', () {
    const decomposed = '\u1100\u1161\u11A8'; // ᄀ + ᅡ + ᆨ
    expect(normalizer.normalize(decomposed), '각');
    expect(normalizer.normalize('\u1112\u1161\u11ab\u1100\u1173\u11af'), '한글');
  });

  test('종성 없는 음절과 종성 자모도 하나로 합성한다', () {
    expect(normalizer.normalize('가\u11A8'), '각');
  });

  test('한글 음절과 영문이 섞여도 각각의 규칙을 유지한다', () {
    expect(
      normalizer.normalize(' \u1100\u1161 Party '),
      '가 party',
    );
  });

  test('같은 정규화 규칙을 그룹명과 대표 캐릭터명에 동일하게 적용한다', () {
    expect(
      normalizer.normalize('  \u1112\u1161\u11ab\u1100\u1173\u11af  '),
      normalizer.normalize('한글'),
    );
  });

  test('미입력 그룹명은 대표 캐릭터명 기반 기본값을 만든다', () {
    expect(normalizer.defaultName(' 검증된캐릭터 '), '검증된캐릭터의 그룹');
    expect(
      normalizer.defaultName('\u1100\u1161\u11A8'),
      '각의 그룹',
    );
  });

  test('직접 입력 그룹명은 trim 후 1~20자만 허용한다', () {
    expect(normalizer.isValidDisplayName('가'), isTrue);
    expect(normalizer.isValidDisplayName('  가  '), isTrue);
    expect(normalizer.isValidDisplayName('a' * 20), isTrue);
    expect(normalizer.isValidDisplayName('a' * 21), isFalse);
    expect(normalizer.isValidDisplayName('   '), isFalse);
    expect(normalizer.isValidDisplayName(''), isFalse);
  });

  test('줄바꿈과 제어문자가 있는 그룹명을 거절한다', () {
    expect(normalizer.isValidDisplayName('앞\n뒤'), isFalse);
    expect(normalizer.isValidDisplayName('앞\r뒤'), isFalse);
    expect(normalizer.isValidDisplayName('앞\t뒤'), isFalse);
    expect(normalizer.isValidDisplayName('앞\u0000뒤'), isFalse);
  });

  test('합성 결과 길이로 20자를 판정한다', () {
    final decomposed = '\u1100\u1161\u11A8' * 20;
    expect(normalizer.isValidDisplayName(decomposed), isTrue);
    expect(normalizer.displayName(decomposed).length, 20);
  });

  test('검색 보조값은 정규화 후 빈 문자열이 될 수 있다', () {
    expect(normalizer.normalize('   '), isEmpty);
  });
}
