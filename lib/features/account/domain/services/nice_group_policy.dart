import '../entities/local_game_account.dart';
import '../entities/nice_group_policy_result.dart';
import 'character_usage_level_policy.dart';

class NiceGroupCandidate {
  const NiceGroupCandidate(
    this.className,
    this.itemLevel, {
    this.missing = false,
  });
  final String className;
  final double? itemLevel;
  final bool missing;
}

class NiceGroupPolicy {
  const NiceGroupPolicy({
    this.usageLevelPolicy = const CharacterUsageLevelPolicy(),
  });

  final CharacterUsageLevelPolicy usageLevelPolicy;
  static const minimumCharacterCount = 2;

  NiceGroupPolicyResult evaluate(Iterable<LocalGameAccount> accounts) {
    return evaluateCandidates(
      accounts.expand(
        (account) => account.characters.map(
          (c) => NiceGroupCandidate(
            c.characterClassName,
            c.itemLevel,
            missing: c.isRosterMissing,
          ),
        ),
      ),
    );
  }

  NiceGroupPolicyResult evaluateCandidates(
    Iterable<NiceGroupCandidate> candidates,
  ) {
    final counts = <String, int>{};
    for (final character in candidates) {
      if (character.missing ||
          !usageLevelPolicy.isInUsageRange(character.itemLevel)) {
        continue;
      }
      final className = character.className.trim().toLowerCase();
      if (className.isEmpty) continue;
      counts.update(className, (count) => count + 1, ifAbsent: () => 1);
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
