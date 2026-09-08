import '../../../account/domain/repositories/account_repository.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../account/domain/services/activity_character_source.dart';
import '../entities/group_member_display_snapshot.dart';

/// 로컬 계정에만 있는 표시 Snapshot을 서버 Character ID로 조회한다.
/// 전투력·아이템 레벨은 선호 역할 Snapshot을 우선하고, 없으면 캐릭터 요약값과
/// 최근 저장 Snapshot을 참고한다.
class GroupLocalMemberDisplayLookup {
  const GroupLocalMemberDisplayLookup({
    required AccountRepository accountRepository,
    this.activityCharactersRepository,
    this.playerId,
  }) : _accountRepository = accountRepository;

  final AccountRepository _accountRepository;
  final ActivityCharactersRepository? activityCharactersRepository;
  final String? playerId;

  Future<Map<String, GroupMemberDisplaySnapshot>>
  loadByServerCharacterId() async {
    final accounts = await _accountRepository.loadAccounts();
    final activityCharacterIds = await loadActivityCharacterIds(
      repository: activityCharactersRepository,
      playerId: playerId,
    );
    final byId = <String, GroupMemberDisplaySnapshot>{};
    for (final account in accounts.where(
      (account) => account.hasActiveOwnership,
    )) {
      for (final character in charactersMatchingActivity(
        account,
        activityCharacterIds,
      )) {
        final serverCharacterId = character.serverCharacterId;
        if (serverCharacterId == null ||
            serverCharacterId.isEmpty ||
            character.isRosterMissing) {
          continue;
        }
        var itemLevel = character.itemLevel;
        var combatPower = character.combatPower;
        final needsBuildLookup =
            character.preferredRole != null ||
            combatPower == null ||
            itemLevel == null;
        if (needsBuildLookup) {
          final builds =
              (await _accountRepository.loadCharacterBuildSnapshots(
                    character.id,
                  ))
                  .where(
                    (build) =>
                        (build.combatPower != null &&
                            build.combatPower!.isFinite &&
                            build.combatPower! >= 0) ||
                        (build.itemLevel != null &&
                            build.itemLevel!.isFinite &&
                            build.itemLevel! >= 0),
                  )
                  .toList()
                ..sort(
                  (left, right) =>
                      right.capturedAt.compareTo(left.capturedAt),
                );
          final preferredRole = character.preferredRole;
          final preferred = preferredRole == null
              ? null
              : builds
                    .where((build) => build.role == preferredRole)
                    .firstOrNull;
          final fallback = builds.isEmpty ? null : builds.first;
          itemLevel =
              preferred?.itemLevel ?? itemLevel ?? fallback?.itemLevel;
          combatPower =
              preferred?.combatPower ??
              combatPower ??
              fallback?.combatPower;
        }
        byId[serverCharacterId] = GroupMemberDisplaySnapshot(
          className: character.characterClassName,
          itemLevel: itemLevel,
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
