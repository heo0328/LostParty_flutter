import '../../../account/domain/entities/character_auto_refresh_result.dart';
import '../../../account/domain/entities/character_build_role.dart';
import '../../../account/domain/entities/nice_group_policy_result.dart';
import '../../../account/domain/repositories/account_repository.dart';
import '../../../account/domain/repositories/nice_group_auto_refresh_settings_repository.dart';
import '../../../account/domain/services/character_auto_refresh_coordinator.dart';
import '../../../account/domain/services/nice_group_policy.dart';

class GroupCharacterRefreshTarget {
  const GroupCharacterRefreshTarget({
    required this.localCharacterId,
    required this.characterName,
    required this.className,
    required this.role,
    required this.generation,
  });

  final int localCharacterId;
  final String characterName;
  final String className;
  final CharacterBuildRole role;
  final int generation;
}

class GroupCharacterRefreshService {
  const GroupCharacterRefreshService({
    required this.coordinator,
    required this.accountRepository,
    required this.settingsRepository,
    required this.playerId,
    this.niceGroupPolicy = const NiceGroupPolicy(),
  });

  final CharacterAutoRefreshCoordinator coordinator;
  final AccountRepository accountRepository;
  final NiceGroupAutoRefreshSettingsRepository settingsRepository;
  final String playerId;
  final NiceGroupPolicy niceGroupPolicy;

  Future<void> prefetch(Iterable<GroupCharacterRefreshTarget> targets) async {
    final exclusion = await _loadExclusion();
    await Future.wait([
      for (final target in targets)
        coordinator.prefetch(_request(target, exclusion)),
    ]);
  }

  Future<CharacterAutoRefreshResult> ensureFresh(
    GroupCharacterRefreshTarget target,
  ) async => coordinator.ensureFresh(
    _request(target, await _loadExclusion()),
  );

  Future<({NiceGroupPolicyResult groups, bool overrideEnabled})>
  _loadExclusion() async {
    final groups = niceGroupPolicy.evaluate(await accountRepository.loadAccounts());
    final overrideEnabled = groups.isEmpty
        ? false
        : await settingsRepository.loadEnabled(playerId: playerId);
    return (groups: groups, overrideEnabled: overrideEnabled);
  }

  CharacterAutoRefreshRequest _request(
    GroupCharacterRefreshTarget target,
    ({NiceGroupPolicyResult groups, bool overrideEnabled}) exclusion,
  ) => CharacterAutoRefreshRequest(
    characterId: target.localCharacterId,
    characterName: target.characterName,
    generation: target.generation,
    expectedRole: target.role,
    excludedFromAutoRefresh:
        exclusion.groups.containsClass(target.className) &&
        !exclusion.overrideEnabled,
  );
}
