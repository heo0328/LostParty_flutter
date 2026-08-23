import '../../../../shared/formatters/display_number_formatter.dart';
import '../entities/party_recruitment.dart';

class RecruitmentAutoTitlePolicy {
  const RecruitmentAutoTitlePolicy();

  String build({
    required String difficultyAlias,
    required ExperienceLevel? experienceLevel,
    required num? minCombatPower,
  }) {
    final combatPower = minCombatPower?.toInt() ?? 0;
    return [
      difficultyAlias.trim(),
      if (experienceLevel != null) _experienceLabel(experienceLevel),
      if (combatPower > 0) DisplayNumberFormatter.integer(combatPower),
      '모집',
    ].where((part) => part.isNotEmpty).join(' ');
  }

  String _experienceLabel(ExperienceLevel value) => switch (value) {
    ExperienceLevel.tryLevel => '트라이',
    ExperienceLevel.clearExp => '클경',
    ExperienceLevel.multiClearExp => '다클경',
    ExperienceLevel.semiExperienced => '반숙',
    ExperienceLevel.experienced => '숙련',
  };
}
