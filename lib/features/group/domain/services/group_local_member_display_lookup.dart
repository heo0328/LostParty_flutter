import '../../../account/domain/repositories/account_repository.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../account/domain/services/activity_character_source.dart';
import '../../../account/domain/services/gem_validation_snapshot_mapper.dart';
import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';
import '../entities/group_member_display_snapshot.dart';

/// 로컬 계정에만 있는 표시 Snapshot을 서버 Character ID로 조회한다.
/// 전투력·아이템 레벨·보석 요약은 선호 역할 Snapshot을 우선하고, 없으면 캐릭터
/// 요약값과 최근 저장 Snapshot을 참고한다.
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
        PartyGemValidationSnapshot? gemValidation;
        final needsBuildLookup =
            character.preferredRole != null ||
            combatPower == null ||
            itemLevel == null;
        if (needsBuildLookup) {
          final builds =
              (await _accountRepository.loadCharacterBuildSnapshots(
                    character.id,
                  )).toList()
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
          final numericBuilds = builds
              .where(
                (build) =>
                    (build.combatPower != null &&
                        build.combatPower!.isFinite &&
                        build.combatPower! >= 0) ||
                    (build.itemLevel != null &&
                        build.itemLevel!.isFinite &&
                        build.itemLevel! >= 0),
              )
              .toList();
          final fallback = numericBuilds.isEmpty ? null : numericBuilds.first;
          final selected = preferred ?? fallback;
          itemLevel =
              preferred?.itemLevel ?? itemLevel ?? fallback?.itemLevel;
          combatPower =
              preferred?.combatPower ??
              combatPower ??
              fallback?.combatPower;
          gemValidation = selected == null
              ? null
              : gemValidationSnapshotFromBuild(selected);
        }
        byId[serverCharacterId] = GroupMemberDisplaySnapshot(
          className: character.characterClassName,
          itemLevel: itemLevel,
          combatPower: combatPower,
          gemValidation: gemValidation,
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
