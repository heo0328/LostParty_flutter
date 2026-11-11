@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:lost_party/features/auth/domain/auth_session_controller.dart';
import 'package:lost_party/features/auth/presentation/google_auth_platform_web.dart';

import 'features/auth/auth_session_controller_test.dart'
    show FakeApi, FakeGoogle, MemoryStore;

class TestHtmlViews implements ui_web.PlatformViewRegistry {
  final elements = <int, web.HTMLElement>{};
  @override
  bool registerViewFactory(
    String viewType,
    Function viewFactory, {
    bool isVisible = true,
  }) => true;
  @override
  Object getViewById(int viewId) => elements[viewId]!;
  Future<Object?> handle(MethodCall call) async {
    if (call.method == 'create') {
      final arguments = call.arguments as Map;
      final element = web.HTMLDivElement();
      elements[arguments['id'] as int] = element;
      web.document.body!.appendChild(element);
    } else if (call.method == 'dispose') {
      elements.remove(call.arguments)?.remove();
    }
    return null;
  }

  void clear() {
    for (final element in elements.values) {
      element.remove();
    }
  }
}

class FakeGis implements WebGoogleServices {
  bool failLoad = false;
  int loads = 0, renders = 0;
  JSObject? initialization, button;
  @override
  Future<void> load() async {
    loads++;
    if (failLoad) throw StateError('SDK blocked');
  }

  @override
  void initialize(JSObject configuration) => initialization = configuration;
  @override
  void renderButton(web.HTMLElement element, JSObject configuration) {
    renders++;
    button = configuration;
  }

  void click() =>
      button!.getProperty<JSFunction>('click_listener'.toJS).callAsFunction();
  void respond(String state) => initialization!
      .getProperty<JSFunction>('callback'.toJS)
      .callAsFunction(
        null,
        {'state': state, 'credential': 'synthetic-google-proof'}.jsify(),
      );
  String get state => button!.getProperty<JSString>('state'.toJS).toDart;
}

void main() {
  late FakeApi api;
  late AuthSessionController auth;
  late FakeGis gis;
  late TestHtmlViews views;
  setUp(() async {
    views = TestHtmlViews();
    ui_web.debugOverridePlatformViewRegistry(views);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, views.handle);
    api = FakeApi()..now = DateTime.now().toUtc();
    auth = AuthSessionController(
      api: api,
      google: FakeGoogle(),
      store: MemoryStore(),
      serverClientId: 'configured-web-client',
      clock: () => api.now,
    );
    await auth.restore();
    gis = FakeGis();
  });
  tearDown(() {
    views.clear();
    ui_web.debugOverridePlatformViewRegistry(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
    auth.dispose();
  });

  testWidgets('blocked SDK has explicit retry and creates no challenge', (
    tester,
  ) async {
    gis.failLoad = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildWebGoogleButton(
            auth: auth,
            remember: false,
            onLocked: (_) {},
            onSuccess: () {},
            services: gis,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(api.challenges, 0);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(gis.loads, 2);
    expect(api.challenges, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'GIS receives nonce; stale and duplicate callbacks cannot exchange',
    (tester) async {
      var successes = 0;
      var remember = false;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return buildWebGoogleButton(
                  auth: auth,
                  remember: remember,
                  onLocked: (_) {},
                  onSuccess: () => successes++,
                  services: gis,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(gis.renders, 1);
      expect(
        gis.initialization!.getProperty<JSString>('client_id'.toJS).toDart,
        'configured-web-client',
      );
      expect(
        gis.initialization!.getProperty<JSString>('nonce'.toJS).toDart,
        'server-nonce',
      );
      rebuild(() => remember = true);
      await tester.pump();
      expect(gis.renders, 1);
      gis.click();
      gis.respond('previous-button-state');
      await tester.pump();
      expect(api.logins, 0);
      // JS callbacks cross the fake-async zone; allow their real microtasks to
      // finish before asserting the synthetic Backend/session result.
      await tester.runAsync(() async {
        gis.respond(gis.state);
        gis.respond(gis.state);
        for (var i = 0; i < 20 && !auth.isAuthenticated; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(api.logins, 1);
      expect(api.loginRemember, isTrue, reason: 'checkbox value at click');
      expect(
        auth.isAuthenticated,
        isTrue,
        reason: 'status=${auth.status} code=${auth.errorCode}',
      );
      expect(successes, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
