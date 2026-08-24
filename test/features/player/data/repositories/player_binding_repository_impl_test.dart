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
}

class _FakePlayerBindingStore implements PlayerBindingStore {
  _FakePlayerBindingStore({this.playerId = 'player-created', this.error});

  final String playerId;
  final Object? error;
  final requestedAuthUids = <String>[];

  @override
  Future<String> getOrCreateActivePlayerId({required String authUid}) async {
    requestedAuthUids.add(authUid);
    if (error case final error?) throw error;
    return playerId;
  }
}
