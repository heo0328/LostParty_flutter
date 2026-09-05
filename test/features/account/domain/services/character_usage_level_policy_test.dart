import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/services/character_usage_level_policy.dart';

void main() {
  const policy = CharacterUsageLevelPolicy();

  test('1700을 앱 공통 사용 레벨의 포함 경계로 사용한다', () {
    expect(CharacterUsageLevelPolicy.minimumItemLevel, 1700);
    expect(policy.isInUsageRange(1699.99), isFalse);
    expect(policy.isInUsageRange(1700), isTrue);
    expect(policy.isInUsageRange(1700.01), isTrue);
    expect(policy.isInUsageRange(null), isFalse);
  });
}
