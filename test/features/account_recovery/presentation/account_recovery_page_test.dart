import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account_recovery/domain/entities/account_recovery_status.dart';
import 'package:lost_party/features/account_recovery/domain/repositories/account_recovery_repository.dart';
import 'package:lost_party/features/account_recovery/presentation/pages/account_recovery_page.dart';

void main() {
  testWidgets('미연결 사용자는 Google 복구 연결을 시작할 수 있다', (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('재설치 전에 복구 수단을 연결해 주세요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('linkGoogleRecoveryButton')));
    await tester.pumpAndSettle();

    expect(repository.linkCalls, 1);
    expect(find.text('Google 계정 연결 완료'), findsOneWidget);
    expect(find.text('Google 계정을 복구 수단으로 연결했습니다.'), findsOneWidget);
  });

  testWidgets('credential 충돌은 현재 데이터 보존 안내를 표시한다', (tester) async {
    final repository = _FakeRepository(collision: true);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('linkGoogleRecoveryButton')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('다른 LOSTPARTY 사용자에게 이미 연결되어 있습니다'),
      findsOneWidget,
    );
    expect(find.text('재설치 전에 복구 수단을 연결해 주세요'), findsOneWidget);
  });
}

Widget _app(AccountRecoveryRepository repository) =>
    MaterialApp(home: AccountRecoveryPage(repository: repository));

class _FakeRepository implements AccountRecoveryRepository {
  _FakeRepository({this.collision = false});

  final bool collision;
  bool linked = false;
  int linkCalls = 0;

  @override
  Future<AccountRecoveryStatus> loadStatus() async =>
      AccountRecoveryStatus(isGoogleLinked: linked);

  @override
  Future<AccountRecoveryLinkResult> linkGoogle() async {
    linkCalls++;
    if (collision) {
      throw const AccountRecoveryException(
        AccountRecoveryFailureReason.credentialAlreadyInUse,
      );
    }
    linked = true;
    return AccountRecoveryLinkResult.linked;
  }
}
