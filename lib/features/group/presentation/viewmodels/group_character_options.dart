import '../../../account/domain/entities/local_game_account.dart';
import '../../../account/domain/repositories/account_repository.dart';

/// 그룹 생성·가입 신청에 쓸 수 있는 인증 Character. 서버 Character ID와 active
/// 소유 계정만 담는다.
class GroupCharacterOption {
  const GroupCharacterOption({
    required this.serverCharacterId,
    required this.characterName,
    required this.serverName,
    required this.className,
    required this.accountLabel,
    required this.isMainAccount,
    required this.isRepresentative,
    required this.itemLevel,
  });

  final String serverCharacterId;
  final String characterName;
  final String serverName;
  final String className;
  final String accountLabel;
  final bool isMainAccount;
  final bool isRepresentative;
  final double? itemLevel;
}

/// 그룹 생성과 가입 신청이 같은 인증 Character 목록을 사용한다.
class GroupCharacterOptionLoader {
  const GroupCharacterOptionLoader({required this.accountRepository});

  final AccountRepository accountRepository;

  Future<List<GroupCharacterOption>> load() async {
    final accounts = await accountRepository.loadAccounts();
    final options = <GroupCharacterOption>[];
    for (final account in accounts.where(
      (account) => account.hasActiveOwnership,
    )) {
      for (final character in account.characters) {
        if (!_isAuthenticated(character)) continue;
        options.add(
          GroupCharacterOption(
            serverCharacterId: character.serverCharacterId!,
            characterName: character.characterName,
            serverName: character.serverName,
            className: character.characterClassName,
            accountLabel: account.label,
            isMainAccount: account.isMain,
            isRepresentative: account.representativeCharacterId == character.id,
            itemLevel: character.itemLevel,
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
