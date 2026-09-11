import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

import '../entities/character_build_analysis.dart';
import '../entities/character_build_role.dart';
import '../entities/character_build_snapshot.dart';

/// 로컬 Build Snapshot에서 Character 최소 표시용 통합 무결성 요약을 만든다.
///
/// 예외를 밖으로 던지지 않는다. 판정 불능이면 null이 아니라
/// [BuildIntegrityStatus.unavailable] 스냅샷을 반환한다.
BuildIntegritySnapshot? buildIntegritySnapshotFromBuild(
  CharacterBuildSnapshot snapshot,
) {
  try {
    return buildIntegritySnapshotFromAnalysis(
      analysis: snapshot.analysis,
      role: snapshot.role,
      checkedAt: snapshot.capturedAt,
    );
  } catch (_) {
    return null;
  }
}

BuildIntegritySnapshot? buildIntegritySnapshotFromAnalysis({
  required CharacterBuildAnalysis analysis,
  required CharacterBuildRole role,
  required DateTime checkedAt,
}) {
  try {
    final issueCodes = _collectIssueCodes(analysis);
    final status = _resolveStatus(
      issueCodes: issueCodes,
      canVerifyArkGridMinimum: analysis.arkGridMinimumIntegrity != null,
    );
    final catalogVersion = analysis.catalogDetection?.catalogVersion.trim();
    return BuildIntegritySnapshot(
      status: status,
      issueCodes: issueCodes,
      role: switch (role) {
        CharacterBuildRole.dealer => BuildIntegrityRole.dealer,
        CharacterBuildRole.support => BuildIntegrityRole.support,
      },
      checkedAt: checkedAt.toUtc(),
      catalogVersion: (catalogVersion == null || catalogVersion.isEmpty)
          ? null
          : catalogVersion,
    );
  } catch (_) {
    return null;
  }
}

List<BuildIntegrityIssueCode> _collectIssueCodes(
  CharacterBuildAnalysis analysis,
) {
  final codes = <BuildIntegrityIssueCode>[];
  final gem = analysis.gemValidationSummary;

  final equippedGemCount = analysis.equippedGemCount;
  if (equippedGemCount != null && equippedGemCount < 11) {
    codes.add(BuildIntegrityIssueCode.gemSlotCount);
  }
  if (gem.foreignClassCount > 0) {
    codes.add(BuildIntegrityIssueCode.foreignClassGem);
  }
  if (gem.unverifiedSameClassCount > 0) {
    codes.add(BuildIntegrityIssueCode.unmatchedSkillGem);
  }
  if (equippedGemCount == null ||
      !analysis.gemEffectsSourceAvailable ||
      gem.unavailableCount > 0) {
    codes.add(BuildIntegrityIssueCode.gemUnavailable);
  }

  final minimum = analysis.arkGridMinimumIntegrity;
  if (minimum != null && !minimum.isSatisfied) {
    codes.add(BuildIntegrityIssueCode.arkGridMinimum);
  }

  final hasUnsatisfiedCondition = analysis.arkGridConditions.any(
    (condition) => !condition.isSatisfied,
  );
  if (hasUnsatisfiedCondition) {
    codes.add(BuildIntegrityIssueCode.arkGridCondition);
  }

  return List<BuildIntegrityIssueCode>.unmodifiable(codes);
}

BuildIntegrityStatus _resolveStatus({
  required List<BuildIntegrityIssueCode> issueCodes,
  required bool canVerifyArkGridMinimum,
}) {
  const errorCodes = <BuildIntegrityIssueCode>{
    BuildIntegrityIssueCode.gemSlotCount,
    BuildIntegrityIssueCode.foreignClassGem,
    BuildIntegrityIssueCode.unmatchedSkillGem,
    BuildIntegrityIssueCode.arkGridMinimum,
    BuildIntegrityIssueCode.arkGridCondition,
  };
  const reviewCodes = <BuildIntegrityIssueCode>{
    BuildIntegrityIssueCode.sameClassGemUnverified,
    BuildIntegrityIssueCode.gemUnavailable,
  };

  if (issueCodes.any(errorCodes.contains)) {
    return BuildIntegrityStatus.error;
  }
  if (issueCodes.any(reviewCodes.contains)) {
    return BuildIntegrityStatus.review;
  }
  if (canVerifyArkGridMinimum) {
    return BuildIntegrityStatus.clean;
  }
  return BuildIntegrityStatus.unavailable;
}
