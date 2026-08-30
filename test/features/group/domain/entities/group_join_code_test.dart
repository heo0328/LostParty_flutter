import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/domain/entities/group_join_code.dart';

void main() {
  group('GroupJoinCode', () {
    test('정규화는 앞뒤 공백을 제거하고 대문자로 바꾼다', () {
      expect(GroupJoinCode.normalize('  abcd  '), 'ABCD');
    });

    test('혼동 문자와 짧은 입력은 파싱에 실패한다', () {
      expect(GroupJoinCode.tryParse('0O1Il23456789ABCDEF'), isNull);
      expect(GroupJoinCode.tryParse('SHORT'), isNull);
      expect(GroupJoinCode.tryParse(''), isNull);
    });

    test('유효한 20자 코드는 정규화해 파싱한다', () {
      const raw = '23456789abcdefghjkmn';
      final code = GroupJoinCode.tryParse('  $raw  ');
      expect(code, isNotNull);
      expect(code!.value, '23456789ABCDEFGHJKMN');
      expect(code.value.length, GroupJoinCode.length);
    });

    test('생성기는 고정 길이·허용 알파벳·≥96비트를 만족한다', () {
      final code = GroupJoinCode.generate(random: Random(42));
      expect(code.value.length, 20);
      expect(code.value.length * 5, greaterThanOrEqualTo(96));
      for (final char in code.value.split('')) {
        expect(GroupJoinCode.alphabet.contains(char), isTrue);
      }
      expect(GroupJoinCode.tryParse(code.value), code);
    });

    test('알파벳에 0 O 1 I l 이 없다', () {
      for (final forbidden in ['0', 'O', '1', 'I', 'l']) {
        expect(GroupJoinCode.alphabet.contains(forbidden), isFalse);
      }
    });
  });
}
