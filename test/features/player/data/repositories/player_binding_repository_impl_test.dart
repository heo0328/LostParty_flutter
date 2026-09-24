import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/player/data/datasources/player_binding_store.dart';
import 'package:lost_party/features/player/data/repositories/player_binding_repository_impl.dart';

void main() {
  test('같은 AuthUid의 기존 PlayerId를 세션으로 반환한다', () async {
    final store = _FakePlayerBindingStore(playerId: 'player-existing');
    final repository = PlayerBindingRepositoryImpl(store);

    final session = await repository.getOrCreate(authUid: 'auth-uid');

    expect(session.authUid, 'auth-uid');
    expect(session.playerId, 'player-existing');
    expect(store.requestedAuthUids, ['auth-uid']);
  });

  test('AuthUid 주변 공백을 제거하고 빈 값은 거부한다', () async {
    final store = _FakePlayerBindingStore(playerId: 'player-id');
    final repository = PlayerBindingRepositoryImpl(store);

    final session = await repository.getOrCreate(authUid: ' auth-uid ');
    expect(session.authUid, 'auth-uid');
    expect(store.requestedAuthUids, ['auth-uid']);

    await expectLater(
      repository.getOrCreate(authUid: ' '),
      throwsArgumentError,
    );
  });

  test('저장소 실패를 부트스트랩에 전달한다', () async {
    final repository = PlayerBindingRepositoryImpl(
      _FakePlayerBindingStore(error: StateError('binding 실패')),
    );

    await expectLater(
      repository.getOrCreate(authUid: 'auth-uid'),
      throwsStateError,
    );
  });

  test('복구 조회는 기존 binding만 반환하고 새 Player를 만들지 않는다', () async {
    final existingStore = _FakePlayerBindingStore(
      existingPlayerId: 'player-existing',
    );
    final existing = await PlayerBindingRepositoryImpl(
      existingStore,
    ).getExisting(authUid: ' auth-uid ');

    expect(existing?.authUid, 'auth-uid');
    expect(existing?.playerId, 'player-existing');
    expect(existingStore.getOrCreateCalls, 0);

    final missingStore = _FakePlayerBindingStore();
    final missing = await PlayerBindingRepositoryImpl(
      missingStore,
    ).getExisting(authUid: 'auth-uid');
    expect(missing, isNull);
    expect(missingStore.getOrCreateCalls, 0);
  });
}

class _FakePlayerBindingStore implements PlayerBindingStore {
  _FakePlayerBindingStore({
    this.playerId = 'player-created',
    this.existingPlayerId,
    this.error,
  });

  final String playerId;
  final String? existingPlayerId;
  final Object? error;
  final requestedAuthUids = <String>[];
  var getOrCreateCalls = 0;

  @override
  Future<String?> getExistingActivePlayerId({required String authUid}) async {
    requestedAuthUids.add(authUid);
    if (error case final error?) throw error;
    return existingPlayerId;
  }

  @override
  Future<String> getOrCreateActivePlayerId({required String authUid}) async {
    getOrCreateCalls += 1;
    requestedAuthUids.add(authUid);
    if (error case final error?) throw error;
    return playerId;
  }
}
