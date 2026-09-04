import '../../../account/domain/repositories/account_repository.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../domain/entities/group_create_command.dart';
import '../../domain/entities/group_create_result.dart';
import '../../domain/repositories/group_create_repository.dart';
import '../../domain/services/group_name_normalizer.dart';
import 'group_character_options.dart';
import '../../domain/services/group_character_refresh_service.dart';
import '../../../account/domain/entities/character_auto_refresh_result.dart';

export 'group_character_options.dart' show GroupCharacterOption;

class GroupCreateViewModel {
  const GroupCreateViewModel({
    required this.accountRepository,
    required this.createRepository,
    this.activityCharactersRepository,
    this.playerId,
    this.characterRefreshService,
    this.normalizer = const GroupNameNormalizer(),
  });

  final AccountRepository accountRepository;
  final GroupCreateRepository createRepository;
  final ActivityCharactersRepository? activityCharactersRepository;
  final String? playerId;
  final GroupCharacterRefreshService? characterRefreshService;
  final GroupNameNormalizer normalizer;

  Future<List<GroupCharacterOption>> loadAuthenticatedCharacters() =>
      GroupCharacterOptionLoader(
        accountRepository: accountRepository,
        activityCharactersRepository: activityCharactersRepository,
        playerId: playerId,
        characterRefreshService: characterRefreshService,
      ).load();

  Future<CharacterAutoRefreshResult?> ensureFresh(
    GroupCharacterOption character, {
    required int generation,
  }) async => characterRefreshService?.ensureFresh(
    GroupCharacterRefreshTarget(
      localCharacterId: character.localCharacterId,
      characterName: character.characterName,
      className: character.className,
      role: character.preferredRole,
      generation: generation,
    ),
  ) ?? Future.value(null);

  String defaultNameFor(GroupCharacterOption option) =>
      normalizer.defaultName(option.characterName);

  bool isValidName(String value) =>
      value.trim().isEmpty || normalizer.isValidDisplayName(value);

  Future<GroupCreateResult> create({
    required GroupCharacterOption character,
    required String name,
  }) => createRepository.create(
    GroupCreateCommand(
      representativeCharacterId: character.serverCharacterId,
      representativeCharacterName: character.characterName,
      representativeServerName: character.serverName,
      name: name.trim().isEmpty ? null : name,
    ),
  );
}

String groupCreateFailureMessage(GroupCreateFailure failure) =>
    switch (failure) {
      GroupCreateFailure.unauthenticated ||
      GroupCreateFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
      GroupCreateFailure.invalidCharacter =>
        '그룹을 만들 수 없는 캐릭터입니다. 내 계정에서 정보를 새로고침한 뒤 다시 시도해 주세요.',
      GroupCreateFailure.ownershipLost => '캐릭터 소유권을 확인하지 못했습니다.',
      GroupCreateFailure.activeGroupLimitReached =>
        '가입한 그룹이 50개입니다. 더 만들 수 없습니다.',
      GroupCreateFailure.invalidRequest => '그룹 이름을 확인해 주세요.',
      GroupCreateFailure.permissionDenied => '그룹 생성 권한을 확인하지 못했습니다.',
      GroupCreateFailure.temporarilyUnavailable =>
        '일시적으로 처리할 수 없습니다. 새로고침한 뒤 다시 시도해 주세요.',
      GroupCreateFailure.unknown => '그룹을 만들지 못했습니다.',
    };
