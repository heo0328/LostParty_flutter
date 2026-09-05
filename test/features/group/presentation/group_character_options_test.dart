import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/activity_characters_repository.dart';
import 'package:lost_party/features/group/presentation/viewmodels/group_character_options.dart';

void main() {
  test('그룹 생성·가입 후보는 활동 Character만 담는다', () async {
    final options = await GroupCharacterOptionLoader(
      accountRepository: _Accounts(),
      activityCharactersRepository: _Activity({'character-1'}),
      playerId: 'player-1',
    ).load();

    expect(options.map((option) => option.serverCharacterId), ['character-1']);
    expect(
      options.any((option) => option.serverCharacterId == 'character-2'),
      isFalse,
    );
  });

  test('활동 저장이 없으면 인증 Character 전체를 후보로 둔다', () async {
    final options = await GroupCharacterOptionLoader(
      accountRepository: _Accounts(),
    ).load();

    expect(options.map((option) => option.serverCharacterId), [
      'character-1',
      'character-2',
    ]);
  });

  test('활동 문서가 비어 있으면 인증 Character fallback을 사용한다', () async {
    final options = await GroupCharacterOptionLoader(
      accountRepository: _Accounts(),
      activityCharactersRepository: _Activity({}),
      playerId: 'player-1',
    ).load();

    expect(options.map((option) => option.serverCharacterId), [
      'character-1',
      'character-2',
    ]);
  });
}

class _Activity implements ActivityCharactersRepository {
  _Activity(this.characterIds);
  final Set<String> characterIds;

  @override
  Future<ActivityCharacters> load({required String playerId}) async {
    return ActivityCharacters(playerId: playerId, characterIds: characterIds);
  }

  @override
  Future<ActivityCharacters> save(SaveActivityCharactersCommand command) {
    throw UnimplementedError();
  }
}

class _Accounts extends Fake implements AccountRepository {
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => const [
    LocalGameAccount(
      id: 1,
      label: '계정',
      isMain: true,
      lookupCharacterName: '대표',
      representativeCharacterId: 1,
      displayLimit: 1,
      serverOwnershipStatus: 'active',
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverCharacterId: 'character-1',
          serverName: '루페온',
          characterName: '대표',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1750,
          combatPower: 3100,
          isVisible: true,
          displayOrder: 0,
        ),
        LocalAccountCharacter(
          id: 2,
          serverCharacterId: 'character-2',
          serverName: '루페온',
          characterName: '비활동',
          characterLevel: 70,
          characterClassName: '워로드',
          itemLevel: 1800,
          combatPower: 2200,
          isVisible: true,
          displayOrder: 1,
        ),
      ],
    ),
  ];
}
