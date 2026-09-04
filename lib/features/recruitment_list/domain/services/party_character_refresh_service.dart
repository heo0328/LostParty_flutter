import '../../../account/domain/entities/character_auto_refresh_result.dart';
import '../../../account/domain/entities/character_build_role.dart';
import '../../../account/domain/entities/nice_group_policy_result.dart';
import '../../../account/domain/repositories/account_repository.dart';
import '../../../account/domain/repositories/nice_group_auto_refresh_settings_repository.dart';
import '../../../account/domain/services/character_auto_refresh_coordinator.dart';
import '../../../account/domain/services/nice_group_policy.dart';
import '../entities/party_recruitment.dart';

class PartyCharacterRefreshTarget {
  const PartyCharacterRefreshTarget({
    required this.localCharacterId,
    required this.characterName,
    required this.className,
    required this.role,
    required this.generation,
  });

  final int localCharacterId;
  final String characterName;
  final String className;
  final PartyRole role;
  final int generation;
}

class PartyCharacterRefreshService {
  const PartyCharacterRefreshService({
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

  Future<void> prefetch(Iterable<PartyCharacterRefreshTarget> targets) async {
    final exclusion = await _loadExclusion();
    await Future.wait([
      for (final target in targets)
        _refresh(target, prefetch: true, exclusion: exclusion),
    ]);
  }

  Future<CharacterAutoRefreshResult> ensureFresh(
    PartyCharacterRefreshTarget target, {
    bool force = false,
  }) async => _refresh(
    target,
    prefetch: false,
    force: force,
    exclusion: await _loadExclusion(),
  );

  Future<({NiceGroupPolicyResult groups, bool overrideEnabled})>
  _loadExclusion() async {
    final groups = niceGroupPolicy.evaluate(
      await accountRepository.loadAccounts(),
    );
    final overrideEnabled = groups.isEmpty
        ? false
        : await settingsRepository.loadEnabled(playerId: playerId);
    return (groups: groups, overrideEnabled: overrideEnabled);
  }

  Future<CharacterAutoRefreshResult> _refresh(
    PartyCharacterRefreshTarget target, {
    required bool prefetch,
    bool force = false,
    required ({NiceGroupPolicyResult groups, bool overrideEnabled}) exclusion,
  }) async {
    final excluded = exclusion.groups.containsClass(target.className) &&
        !exclusion.overrideEnabled;
    final request = CharacterAutoRefreshRequest(
      characterId: target.localCharacterId,
      characterName: target.characterName,
      generation: target.generation,
      expectedRole: _buildRole(target.role),
      excludedFromAutoRefresh: excluded,
      force: force,
    );
    return prefetch
        ? coordinator.prefetch(request)
        : coordinator.ensureFresh(request);
  }

  CharacterBuildRole _buildRole(PartyRole role) => switch (role) {
    PartyRole.dealer => CharacterBuildRole.dealer,
    PartyRole.support => CharacterBuildRole.support,
  };
}
