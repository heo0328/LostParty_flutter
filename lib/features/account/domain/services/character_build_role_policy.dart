import '../entities/character_build_role.dart';
import '../entities/character_build_analysis.dart';
import '../entities/character_build_catalog_detection.dart';

class AutomaticBuildRole {
  const AutomaticBuildRole({this.role, this.message});
  final CharacterBuildRole? role;
  final String? message;
}

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

  /// Automatic analysis never falls back to the user's selected/preferred role.
  AutomaticBuildRole automaticRole(
    String className,
    CharacterBuildAnalysis analysis,
  ) {
    final fixed = fixedRole(className);
    if (fixed != null) return AutomaticBuildRole(role: fixed);
    final detection = analysis.catalogDetection;
    if (detection == null ||
        detection.status == CharacterBuildDetectionStatus.unsupportedClass) {
      return const AutomaticBuildRole(message: '현재 역할을 판별할 수 없습니다.');
    }
    if (detection.status != CharacterBuildDetectionStatus.detected ||
        detection.detectedRole == null) {
      return const AutomaticBuildRole(message: '현재 역할을 하나로 판별할 수 없습니다.');
    }
    if (detection.matchedRelatedNodes.isEmpty) {
      return const AutomaticBuildRole(message: '현재 역할의 4티어 노드를 확인할 수 없습니다.');
    }
    return AutomaticBuildRole(role: detection.detectedRole);
  }
}
