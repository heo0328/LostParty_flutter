import '../repositories/character_summary_sync_gateway.dart';

class RosterSummaryApplyResult {
  const RosterSummaryApplyResult({
    required this.updatedLocalCount,
    required this.serverPatches,
  });

  final int updatedLocalCount;
  final List<CharacterSummaryServerPatch> serverPatches;
}
