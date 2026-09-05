import '../entities/local_game_account.dart';
import 'character_usage_level_policy.dart';

class StartupCharacterRefreshEligibilityPolicy {
  const StartupCharacterRefreshEligibilityPolicy({
    this.usageLevelPolicy = const CharacterUsageLevelPolicy(),
  });

  final CharacterUsageLevelPolicy usageLevelPolicy;

  List<LocalAccountCharacter> eligibleCharacters(
    Iterable<LocalGameAccount> accounts,
  ) => List.unmodifiable([
    for (final account in accounts)
      if (account.hasActiveOwnership)
        for (final character in account.characters)
          if (_isEligible(character)) character,
  ]);

  bool _isEligible(LocalAccountCharacter character) {
    final serverCharacterId = character.serverCharacterId;
    return serverCharacterId != null &&
        serverCharacterId.isNotEmpty &&
        !character.isRosterMissing &&
        usageLevelPolicy.isInUsageRange(character.itemLevel);
  }
}
