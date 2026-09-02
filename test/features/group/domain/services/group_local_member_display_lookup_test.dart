import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/activity_characters_repository.dart';
import 'package:lost_party/features/group/domain/services/group_local_member_display_lookup.dart';

class _Build extends Fake implements CharacterBuildSnapshot {
  _Build(this.combatPower, this.capturedAt);
  @override
  final double? combatPower;
  @override
  final DateTime capturedAt;
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
  _Accounts({
    this.power,
    this.status = 'active',
    this.builds = const [],
    this.extraInactive = false,
  });
  final double? power;
  final String status;
  final List<CharacterBuildSnapshot> builds;
  final bool extraInactive;
  int buildReads = 0;
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => [
    LocalGameAccount(
      id: 1,
      label: '계정',
      isMain: true,
      lookupCharacterName: '캐릭터',
      representativeCharacterId: 1,
      displayLimit: 5,
      serverOwnershipStatus: status,
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverCharacterId: 'character-1',
          serverName: '서버',
          characterName: '캐릭터',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1700,
          combatPower: power,
          isVisible: true,
          displayOrder: 0,
        ),
        if (extraInactive)
          const LocalAccountCharacter(
            id: 2,
            serverCharacterId: 'character-2',
            serverName: '서버',
            characterName: '비활동',
            characterLevel: 70,
            characterClassName: '워로드',
            itemLevel: 1700,
            combatPower: 2200,
            isVisible: true,
            displayOrder: 1,
          ),
      ],
    ),
  ];
  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int id,
  ) async {
    buildReads++;
    return builds;
  }
}

void main() {
  test('프로필이 비어도 가장 최근 유효한 저장 세팅 전투력을 사용한다', () async {
    final repository = _Accounts(
      builds: [
        _Build(2500, DateTime(2026, 8, 29)),
        _Build(null, DateTime(2026, 8, 31)),
        _Build(2800, DateTime(2026, 8, 30)),
      ],
    );
    final value = await GroupLocalMemberDisplayLookup(
      accountRepository: repository,
    ).forServerCharacterId('character-1');
    expect(value?.combatPower, 2800);
  });
  test('프로필 숫자가 있으면 세팅을 추가 조회하지 않는다', () async {
    final repository = _Accounts(power: 3100);
    final value = await GroupLocalMemberDisplayLookup(
      accountRepository: repository,
    ).forServerCharacterId('character-1');
    expect(value?.combatPower, 3100);
    expect(repository.buildReads, 0);
  });
  test('소유권 상실 계정은 서버 표시 동기화 후보에서 제외한다', () async {
    final repository = _Accounts(power: 3100, status: 'ownershipLost');
    final values = await GroupLocalMemberDisplayLookup(
      accountRepository: repository,
    ).loadByServerCharacterId();
    expect(values, isEmpty);
  });
  test('활동 Character만 전투력 보강 후보에 담는다', () async {
    final values = await GroupLocalMemberDisplayLookup(
      accountRepository: _Accounts(power: 3100, extraInactive: true),
      activityCharactersRepository: _Activity({'character-1'}),
      playerId: 'player-1',
    ).loadByServerCharacterId();
    expect(values.keys, ['character-1']);
    expect(values['character-1']?.combatPower, 3100);
  });
}
