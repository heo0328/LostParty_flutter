import 'character_build_snapshot.dart';

enum CharacterAutoRefreshStatus {
  refreshed,
  cached,
  excluded,
  needsConfirmation,
  blocked,
}

class CharacterAutoRefreshResult {
  const CharacterAutoRefreshResult({
    required this.status,
    required this.characterId,
    required this.generation,
    required this.snapshot,
    required this.detectedRole,
    required this.expectedRoleChanged,
    required this.message,
  });

  final CharacterAutoRefreshStatus status;
  final int characterId;
  final int generation;
  final CharacterBuildSnapshot? snapshot;
  final CharacterBuildRole? detectedRole;
  final bool expectedRoleChanged;
  final String? message;

  bool get canProceed =>
      status == CharacterAutoRefreshStatus.refreshed ||
      status == CharacterAutoRefreshStatus.cached ||
      status == CharacterAutoRefreshStatus.excluded;

  bool get requiresConfirmation =>
      status == CharacterAutoRefreshStatus.needsConfirmation;

  DateTime? get lastSuccessfulAt => snapshot?.capturedAt;

  bool matchesSelection({
    required int selectedCharacterId,
    required int currentGeneration,
  }) => characterId == selectedCharacterId && generation == currentGeneration;

  CharacterAutoRefreshResult forRequest({
    required int generation,
    required CharacterBuildRole? expectedRole,
  }) {
    return CharacterAutoRefreshResult(
      status: status,
      characterId: characterId,
      generation: generation,
      snapshot: snapshot,
      detectedRole: detectedRole,
      expectedRoleChanged:
          expectedRole != null &&
          detectedRole != null &&
          expectedRole != detectedRole,
      message: message,
    );
  }
}
