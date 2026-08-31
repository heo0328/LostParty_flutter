import '../../../account/domain/repositories/account_repository.dart';
import '../entities/group_member_display_snapshot.dart';

/// 로컬 계정에만 있는 표시 Snapshot을 서버 Character ID로 조회한다.
class GroupLocalMemberDisplayLookup {
  const GroupLocalMemberDisplayLookup({
    required AccountRepository accountRepository,
  }) : _accountRepository = accountRepository;

  final AccountRepository _accountRepository;

  Future<Map<String, GroupMemberDisplaySnapshot>>
  loadByServerCharacterId() async {
    final accounts = await _accountRepository.loadAccounts();
    final byId = <String, GroupMemberDisplaySnapshot>{};
    for (final account in accounts.where(
      (account) => account.hasActiveOwnership,
    )) {
      for (final character in account.characters) {
        final serverCharacterId = character.serverCharacterId;
        if (serverCharacterId == null ||
            serverCharacterId.isEmpty ||
            character.isRosterMissing) {
          continue;
        }
        var combatPower = character.combatPower;
        if (combatPower == null) {
          // 역할 세팅만 저장된 기존 계정도 표시값을 복구한다. 외부 API 조회는 하지 않는다.
          final builds =
              (await _accountRepository.loadCharacterBuildSnapshots(
                    character.id,
                  ))
                  .where(
                    (build) =>
                        build.combatPower != null &&
                        build.combatPower!.isFinite &&
                        build.combatPower! >= 0,
                  )
                  .toList()
                ..sort(
                  (left, right) => right.capturedAt.compareTo(left.capturedAt),
                );
          if (builds.isNotEmpty) combatPower = builds.first.combatPower;
        }
        byId[serverCharacterId] = GroupMemberDisplaySnapshot(
          className: character.characterClassName,
          itemLevel: character.itemLevel,
          combatPower: combatPower,
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
