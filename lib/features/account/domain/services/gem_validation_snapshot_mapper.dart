import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

import '../entities/character_build_snapshot.dart';

/// 로컬 Build Snapshot에서 파티·그룹용 최소 보석 요약을 만든다.
PartyGemValidationSnapshot? gemValidationSnapshotFromBuild(
  CharacterBuildSnapshot snapshot,
) {
  final catalogVersion = snapshot.analysis.catalogDetection?.catalogVersion;
  if (catalogVersion == null || catalogVersion.trim().isEmpty) return null;
  final summary = snapshot.analysis.gemValidationSummary;
  final hasError =
      summary.hasGemSlotCountError ||
      summary.foreignClassCount > 0 ||
      summary.hasUnmatchedSkillError;
  return PartyGemValidationSnapshot(
    status: hasError
        ? PartyGemValidationStatus.error
        : (!summary.sourceAvailable || summary.unavailableCount > 0)
        ? PartyGemValidationStatus.unavailable
        : PartyGemValidationStatus.verified,
    foreignClassGemCount: summary.foreignClassCount,
    unverifiedSameClassGemCount: 0,
    validatedAt: snapshot.capturedAt,
    catalogVersion: catalogVersion,
    schemaVersion: 2,
    equippedGemCount: summary.equippedGemCount,
    unmatchedSkillGemCount: summary.unverifiedSameClassCount,
  );
}
