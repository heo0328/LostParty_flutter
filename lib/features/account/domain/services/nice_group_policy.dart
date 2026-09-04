import '../entities/local_game_account.dart';
import '../entities/nice_group_policy_result.dart';

class NiceGroupPolicy {
  const NiceGroupPolicy();

  static const minimumItemLevel = 1700.0;
  static const minimumCharacterCount = 2;

  NiceGroupPolicyResult evaluate(Iterable<LocalGameAccount> accounts) {
    final counts = <String, int>{};
    for (final account in accounts) {
      for (final character in account.characters) {
        if (character.isRosterMissing ||
            (character.itemLevel ?? -1) < minimumItemLevel) {
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
