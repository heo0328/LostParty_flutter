import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/activity_characters_repository.dart';
import 'package:lost_party/features/account/domain/repositories/character_combat_power_sync_gateway.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/entities/group_member_display.dart';
import 'package:lost_party/features/group/domain/entities/group_member_display_snapshot_refresh_command.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_request_character.dart';
import 'package:lost_party/features/group/domain/entities/group_summary.dart';
import 'package:lost_party/features/group/domain/repositories/group_character_search_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_join_command_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_read_repository.dart';
import 'package:lost_party/features/group/domain/services/group_member_display_builder.dart';
import 'package:lost_party/features/group/presentation/pages/group_detail_page.dart';
import 'package:lost_party/features/group/presentation/viewmodels/group_join_view_model.dart';
import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

final _now = DateTime(2026, 8, 31);
GroupMember _member({
  double? power,
  GroupJoinedBy joinedBy = GroupJoinedBy.created,
}) => GroupMember(
  groupId: 'group-1',
  playerId: 'player-1',
  role: GroupMemberRole.leader,
  joinedAt: _now,
  joinSequence: 1,
  joinedBy: joinedBy,
  displayCharacterIdSnapshot: 'character-1',
  displayCharacterNameSnapshot: '대표캐릭터',
  displayClassNameSnapshot: '바드',
  itemLevelSnapshot: 1700,
  combatPowerSnapshot: power,
  revision: 1,
);

class _Accounts extends Fake implements AccountRepository {
  _Accounts({this.power = 3100});
  final double? power;
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => [
    LocalGameAccount(
      id: 1,
      label: '계정',
      isMain: true,
      lookupCharacterName: '대표캐릭터',
      representativeCharacterId: 1,
      displayLimit: 5,
      serverOwnershipStatus: 'active',
      characters: [
        for (var id = 1; id <= 2; id++)
          LocalAccountCharacter(
            id: id,
            serverCharacterId: 'character-$id',
            serverName: '서버',
            characterName: id == 1 ? '대표캐릭터' : '부캐릭터',
            characterLevel: 70,
            characterClassName: '바드',
            itemLevel: 1700,
            combatPower: id == 1 ? power : 2200,
            isVisible: true,
            displayOrder: id,
          ),
      ],
    ),
  ];
  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int id,
  ) async => [];
}

class _Reads extends Fake implements GroupReadRepository {
  GroupMember member = _member();
  @override
  Future<GroupMember?> loadGroupMember({
    required String groupId,
    required String playerId,
  }) async => member;
  @override
  Future<List<GroupMemberDisplay>> loadGroupMemberDisplays(
    String groupId,
  ) async => [GroupMemberDisplayBuilder.fromMember(member: member)];
  @override
  Future<GroupRelation?> loadMyRelation({
    required String playerId,
    required String groupId,
  }) async => GroupRelation(
    groupId: groupId,
    playerId: playerId,
    relation: GroupRelationKind.member,
    groupNameSnapshot: '그룹',
    displayCharacterNameSnapshot: '대표캐릭터',
    sourceRevision: 1,
    createdAt: _now,
    updatedAt: _now,
  );
  @override
  Future<GroupPublicSummary?> loadGroup(String groupId) async =>
      GroupPublicSummary(
        groupId: groupId,
        name: '그룹',
        status: GroupStatus.active,
        representativeCharacterNameSnapshot: '대표캐릭터',
        representativeServerNameSnapshot: '서버',
        leaderDisplayCharacterNameSnapshot: '대표캐릭터',
        memberCount: 1,
        revision: 1,
        hasActiveJoinCode: false,
        joinCodeVisibleToMembers: false,
        createdAt: _now,
        lastActivityAt: _now,
      );
}

class _Commands extends Fake implements GroupJoinCommandRepository {
  _Commands(this.reads);
  final _Reads reads;
  bool fail = false;
  int calls = 0;
  @override
  Future<void> refreshMyDisplaySnapshot(
    GroupMemberDisplaySnapshotRefreshCommand command,
  ) async {
    calls++;
    if (fail) throw StateError('write failed');
    reads.member = _member(
      power: command.snapshot.combatPower ?? reads.member.combatPowerSnapshot,
      joinedBy: reads.member.joinedBy,
    );
  }
}

class _Powers extends Fake implements CharacterCombatPowerSyncGateway {
  final saved = <String, double>{};
  bool fail = false;
  int calls = 0;
  Completer<void>? pending;
  @override
  Future<void> updateCombatPowers(
    Map<String, double> powersByCharacterId,
  ) async {
    calls++;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('sync failed');
    saved.addAll(powersByCharacterId);
  }
}

class _Search extends Fake implements GroupCharacterSearchRepository {
  _Search(this.powers, {this.integrityByCharacterId = const {}});
  final _Powers powers;
  final Map<String, BuildIntegritySnapshot?> integrityByCharacterId;
  @override
  Future<List<GroupRequestCharacter>> loadActiveCharactersForPlayer(
    String ownerPlayerId, {
    int limit = groupCharacterSearchPageSize,
  }) async => [
    for (var id = 1; id <= 2; id++)
      GroupRequestCharacter(
        characterId: 'character-$id',
        ownerPlayerId: ownerPlayerId,
        characterName: id == 1 ? '대표캐릭터' : '부캐릭터',
        serverName: '서버',
        characterClassName: '바드',
        itemLevel: 1700,
        combatPower: powers.saved['character-$id'],
        buildIntegritySnapshot: integrityByCharacterId['character-$id'],
      ),
  ];
}

class _Activity implements ActivityCharactersRepository {
  _Activity(this.byPlayer);
  final Map<String, Set<String>> byPlayer;

  @override
  Future<ActivityCharacters> load({required String playerId}) async {
    return ActivityCharacters(
      playerId: playerId,
      characterIds: byPlayer[playerId] ?? const {},
    );
  }

  @override
  Future<ActivityCharacters> save(SaveActivityCharactersCommand command) {
    throw UnimplementedError();
  }
}

void main() {
  late _Reads reads;
  late _Commands commands;
  late _Powers powers;
  setUp(() {
    reads = _Reads();
    commands = _Commands(reads);
    powers = _Powers();
  });
  GroupMembershipActionViewModel model({
    double? power = 3100,
    Map<String, Set<String>>? activityByPlayer,
    Map<String, BuildIntegritySnapshot?> integrityByCharacterId = const {},
  }) => GroupMembershipActionViewModel(
    accountRepository: _Accounts(power: power),
    readRepository: reads,
    commandRepository: commands,
    characterSearchRepository: _Search(
      powers,
      integrityByCharacterId: integrityByCharacterId,
    ),
    combatPowerSyncGateway: powers,
    activityCharactersRepository: _Activity(
      activityByPlayer ??
          {
            'player-1': {'character-1', 'character-2'},
          },
    ),
    playerId: 'player-1',
  );
  for (final joinedBy in GroupJoinedBy.values) {
    test('$joinedBy: 전투력 없는 membership을 복구하고 상세 캐릭터별로 동기화한다', () async {
      reads.member = _member(joinedBy: joinedBy);
      final vm = model();
      final result = await vm.loadMemberDisplays(
        groupId: 'group-1',
        playerId: 'player-1',
      );
      expect(result.syncFailed, isFalse);
      expect(result.members.single.combatPower, 3100);
      final details = await vm.loadPlayerCharacters('player-1');
      expect(details.map((character) => character.combatPower), [3100, 2200]);
    });
  }
  test('로컬 전투력 없음은 서버 전투력 삭제 명령을 보내지 않는다', () async {
    reads.member = _member(power: 2800);
    final result = await model(
      power: null,
    ).loadMemberDisplays(groupId: 'group-1', playerId: 'player-1');
    expect(result.members.single.combatPower, 2800);
    expect(commands.calls, 0);
    expect(powers.saved.containsKey('character-1'), isFalse);
  });
  test('Character 동기화 실패여도 membership 갱신과 목록은 계속된다', () async {
    powers.fail = true;
    final result = await model().loadMemberDisplays(
      groupId: 'group-1',
      playerId: 'player-1',
    );
    expect(result.syncFailed, isTrue);
    expect(result.members.single.combatPower, 3100);
    expect(commands.calls, 1);
  });
  testWidgets('Snapshot 갱신 실패를 표시하고 저장 목록은 계속 보여준다', (tester) async {
    commands.fail = true;
    reads.member = _member(power: 2800);
    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailPage(
          groupId: 'group-1',
          playerId: 'player-1',
          readRepository: reads,
          actionViewModel: model(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('groupDisplaySyncWarning')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('groupMemberCard-player-1')),
      findsOneWidget,
    );
  });
  testWidgets('동기화 중 새로고침 연타는 중복 요청을 만들지 않는다', (tester) async {
    powers.pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailPage(
          groupId: 'group-1',
          playerId: 'player-1',
          readRepository: reads,
          actionViewModel: model(),
        ),
      ),
    );
    await tester.pump();
    final button = find.byKey(const ValueKey('groupDetailRefreshButton'));
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    await tester.tap(button);
    await tester.tap(button);
    expect(powers.calls, 1);
    powers.pending!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
    expect(find.byKey(const ValueKey('groupDisplaySyncWarning')), findsNothing);
  });

  test('전투력 보강과 본인 Character 목록은 활동 Character만 담는다', () async {
    final vm = model(
      activityByPlayer: {
        'player-1': {'character-1'},
      },
    );
    final result = await vm.loadMemberDisplays(
      groupId: 'group-1',
      playerId: 'player-1',
    );
    expect(result.syncFailed, isFalse);
    expect(powers.saved.keys, ['character-1']);
    expect(powers.saved.containsKey('character-2'), isFalse);
    final mine = await vm.loadPlayerCharacters('player-1');
    expect(mine.map((character) => character.characterId), ['character-1']);
    final others = await vm.loadPlayerCharacters('player-2');
    expect(others, isEmpty);
  });

  test('다른 그룹원 활동 목록 누락을 인증 Character 전체로 대체하지 않는다', () async {
    final vm = model(activityByPlayer: const {});
    final others = await vm.loadPlayerCharacters('player-2');
    expect(others, isEmpty);
    final search = await vm.characterSearchRepository
        .loadActiveCharactersForPlayer('player-2');
    expect(search.map((character) => character.characterId), [
      'character-1',
      'character-2',
    ]);
  });
  test('비활동 Character membership Snapshot은 활동 해제만으로 지우지 않는다', () async {
    reads.member = _member(power: 2800);
    final result = await model(
      power: 3100,
      activityByPlayer: {
        'player-1': {'character-2'},
      },
    ).loadMemberDisplays(groupId: 'group-1', playerId: 'player-1');
    expect(result.members.single.combatPower, 2800);
    expect(commands.calls, 0);
    expect(powers.saved.containsKey('character-1'), isFalse);
    expect(powers.saved['character-2'], 2200);
  });
  testWidgets('그룹장은 바로 탈퇴 버튼 대신 나가기를 본다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailPage(
          groupId: 'group-1',
          playerId: 'player-1',
          readRepository: reads,
          actionViewModel: model(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('groupLeaveButton')), findsNothing);
    expect(find.byKey(const ValueKey('groupLeaderExitButton')), findsOneWidget);
  });

  testWidgets('활동 Character 무결성 상태를 별도 라벨로 표시한다', (tester) async {
    final checkedAt = DateTime.utc(2026, 9, 11);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 800)),
          child: GroupDetailPage(
            groupId: 'group-1',
            playerId: 'player-1',
            readRepository: reads,
            actionViewModel: model(
              integrityByCharacterId: {
                'character-1': BuildIntegritySnapshot(
                  status: BuildIntegrityStatus.error,
                  issueCodes: const [
                    BuildIntegrityIssueCode.foreignClassGem,
                    BuildIntegrityIssueCode.arkGridCondition,
                  ],
                  role: BuildIntegrityRole.dealer,
                  checkedAt: checkedAt,
                  catalogVersion: null,
                ),
                'character-2': BuildIntegritySnapshot(
                  status: BuildIntegrityStatus.review,
                  issueCodes: const [
                    BuildIntegrityIssueCode.sameClassGemUnverified,
                  ],
                  role: BuildIntegrityRole.support,
                  checkedAt: checkedAt,
                  catalogVersion: null,
                ),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('groupMemberCard-player-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('memberCharacter-character-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('memberCharacterIntegrity-character-1')),
      findsOneWidget,
    );
    expect(find.text('보석 오류'), findsOneWidget);
    expect(find.text('아크그리드 오류'), findsOneWidget);
    expect(find.text('보석 확인 필요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clean 무결성은 활동 목록에 추가 라벨을 만들지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailPage(
          groupId: 'group-1',
          playerId: 'player-1',
          readRepository: reads,
          actionViewModel: model(
            integrityByCharacterId: {
              'character-1': BuildIntegritySnapshot(
                status: BuildIntegrityStatus.clean,
                issueCodes: const [],
                role: BuildIntegrityRole.dealer,
                checkedAt: DateTime.utc(2026, 9, 11),
                catalogVersion: null,
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('groupMemberCard-player-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('memberCharacterIntegrity-character-1')),
      findsNothing,
    );
    expect(find.text('보석'), findsNothing);
  });
}
