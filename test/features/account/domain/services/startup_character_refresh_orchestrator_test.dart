import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_auto_refresh_result.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/nice_group_auto_refresh_settings_repository.dart';
import 'package:lost_party/features/account/domain/services/character_auto_refresh_coordinator.dart';
import 'package:lost_party/features/account/domain/services/startup_character_refresh_orchestrator.dart';

void main() {
  test('앱 수명 동안 같은 실행 Future를 재사용하고 각 Character를 한 번만 요청한다', () async {
    final repository = _FakeAccountRepository([
      _account(
        characters: [
          _character(1),
          _character(2, className: '도화가'),
        ],
      ),
    ]);
    final gateway = _FakeRefreshGateway();
    final orchestrator = _orchestrator(
      repository: repository,
      gateway: gateway,
    );

    final first = orchestrator.runOnce();
    final second = orchestrator.runOnce();

    expect(identical(first, second), isTrue);
    await first;
    expect(repository.loadCount, 1);
    expect(gateway.requests.map((request) => request.characterId), [1, 2]);
    await orchestrator.dispose();
  });

  test('활성 소유권의 인증된 1700 이상 Character만 요청한다', () async {
    final repository = _FakeAccountRepository([
      _account(
        characters: [
          _character(1, itemLevel: 1700),
          _character(2, itemLevel: 1699.99),
          _character(3, authenticated: false),
          _character(4, rosterMissing: true),
        ],
      ),
      _account(
        id: 2,
        active: false,
        characters: [_character(5, itemLevel: 1800)],
      ),
    ]);
    final gateway = _FakeRefreshGateway();
    final orchestrator = _orchestrator(
      repository: repository,
      gateway: gateway,
    );

    final report = await orchestrator.runOnce();

    expect(report.totalCount, 1);
    expect(gateway.requests.single.characterId, 1);
    await orchestrator.dispose();
  });

  test('나이스단 자동 갱신 OFF면 기존 판정 대상 요청을 제외 상태로 전달한다', () async {
    final settings = _FakeSettingsRepository(enabled: false);
    final gateway = _FakeRefreshGateway();
    final orchestrator = _orchestrator(
      repository: _FakeAccountRepository([
        _account(
          characters: [
            _character(1, className: '바드'),
            _character(2, className: '바드'),
            _character(3, className: '도화가'),
          ],
        ),
      ]),
      gateway: gateway,
      settings: settings,
    );

    await orchestrator.runOnce();

    expect(settings.loadedPlayerIds, ['player-1']);
    expect(
      gateway.requests
          .where((request) => request.characterId != 3)
          .every((request) => request.excludedFromAutoRefresh),
      isTrue,
    );
    expect(
      gateway.requests
          .singleWhere((request) => request.characterId == 3)
          .excludedFromAutoRefresh,
      isFalse,
    );
    await orchestrator.dispose();
  });

  test('나이스단 자동 갱신 ON이면 판정 대상도 일반 갱신으로 전달한다', () async {
    final gateway = _FakeRefreshGateway();
    final orchestrator = _orchestrator(
      repository: _FakeAccountRepository([
        _account(
          characters: [
            _character(1, className: '홀리나이트'),
            _character(2, className: '홀리나이트'),
          ],
        ),
      ]),
      gateway: gateway,
      settings: _FakeSettingsRepository(enabled: true),
    );

    await orchestrator.runOnce();

    expect(
      gateway.requests.every((request) => !request.excludedFromAutoRefresh),
      isTrue,
    );
    await orchestrator.dispose();
  });

  test('한 Character 요청 예외를 격리하고 나머지 요청과 상태 보고를 완료한다', () async {
    final gateway = _FakeRefreshGateway(failingIds: {2});
    final orchestrator = _orchestrator(
      repository: _FakeAccountRepository([
        _account(
          characters: [
            _character(1, className: '바드'),
            _character(2, className: '도화가'),
            _character(3, className: '홀리나이트'),
          ],
        ),
      ]),
      gateway: gateway,
    );
    final states = <StartupCharacterRefreshState>[];
    final subscription = orchestrator.states.listen(states.add);

    final report = await orchestrator.runOnce();

    expect(gateway.requests.length, 3);
    expect(report.failedCount, 1);
    expect(report.items.where((item) => item.isSuccess).length, 2);
    expect(orchestrator.state.phase, StartupCharacterRefreshPhase.completed);
    expect(orchestrator.state.completedCount, 3);
    expect(orchestrator.state.failedCount, 1);
    expect(states.first.phase, StartupCharacterRefreshPhase.running);
    expect(states.last.phase, StartupCharacterRefreshPhase.completed);
    await subscription.cancel();
    await orchestrator.dispose();
  });

  test('인증 세션이 없으면 계정이나 설정을 읽지 않고 완료한다', () async {
    final repository = _FakeAccountRepository([
      _account(characters: [_character(1)]),
    ]);
    final settings = _FakeSettingsRepository(enabled: true);
    final gateway = _FakeRefreshGateway();
    final orchestrator = _orchestrator(
      playerId: ' ',
      repository: repository,
      gateway: gateway,
      settings: settings,
    );

    final report = await orchestrator.runOnce();

    expect(report.totalCount, 0);
    expect(repository.loadCount, 0);
    expect(settings.loadedPlayerIds, isEmpty);
    expect(gateway.requests, isEmpty);
    await orchestrator.dispose();
  });

  test('계정 로드 실패를 호출자에게 던지지 않고 완료 보고서에 남긴다', () async {
    final orchestrator = _orchestrator(
      repository: _FakeAccountRepository(const [], loadError: StateError('db')),
      gateway: _FakeRefreshGateway(),
    );

    final report = await orchestrator.runOnce();

    expect(report.fatalError, isA<StateError>());
    expect(orchestrator.state.phase, StartupCharacterRefreshPhase.completed);
    expect(orchestrator.state.failedCount, 1);
    await orchestrator.dispose();
  });

  test('수동 갱신은 나이스단을 제외하고 TTL을 우회하는 강제 요청을 보낸다', () async {
    final gateway = _FakeRefreshGateway();
    final orchestrator = _orchestrator(
      repository: _FakeAccountRepository([
        _account(
          characters: [
            _character(1, className: '바드'),
            _character(2, className: '바드'),
            _character(3, className: '도화가'),
          ],
        ),
      ]),
      gateway: gateway,
    );

    final report = await orchestrator.runManualExcludingNiceGroup();

    expect(report.totalCount, 1);
    expect(gateway.requests.single.characterId, 3);
    expect(gateway.requests.single.force, isTrue);
    expect(gateway.requests.single.excludedFromAutoRefresh, isFalse);
    await orchestrator.dispose();
  });
}

StartupCharacterRefreshOrchestrator _orchestrator({
  String playerId = 'player-1',
  required _FakeAccountRepository repository,
  required _FakeRefreshGateway gateway,
  _FakeSettingsRepository? settings,
}) => StartupCharacterRefreshOrchestrator(
  playerId: playerId,
  accountRepository: repository,
  niceGroupAutoRefreshSettingsRepository:
      settings ?? _FakeSettingsRepository(enabled: false),
  refreshGateway: gateway,
);

LocalGameAccount _account({
  int id = 1,
  bool active = true,
  required List<LocalAccountCharacter> characters,
}) => LocalGameAccount(
  id: id,
  label: '계정$id',
  isMain: id == 1,
  lookupCharacterName: characters.first.characterName,
  representativeCharacterId: characters.first.id,
  displayLimit: 6,
  serverOwnershipStatus: active ? 'active' : 'released',
  characters: characters,
);

LocalAccountCharacter _character(
  int id, {
  String className = '기상술사',
  double itemLevel = 1700,
  bool authenticated = true,
  bool rosterMissing = false,
  CharacterBuildRole? preferredRole,
}) => LocalAccountCharacter(
  id: id,
  serverCharacterId: authenticated ? 'server-$id' : null,
  serverName: '루페온',
  characterName: '캐릭터$id',
  characterLevel: 70,
  characterClassName: className,
  itemLevel: itemLevel,
  combatPower: 100000,
  isVisible: true,
  displayOrder: id,
  preferredRole: preferredRole,
  isRosterMissing: rosterMissing,
);

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(this.accounts, {this.loadError});

  final List<LocalGameAccount> accounts;
  final Object? loadError;
  int loadCount = 0;

  @override
  Future<List<LocalGameAccount>> loadAccounts() async {
    loadCount++;
    if (loadError != null) throw loadError!;
    return accounts;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsRepository
    implements NiceGroupAutoRefreshSettingsRepository {
  _FakeSettingsRepository({required this.enabled});

  final bool enabled;
  final List<String> loadedPlayerIds = [];

  @override
  Future<bool> loadEnabled({required String playerId}) async {
    loadedPlayerIds.add(playerId);
    return enabled;
  }

  @override
  Future<void> saveEnabled({
    required String playerId,
    required bool enabled,
  }) async {}
}

class _FakeRefreshGateway implements CharacterAutoRefreshGateway {
  _FakeRefreshGateway({this.failingIds = const {}});

  final Set<int> failingIds;
  final List<CharacterAutoRefreshRequest> requests = [];

  @override
  Future<CharacterAutoRefreshResult> prefetch(
    CharacterAutoRefreshRequest request,
  ) async {
    requests.add(request);
    if (failingIds.contains(request.characterId)) {
      throw StateError('failed ${request.characterId}');
    }
    return CharacterAutoRefreshResult(
      status: request.excludedFromAutoRefresh
          ? CharacterAutoRefreshStatus.excluded
          : CharacterAutoRefreshStatus.refreshed,
      characterId: request.characterId,
      generation: request.generation,
      snapshot: null,
      detectedRole: request.expectedRole,
      expectedRoleChanged: false,
      message: null,
    );
  }
}
