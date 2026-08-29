import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/manual_verification/domain/manual_verification_code.dart';

void main() {
  test('LP- 접두어와 혼동 문자를 제외한 6자리를 만든다', () {
    final code = ManualVerificationCode.generate();
    expect(code, startsWith('LP-'));
    expect(ManualVerificationCode.isValid(code), isTrue);
    expect(code.substring(3).contains(RegExp(r'[0O1IL]')), isFalse);
  });

  test('대소문자를 가리지 않고 정규화한다', () {
    expect(ManualVerificationCode.normalize(' lp-7k4m2q '), 'LP-7K4M2Q');
    expect(ManualVerificationCode.isValid('lp-7K4M2Q'), isTrue);
    expect(ManualVerificationCode.isValid('LP-0ABCDE'), isFalse);
  });
}
