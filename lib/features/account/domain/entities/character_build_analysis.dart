enum BuildNoticeLevel { info, warning }

enum GemSkillCategory { normal, passiveOrIdentity, unknown }

class BuildNotice {
  const BuildNotice({
    required this.code,
    required this.level,
    required this.message,
  });

  final String code;
  final BuildNoticeLevel level;
  final String message;
}

class GemSkillEffect {
  const GemSkillEffect({
    required this.gemSlot,
    required this.gemLevel,
    required this.skillName,
    required this.descriptions,
    required this.category,
  });

  final int gemSlot;
  final int gemLevel;
  final String skillName;
  final List<String> descriptions;
  final GemSkillCategory category;
}

class ArkGridConditionCheck {
  const ArkGridConditionCheck({
    required this.coreName,
    required this.conditionText,
    required this.requiredPassiveNames,
    required this.missingPassiveNames,
  });

  final String coreName;
  final String conditionText;
  final List<String> requiredPassiveNames;
  final List<String> missingPassiveNames;

  bool get isSatisfied => missingPassiveNames.isEmpty;
}

class ArkGridCorePointCheck {
  const ArkGridCorePointCheck({
    required this.coreName,
    required this.grade,
    required this.point,
    required this.minimumPoint,
    required this.recommendedPoint,
  });

  final String coreName;
  final String grade;
  final int point;
  final int minimumPoint;
  final int recommendedPoint;

  bool get meetsMinimum => point >= minimumPoint;
  bool get meetsRecommendation => point >= recommendedPoint;
}

class CharacterBuildAnalysis {
  const CharacterBuildAnalysis({
    required this.runeCount,
    required this.gemEffects,
    required this.arkGridConditions,
    required this.arkGridCorePoints,
    required this.notices,
  });

  static const expectedRuneCount = 8;

  final int runeCount;
  final List<GemSkillEffect> gemEffects;
  final List<ArkGridConditionCheck> arkGridConditions;
  final List<ArkGridCorePointCheck> arkGridCorePoints;
  final List<BuildNotice> notices;
}
