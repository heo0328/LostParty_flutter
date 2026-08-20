import '../../../../shared/game_catalog/domain/entities/game_catalog.dart';
import 'character_build_role.dart';

enum CharacterBuildDetectionStatus {
  detected,
  unsupportedClass,
  branchNotFound,
  ambiguous,
}

class CharacterBuildCatalogDetection {
  const CharacterBuildCatalogDetection({
    required this.catalogVersion,
    required this.status,
    required this.classId,
    required this.branchId,
    required this.branchDisplayName,
    required this.detectedRole,
    required this.matchedTier1Node,
    required this.matchedRelatedNodes,
  });

  final String catalogVersion;
  final CharacterBuildDetectionStatus status;
  final String? classId;
  final String? branchId;
  final String? branchDisplayName;
  final CharacterBuildRole? detectedRole;
  final String? matchedTier1Node;
  final List<String> matchedRelatedNodes;
}

CharacterBuildRole characterBuildRoleFromCatalogRole(GameCatalogRole role) {
  return switch (role) {
    GameCatalogRole.dealer => CharacterBuildRole.dealer,
    GameCatalogRole.support => CharacterBuildRole.support,
  };
}
