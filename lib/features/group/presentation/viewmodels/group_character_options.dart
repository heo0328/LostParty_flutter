import '../../../account/domain/entities/local_game_account.dart';
import '../../../account/domain/repositories/account_repository.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../account/domain/services/activity_character_source.dart';
import '../../../account/domain/entities/character_build_role.dart';
import '../../domain/services/group_character_refresh_service.dart';

/// 그룹 생성·가입 신청에 쓸 수 있는 인증 Character. 서버 Character ID와 active
/// 소유 계정만 담는다.
class GroupCharacterOption {
  const GroupCharacterOption({
    required this.serverCharacterId,
    this.localCharacterId = -1,
    required this.characterName,
    required this.serverName,
    required this.className,
    required this.accountLabel,
    required this.isMainAccount,
    required this.isRepresentative,
    required this.itemLevel,
    this.combatPower,
    this.preferredRole = CharacterBuildRole.dealer,
  });

  final String serverCharacterId;
  final int localCharacterId;
  final String characterName;
  final String serverName;
  final String className;
  final String accountLabel;
  final bool isMainAccount;
  final bool isRepresentative;
  final double? itemLevel;
  final double? combatPower;
  final CharacterBuildRole preferredRole;
}

/// 그룹 생성과 가입 신청이 같은 인증 Character 목록을 사용한다.
class GroupCharacterOptionLoader {
  const GroupCharacterOptionLoader({
    required this.accountRepository,
    this.activityCharactersRepository,
    this.playerId,
    this.characterRefreshService,
  });

  final AccountRepository accountRepository;
  final ActivityCharactersRepository? activityCharactersRepository;
  final String? playerId;
  final GroupCharacterRefreshService? characterRefreshService;

  Future<List<GroupCharacterOption>> load() async {
    final accounts = await accountRepository.loadAccounts();
    final activityCharacterIds = await loadActivityCharacterIds(
      repository: activityCharactersRepository,
      playerId: playerId,
    );
    await characterRefreshService?.prefetch([
      for (final account in accounts.where((account) => account.hasActiveOwnership))
        for (final character in charactersMatchingActivity(account, activityCharacterIds))
          if (_isAuthenticated(character))
            GroupCharacterRefreshTarget(
              localCharacterId: character.id,
              characterName: character.characterName,
              className: character.characterClassName,
              role: character.preferredRole ?? CharacterBuildRole.dealer,
              generation: 0,
            ),
    ]);
    final refreshedAccounts = characterRefreshService == null
        ? accounts
        : await accountRepository.loadAccounts();
    final options = <GroupCharacterOption>[];
    for (final account in refreshedAccounts.where(
      (account) => account.hasActiveOwnership,
    )) {
      for (final character in charactersMatchingActivity(
        account,
        activityCharacterIds,
      )) {
        if (!_isAuthenticated(character)) continue;
        options.add(
          GroupCharacterOption(
            serverCharacterId: character.serverCharacterId!,
            localCharacterId: character.id,
            characterName: character.characterName,
            serverName: character.serverName,
            className: character.characterClassName,
            accountLabel: account.label,
            isMainAccount: account.isMain,
            isRepresentative: account.representativeCharacterId == character.id,
            itemLevel: character.itemLevel,
            combatPower: character.combatPower,
            preferredRole: character.preferredRole ?? CharacterBuildRole.dealer,
          ),
        );
      }
    }
    options.sort((left, right) {
      if (left.isRepresentative != right.isRepresentative) {
        return left.isRepresentative ? -1 : 1;
      }
      if (left.isMainAccount != right.isMainAccount) {
        return left.isMainAccount ? -1 : 1;
      }
      final byItemLevel = (right.itemLevel ?? -1).compareTo(
        left.itemLevel ?? -1,
      );
      return byItemLevel != 0
          ? byItemLevel
          : left.characterName.compareTo(right.characterName);
    });
    return options;
  }

  bool _isAuthenticated(LocalAccountCharacter character) {
    final serverCharacterId = character.serverCharacterId;
    return serverCharacterId != null &&
        serverCharacterId.isNotEmpty &&
        !character.isRosterMissing;
  }
}
