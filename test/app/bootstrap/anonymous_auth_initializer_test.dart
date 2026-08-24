import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/bootstrap/anonymous_auth_initializer.dart';

void main() {
  test('기존 인증 사용자가 있으면 다시 로그인하지 않는다', () async {
    final gateway = _FakeAnonymousAuthGateway(hasCurrentUser: true);

    await AnonymousAuthInitializer(gateway).initialize();

    expect(gateway.signInAttempts, 0);
  });

  test('인증 사용자가 없으면 익명 로그인한다', () async {
    final gateway = _FakeAnonymousAuthGateway();

    await AnonymousAuthInitializer(gateway).initialize();

    expect(gateway.signInAttempts, 1);
    expect(gateway.hasCurrentUser, isTrue);
  });

  test('익명 로그인 실패를 부트스트랩에 전달한다', () async {
    final gateway = _FakeAnonymousAuthGateway(signInError: StateError('실패'));

    await expectLater(
      AnonymousAuthInitializer(gateway).initialize(),
      throwsStateError,
    );
    expect(gateway.signInAttempts, 1);
  });

  test('로그인 결과에 사용자가 없으면 실패한다', () async {
    final gateway = _FakeAnonymousAuthGateway(createUserOnSignIn: false);

    await expectLater(
      AnonymousAuthInitializer(gateway).initialize(),
      throwsStateError,
    );
    expect(gateway.signInAttempts, 1);
  });
}

class _FakeAnonymousAuthGateway implements AnonymousAuthGateway {
  _FakeAnonymousAuthGateway({
    bool hasCurrentUser = false,
    this.createUserOnSignIn = true,
    this.signInError,
  }) : _hasCurrentUser = hasCurrentUser;

  bool _hasCurrentUser;
  final bool createUserOnSignIn;
  final Object? signInError;
  var signInAttempts = 0;

  @override
  bool get hasCurrentUser => _hasCurrentUser;

  @override
  Future<void> signInAnonymously() async {
    signInAttempts += 1;
    if (signInError case final error?) throw error;
    if (createUserOnSignIn) _hasCurrentUser = true;
  }
}
