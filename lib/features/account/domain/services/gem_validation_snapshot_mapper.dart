import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

import '../entities/character_build_analysis.dart';
import '../entities/character_build_snapshot.dart';

/// 로컬 Build Snapshot에서 파티·그룹용 최소 보석 요약을 만든다.
PartyGemValidationSnapshot? gemValidationSnapshotFromBuild(
  CharacterBuildSnapshot snapshot,
) {
  final catalogVersion = snapshot.analysis.catalogDetection?.catalogVersion;
  if (catalogVersion == null || catalogVersion.trim().isEmpty) return null;
  final summary = snapshot.analysis.gemValidationSummary;
  return PartyGemValidationSnapshot(
    status: switch (summary.status) {
      GemValidationSummaryStatus.verified => PartyGemValidationStatus.verified,
      GemValidationSummaryStatus.sameClassTargetUnverified =>
        PartyGemValidationStatus.sameClassTargetUnverified,
      GemValidationSummaryStatus.foreignClass =>
        PartyGemValidationStatus.foreignClass,
      GemValidationSummaryStatus.unavailable =>
        PartyGemValidationStatus.unavailable,
    },
    foreignClassGemCount: summary.foreignClassCount,
    unverifiedSameClassGemCount: summary.unverifiedSameClassCount,
    validatedAt: snapshot.capturedAt,
    catalogVersion: catalogVersion,
  );
}
