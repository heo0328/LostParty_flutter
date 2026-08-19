import 'character_build_analysis.dart';

enum CharacterBuildRole { dealer, support }

class CharacterBuildSnapshot {
  const CharacterBuildSnapshot({
    required this.id,
    required this.characterId,
    required this.role,
    required this.rawJson,
    required this.itemLevel,
    required this.combatPower,
    required this.capturedAt,
    required this.dataVersion,
    required this.analysis,
  });

  final int id;
  final int characterId;
  final CharacterBuildRole role;
  final String rawJson;
  final double? itemLevel;
  final double? combatPower;
  final DateTime capturedAt;
  final int dataVersion;
  final CharacterBuildAnalysis analysis;
}
