import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/presentation/widgets/account_auth_actions.dart';
import 'package:lost_party/features/auth/domain/auth_session_controller.dart';
import '../features/auth/auth_session_controller_test.dart'
    show FakeApi, FakeGoogle, MemoryStore;

class _SignedIn extends AuthSessionController {
  _SignedIn()
    : super(
        api: FakeApi(),
        google: FakeGoogle(),
        store: MemoryStore(),
        serverClientId: 'test',
      );
  @override
  bool get isAuthenticated => true;
  @override
  bool get isBusy => false;
  @override
  String? get userId => 'hidden-member';
}

void main() {
  for (final width in [360.0, 720.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('auth toolbar fits width $width scale $scale', (
        tester,
      ) async {
        final auth = _SignedIn();
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          auth.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: Builder(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    toolbarHeight: AccountAuthActions.toolbarHeight(context),
                    title: const Text('내 계정'),
                    actions: [
                      AccountAuthActions(auth: auth),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('hidden-member'), findsNothing);
        expect(find.byTooltip('회원 ID 복사'), findsNothing);
        expect(find.text('로그아웃'), findsOneWidget);
      });
    }
  }
}
