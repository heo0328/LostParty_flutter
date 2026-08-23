import '../../../../shared/formatters/display_number_formatter.dart';
import '../../domain/entities/party_recruitment.dart';

class CandidateBuildDisplayModel {
  const CandidateBuildDisplayModel({
    required this.role,
    required this.itemLevel,
    required this.combatPower,
    required this.minCombatPower,
  });

  final PartyRole role;
  final double? itemLevel;
  final double? combatPower;
  final int? minCombatPower;

  String get roleLabel => role == PartyRole.support ? '서포터' : '딜러';

  String get itemLevelLabel => itemLevel == null
      ? '아이템 레벨 없음'
      : '아이템 레벨 ${DisplayNumberFormatter.integer(itemLevel!)}';

  String get combatPowerLabel {
    final value = combatPower;
    if (value == null) return '전투력 없음';
    final formatted = DisplayNumberFormatter.integer(value);
    final minimum = minCombatPower;
    return minimum != null && minimum > 0 && value < minimum
        ? '전투력 $formatted · 최소 전투력 미달'
        : '전투력 $formatted';
  }

  String get label => '$roleLabel · $itemLevelLabel · $combatPowerLabel';
}
