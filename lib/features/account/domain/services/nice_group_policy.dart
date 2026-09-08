import '../entities/local_game_account.dart';
import '../entities/nice_group_policy_result.dart';
import 'character_usage_level_policy.dart';

class NiceGroupPolicy {
  const NiceGroupPolicy({
    this.usageLevelPolicy = const CharacterUsageLevelPolicy(),
  });

  final CharacterUsageLevelPolicy usageLevelPolicy;
  static const minimumCharacterCount = 2;

  NiceGroupPolicyResult evaluate(Iterable<LocalGameAccount> accounts) {
    final counts = <String, int>{};
    for (final account in accounts) {
      for (final character in account.characters) {
        if (character.isRosterMissing ||
            !usageLevelPolicy.isInUsageRange(character.itemLevel)) {
          continue;
        }
        final className = character.characterClassName.trim().toLowerCase();
        if (className.isEmpty) continue;
        counts.update(className, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return NiceGroupPolicyResult(
      classNames: Set.unmodifiable(
        counts.entries
            .where((entry) => entry.value >= minimumCharacterCount)
            .map((entry) => entry.key),
      ),
    );
  }
}
