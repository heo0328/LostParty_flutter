import 'character_build_analysis.dart';
import 'character_profile.dart';

class CharacterBuildDraft {
  const CharacterBuildDraft({
    required this.characterId,
    required this.rawJson,
    required this.profile,
    required this.analysis,
    required this.fetchedAt,
  });

  final int characterId;
  final String rawJson;
  final CharacterProfile profile;
  final CharacterBuildAnalysis analysis;
  final DateTime fetchedAt;
}
