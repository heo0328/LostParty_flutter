import '../entities/character_build_role.dart';

class CharacterBuildRolePolicy {
  const CharacterBuildRolePolicy();

  static const Set<String> multipleRoleClassNames = {
    '바드',
    '발키리',
    '도화가',
    '홀리나이트',
  };

  bool supportsMultipleRoles(String characterClassName) =>
      multipleRoleClassNames.contains(characterClassName.trim());

  CharacterBuildRole? fixedRole(String characterClassName) =>
      supportsMultipleRoles(characterClassName)
      ? null
      : CharacterBuildRole.dealer;
}
