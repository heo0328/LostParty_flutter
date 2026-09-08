import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/domain/services/character_build_role_policy.dart';

void main() {
  const policy = CharacterBuildRolePolicy();

  test('support-capable classes require build role detection', () {
    for (final className in ['바드', '홀리나이트', '도화가', '발키리']) {
      expect(policy.supportsMultipleRoles(className), isTrue);
      expect(policy.fixedRole(className), isNull);
    }
  });

  test('all other classes have a fixed dealer role', () {
    for (final className in ['블레이드', '소서리스', '브레이커', '기상술사']) {
      expect(policy.supportsMultipleRoles(className), isFalse);
      expect(policy.fixedRole(className), CharacterBuildRole.dealer);
    }
  });
}
