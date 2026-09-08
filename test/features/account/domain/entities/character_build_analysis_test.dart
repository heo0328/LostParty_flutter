import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';

void main() {
  test(
    'gem summary counts every validation result and prioritizes foreign',
    () {
      final analysis = CharacterBuildAnalysis(
        runeCount: 8,
        gemEffects: [
          _effect(0, GemValidationStatus.verified),
          _effect(1, GemValidationStatus.sameClassTargetUnverified),
          _effect(2, GemValidationStatus.foreignClass),
          _effect(3, GemValidationStatus.unavailable),
        ],
        arkGridConditions: const [],
        arkGridCorePoints: const [],
        notices: const [],
      );

      final summary = analysis.gemValidationSummary;

      expect(summary.totalCount, 4);
      expect(summary.verifiedCount, 1);
      expect(summary.unverifiedSameClassCount, 1);
      expect(summary.foreignClassCount, 1);
      expect(summary.unavailableCount, 1);
      expect(summary.status, GemValidationSummaryStatus.foreignClass);
    },
  );

  test('gem summary separates unverified, unavailable and verified states', () {
    expect(
      _analysis([
        GemValidationStatus.sameClassTargetUnverified,
      ]).gemValidationSummary.status,
      GemValidationSummaryStatus.sameClassTargetUnverified,
    );
    expect(
      _analysis([GemValidationStatus.unavailable]).gemValidationSummary.status,
      GemValidationSummaryStatus.unavailable,
    );
    expect(
      _analysis([GemValidationStatus.verified]).gemValidationSummary.status,
      GemValidationSummaryStatus.verified,
    );
    expect(
      _analysis(const []).gemValidationSummary.status,
      GemValidationSummaryStatus.unavailable,
    );
  });
}

CharacterBuildAnalysis _analysis(List<GemValidationStatus> statuses) =>
    CharacterBuildAnalysis(
      runeCount: 8,
      gemEffects: [
        for (var index = 0; index < statuses.length; index++)
          _effect(index, statuses[index]),
      ],
      arkGridConditions: const [],
      arkGridCorePoints: const [],
      notices: const [],
    );

GemSkillEffect _effect(int slot, GemValidationStatus status) => GemSkillEffect(
  gemSlot: slot,
  gemLevel: 10,
  skillName: '테스트',
  descriptions: const [],
  category: GemSkillCategory.normal,
  validationStatus: status,
);
