import '../../../account/domain/repositories/account_repository.dart';
import '../entities/group_member_display_snapshot.dart';

/// 로컬 계정에만 있는 표시 Snapshot을 서버 Character ID로 조회한다.
class GroupLocalMemberDisplayLookup {
  const GroupLocalMemberDisplayLookup({
    required AccountRepository accountRepository,
  }) : _accountRepository = accountRepository;

  final AccountRepository _accountRepository;

  Future<Map<String, GroupMemberDisplaySnapshot>> loadByServerCharacterId() async {
    final accounts = await _accountRepository.loadAccounts();
    final byId = <String, GroupMemberDisplaySnapshot>{};
    for (final account in accounts) {
      for (final character in account.characters) {
        final serverCharacterId = character.serverCharacterId;
        if (serverCharacterId == null || serverCharacterId.isEmpty) continue;
        byId[serverCharacterId] = GroupMemberDisplaySnapshot(
          className: character.characterClassName,
          itemLevel: character.itemLevel,
          combatPower: character.combatPower,
        );
      }
    }
    return Map.unmodifiable(byId);
  }

  Future<GroupMemberDisplaySnapshot?> forServerCharacterId(
    String serverCharacterId,
  ) async {
    final trimmed = serverCharacterId.trim();
    if (trimmed.isEmpty) return null;
    return (await loadByServerCharacterId())[trimmed];
  }
}
