import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/app/theme/app_theme.dart';
import 'package:lost_party/features/account/data/ownership_command_store.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/ownership_command.dart';
import 'package:lost_party/features/account/presentation/viewmodels/ownership_dispute_controller.dart';
import 'package:lost_party/features/account/presentation/widgets/ownership_notice_title.dart';
import '../../../support/server_account_read_fakes.dart' show ReadSessionFake;
import 'ownership_dispute_client_test.dart' show JournalFake, OwnershipApiFake;
import 'ownership_dispute_fixtures.dart';

const label = '원정대 방어 필요 · 확인';
void main() {
  late ReadSessionFake session;
  late OwnershipApiFake api;
  late OwnershipDisputeController controller;
  late List<Map<String, dynamic>> disputes;
  late Map<String, dynamic> current;
  var fail = false;
  setUp(() async {
    fail = false;
    session = ReadSessionFake()..userId = ownerId;
    current = disputeJson(role: 'owner');
    disputes = [current];
    api = OwnershipApiFake()
      ..respond = () async {
        if (fail) throw const AccountReadException('NETWORK_UNAVAILABLE');
        final call = api.calls.last;
        if (call.path == OwnershipCommand.proofsPath) return pageJson([]);
        if (call.path == OwnershipCommand.disputesPath) {
          return pageJson(disputes);
        }
        return current;
      };
    controller = OwnershipDisputeController(
      api: api,
      session: session,
      baseUrl: 'https://example.test',
      commands: OwnershipCommandStore(JournalFake()),
      now: () => clockNow,
    );
    await controller.refresh();
  });
  tearDown(() {
    controller.dispose();
    session.dispose();
  });
  Widget screen({
    bool scope = true,
    double scale = 1,
    String title = '내 계정',
    VoidCallback? onOpen,
  }) {
    final scaffold = Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('back'),
          onPressed: () {},
          icon: const Icon(Icons.arrow_back),
        ),
        title: OwnershipNoticeTitle(child: Text(title)),
        actions: [
          IconButton(
            key: const ValueKey('settings'),
            onPressed: () {},
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: const SizedBox(
        key: ValueKey('body'),
        width: double.infinity,
        height: 80,
      ),
    );
    return MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: scope
            ? OwnershipNoticeScope(
                controller: controller,
                onOpen: onOpen ?? () {},
                child: child!,
              )
            : child!,
      ),
      home: scaffold,
    );
  }

  testWidgets(
    'no scope preserves the existing title; notice keeps body/back/actions in place without requests',
    (tester) async {
      await tester.pumpWidget(screen(scope: false));
      final body = tester.getTopLeft(find.byKey(const ValueKey('body')));
      final back = tester.getRect(find.byKey(const ValueKey('back')));
      final settings = tester.getRect(find.byKey(const ValueKey('settings')));
      final before = api.calls.length;
      await tester.pumpWidget(screen());
      expect(find.text(label), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const ValueKey('body'))), body);
      expect(tester.getRect(find.byKey(const ValueKey('back'))), back);
      expect(tester.getRect(find.byKey(const ValueKey('settings'))), settings);
      expect(api.calls.length, before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow large text uses an accessible icon without clipping the toolbar or moving body',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(screen(scale: 2, title: '사라진 캐릭터명 기록'));
      expect(find.text(label), findsNothing);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(label))),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
        kToolbarHeight,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'processing/review/read failure stay distinct and logout removes the notice',
    (tester) async {
      await tester.pumpWidget(screen());
      current = disputeJson(role: 'owner', due: true);
      disputes = [current];
      await tester.runAsync(controller.refresh);
      await tester.pump();
      expect(find.text('원정대 인증 처리 중 · 확인'), findsOneWidget);
      current = {
        ...current,
        'state': 'review_required',
        'phase': 'review_required',
        'reason_code': 'PARTY_IMPACT_REVIEW_REQUIRED',
        'allowed_actions': <String>[],
      };
      disputes = [current];
      await tester.runAsync(controller.refresh);
      await tester.pump();
      expect(find.text('원정대 인증 확인 필요 · 확인'), findsOneWidget);
      fail = true;
      await tester.runAsync(controller.refresh);
      await tester.pump();
      expect(find.text('원정대 인증 확인 필요 · 확인'), findsOneWidget);
      session.change(authenticated: false);
      await tester.pump();
      expect(find.text('원정대 인증 확인 필요 · 확인'), findsNothing);
    },
  );
  testWidgets('keyboard can activate the notice without issuing any command', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OwnershipNoticeScope(
          controller: controller,
          onOpen: () {
            opened++;
          },
          child: Scaffold(
            appBar: AppBar(
              title: const OwnershipNoticeTitle(child: Text('내 계정')),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, 1);
    expect(api.calls.where((c) => c.key != null), isEmpty);
  });
  testWidgets(
    'single owner navigation deduplicates taps and back returns to the source',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/account',
        routes: [
          GoRoute(
            path: '/account',
            builder: (_, _) => const Scaffold(body: Text('source')),
          ),
          GoRoute(
            path: OwnershipNoticeNavigation.path,
            builder: (_, state) => Scaffold(
              appBar: AppBar(
                title: const OwnershipNoticeTitle(child: Text('원정대 인증')),
              ),
              body: Text(state.uri.queryParameters['disputeId'] ?? 'choose'),
            ),
          ),
        ],
      );
      final navigation = OwnershipNoticeNavigation(router, controller);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => OwnershipNoticeScope(
            controller: controller,
            onOpen: navigation.onOpen,
            child: child!,
          ),
        ),
      );
      final future = navigation.open();
      await navigation.open();
      await tester.pumpAndSettle();
      expect(find.text(disputeId), findsOneWidget);
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      await future;
      expect(router.state.uri.path, '/account');
      expect(router.canPop(), isFalse);
      expect(api.calls.where((c) => c.key != null), isEmpty);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );
  testWidgets(
    'already on verification only refreshes current dispute and never pushes a second page',
    (tester) async {
      final router = GoRouter(
        initialLocation: OwnershipNoticeNavigation.path,
        routes: [
          GoRoute(
            path: OwnershipNoticeNavigation.path,
            builder: (_, _) => const Scaffold(body: Text('verification')),
          ),
        ],
      );
      final navigation = OwnershipNoticeNavigation(router, controller);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.runAsync(navigation.open);
      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);
      expect(controller.selectedDisputeId, disputeId);
      expect(api.calls.where((c) => c.key != null), isEmpty);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );
  testWidgets(
    'multiple owners navigate to explicit selection rather than an arbitrary dispute',
    (tester) async {
      disputes = [
        current,
        {...current, 'dispute_id': secondKey},
      ];
      await tester.runAsync(controller.refresh);
      final router = GoRouter(
        initialLocation: '/account',
        routes: [
          GoRoute(
            path: '/account',
            builder: (_, _) => const Scaffold(body: Text('source')),
          ),
          GoRoute(
            path: OwnershipNoticeNavigation.path,
            builder: (_, state) => Scaffold(
              body: Text(state.uri.queryParameters['disputeId'] ?? 'choose'),
            ),
          ),
        ],
      );
      final navigation = OwnershipNoticeNavigation(router, controller);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final future = navigation.open();
      await tester.pumpAndSettle();
      expect(find.text('choose'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await future;
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );
}
