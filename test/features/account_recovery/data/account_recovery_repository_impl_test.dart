import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account_recovery/data/repositories/account_recovery_repository_impl.dart';
import 'package:lost_party/features/account_recovery/domain/entities/account_recovery_status.dart';

void main() {
  test('Google 연결 성공은 같은 UID와 provider 연결을 요구한다', () async {
    final gateway = _FakeGateway();
    final repository = AccountRecoveryRepositoryImpl(gateway);

    expect((await repository.loadStatus()).isGoogleLinked, isFalse);
    expect(await repository.linkGoogle(), AccountRecoveryLinkResult.linked);
    expect((await repository.loadStatus()).isGoogleLinked, isTrue);
    expect(gateway.linkCalls, 1);
  });

  test('이미 연결된 계정은 인증 창을 다시 열지 않는다', () async {
    final gateway = _FakeGateway(googleLinked: true);
    final repository = AccountRecoveryRepositoryImpl(gateway);

    expect(
      await repository.linkGoogle(),
      AccountRecoveryLinkResult.alreadyLinked,
    );
    expect(gateway.linkCalls, 0);
  });

  test('사용자 취소는 현재 UID와 provider를 변경하지 않는다', () async {
    final gateway = _FakeGateway(cancelled: true);
    final repository = AccountRecoveryRepositoryImpl(gateway);

    expect(await repository.linkGoogle(), AccountRecoveryLinkResult.cancelled);
    expect(gateway.currentIdentity?.uid, 'auth-1');
    expect(gateway.currentIdentity?.providerIds, isEmpty);
  });

  test('다른 사용자에게 연결된 credential은 자동 병합하지 않는다', () async {
    final gateway = _FakeGateway(failureCode: 'credential-already-in-use');
    final repository = AccountRecoveryRepositoryImpl(gateway);

    await expectLater(
      repository.linkGoogle(),
      throwsA(
        isA<AccountRecoveryException>().having(
          (error) => error.reason,
          'reason',
          AccountRecoveryFailureReason.credentialAlreadyInUse,
        ),
      ),
    );
    expect(gateway.currentIdentity?.uid, 'auth-1');
    expect(gateway.currentIdentity?.providerIds, isEmpty);
  });

  test('연결 결과 UID가 바뀌면 성공으로 처리하지 않는다', () async {
    final gateway = _FakeGateway(linkedUid: 'auth-2');
    final repository = AccountRecoveryRepositoryImpl(gateway);

    await expectLater(
      repository.linkGoogle(),
      throwsA(
        isA<AccountRecoveryException>().having(
          (error) => error.reason,
          'reason',
          AccountRecoveryFailureReason.uidChanged,
        ),
      ),
    );
  });

  test('Google 설정 오류는 provider 준비 오류로 변환한다', () async {
    final repository = AccountRecoveryRepositoryImpl(
      _FakeGateway(failureCode: 'clientConfigurationError'),
    );

    await expectLater(
      repository.linkGoogle(),
      throwsA(
        isA<AccountRecoveryException>().having(
          (error) => error.reason,
          'reason',
          AccountRecoveryFailureReason.providerNotEnabled,
        ),
      ),
    );
  });
}

class _FakeGateway implements AccountRecoveryGateway {
  _FakeGateway({
    bool googleLinked = false,
    this.cancelled = false,
    this.failureCode,
    this.linkedUid = 'auth-1',
  }) : _identity = AccountRecoveryIdentity(
         uid: 'auth-1',
         providerIds: googleLinked ? {googleAuthProviderId} : {},
       );

  AccountRecoveryIdentity _identity;
  final bool cancelled;
  final String? failureCode;
  final String linkedUid;
  int linkCalls = 0;

  @override
  AccountRecoveryIdentity? get currentIdentity => _identity;

  @override
  Future<String?> linkGoogle() async {
    linkCalls++;
    if (failureCode case final code?) {
      throw AccountRecoveryGatewayException(code);
    }
    if (cancelled) return null;
    _identity = AccountRecoveryIdentity(
      uid: linkedUid,
      providerIds: {googleAuthProviderId},
    );
    return linkedUid;
  }
}
