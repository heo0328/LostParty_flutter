import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/server_account_verification_client.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/server_account_verification.dart';
import 'package:lost_party/features/account/presentation/pages/server_verification_page.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_verification_view_model.dart';

import '../../../support/server_account_read_fakes.dart';
import 'server_verification_view_model_test.dart' as fixture;

void main() {
  late ReadSessionFake session;
  late fixture.VerificationStateApi api;
  late ServerVerificationViewModel model;
  late ServerAccountReadRepository accounts;
  late ReadApiFake readApi;
  setUp(() {
    session = ReadSessionFake();
    api = fixture.VerificationStateApi()
      ..respond = (_) async => fixture.snapshot(status: 'verified');
    model = ServerVerificationViewModel(
      ServerAccountVerificationClient(api, session),
    );
    readApi = ReadApiFake()
      ..onRegistrations = (_) async => ServerRegistrationPage.fromJson({
        'items': [
          registrationJson()
            ..['ownership_status'] = 'unverified'
            ..['verification_status'] = 'unverified',
        ],
        'next_cursor': null,
      });
    accounts = ServerAccountReadRepository(readApi, session);
  });
  tearDown(() {
    model.dispose();
    session.dispose();
  });
  Widget page({
    Future<void> Function()? reload,
    Future<void> Function(String)? handoff,
  }) => MaterialApp(
    home: ServerVerificationPage(
      model: model,
      accounts: accounts,
      initialRegistrationId: registrationId,
      onLogin: () {},
      onVerified: reload ?? () async {},
      onVerifiedRegistration: handoff,
    ),
  );

  testWidgets(
    'server ownership rejection refreshes and greys roster without success navigation',
    (tester) async {
      var refreshes = 0, handoffs = 0;
      await tester.pumpWidget(
        page(
          reload: () async {
            refreshes++;
          },
          handoff: (_) async {
            handoffs++;
          },
        ),
      );
      await tester.pumpAndSettle();
      final readsBefore = readApi.registrationCalls;
      readApi.onRegistrations = (_) async =>
          ServerRegistrationPage.fromJson(registrationPageJson());
      api.respond = (_) async =>
          throw const AccountReadException('ALREADY_VERIFIED', status: 409);
      await model.start(characterName: 'new-alias');
      await tester.pumpAndSettle();
      expect(find.text('이미 인증된 원정대입니다.'), findsOneWidget);
      expect(readApi.registrationCalls, greaterThan(readsBefore));
      expect(find.text('인증 요청 다시 시도'), findsNothing);
      expect(find.text('장비 변경 확인'), findsNothing);
      expect(find.byType(ServerVerificationPage), findsOneWidget);
      expect(refreshes, 1);
      expect(handoffs, 0);
      final menu = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(menu.items!.single.enabled, isFalse);
      expect(model.value, isNull);
      expect(api.calls, hasLength(1));
    },
  );

  testWidgets(
    'owned roster stays disabled in list and search does not issue a challenge',
    (tester) async {
      readApi.onRegistrations = (_) async =>
          ServerRegistrationPage.fromJson(registrationPageJson());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, isNull);
      final menu = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(menu.items!.single.enabled, isFalse);
      expect((menu.items!.single.child as Text).data, 'sample-account - 인증됨');
      await tester.tap(find.text('캐릭터 검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sample');
      await tester.ensureVisible(find.text('인증 시작'));
      await tester.tap(find.text('인증 시작'));
      await tester.pumpAndSettle();
      expect(find.text('이미 인증된 원정대입니다.'), findsOneWidget);
      expect(api.calls, isEmpty);
      expect(model.hasPending, isFalse);
    },
  );

  testWidgets(
    'normal pending hides result lookup; a failed read exposes explicit recovery',
    (tester) async {
      api.respond = (_) async => fixture.snapshot();
      await model.start(characterName: 'sample');
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('인증 결과 다시 확인'), findsNothing);
      api.respond = (method) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await model.reload();
      await tester.pumpAndSettle();
      expect(find.text('인증 결과 다시 확인'), findsOneWidget);
      expect(api.calls.where((c) => c.method == 'POST'), hasLength(1));
    },
  );

  testWidgets(
    'success refreshes and returns once to the page that opened verification',
    (tester) async {
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ServerVerificationPage(
                      model: model,
                      accounts: accounts,
                      onLogin: () {},
                      onVerified: () async {
                        refreshes++;
                      },
                    ),
                  ),
                ),
                child: const Text('previous page'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('previous page'));
      await tester.pumpAndSettle();
      await model.start(characterName: 'sample');
      await tester.pumpAndSettle();
      expect(find.byType(ServerVerificationPage), findsNothing);
      expect(find.text('previous page'), findsOneWidget);
      expect(refreshes, 1);
      expect(api.calls.map((c) => c.method), ['POST', 'GET']);
    },
  );

  testWidgets(
    'revision rejection requires new roster selection and sends fresh version',
    (tester) async {
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '인증 시작'))
            .onPressed,
        isNull,
      );
      Future<void> choose() async {
        await tester.ensureVisible(
          find.byType(DropdownButtonFormField<VerificationTarget>),
        );
        await tester.tap(
          find.byType(DropdownButtonFormField<VerificationTarget>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('sample · sample-server').last);
        await tester.pumpAndSettle();
      }

      await choose();
      api.respond = (_) async =>
          throw const AccountReadException('REVISION_CONFLICT', status: 409);
      await tester.ensureVisible(find.text('인증 시작'));
      await tester.tap(find.text('인증 시작'));
      await tester.pumpAndSettle();
      expect(
        find.byType(DropdownButtonFormField<VerificationTarget>),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '인증 시작'))
            .onPressed,
        isNull,
      );
      expect(api.calls, hasLength(1));
      readApi.onRegistrations = (_) async => ServerRegistrationPage.fromJson({
        'items': [
          registrationJson()
            ..['version'] = 3
            ..['ownership_status'] = 'unverified'
            ..['verification_status'] = 'unverified',
        ],
        'next_cursor': null,
      });
      await tester.ensureVisible(find.text('원정대·캐릭터 다시 조회'));
      await tester.tap(find.text('원정대·캐릭터 다시 조회'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '인증 시작'))
            .onPressed,
        isNull,
      );
      await choose();
      api.respond = (_) async => fixture.snapshot(status: 'verified');
      await tester.ensureVisible(find.text('인증 시작'));
      await tester.tap(find.text('인증 시작'));
      await tester.pumpAndSettle();
      expect(
        api.calls
            .where((c) => c.method == 'POST')
            .last
            .body!['expected_registration_version'],
        3,
      );
      expect(model.value!.status, ServerVerificationStatus.verified);
    },
  );

  testWidgets(
    'uncertain start survives page reentry with original target and exact replay',
    (tester) async {
      api.respond = (_) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<VerificationTarget>),
      );
      await tester.tap(
        find.byType(DropdownButtonFormField<VerificationTarget>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('sample · sample-server').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('인증 시작'));
      await tester.tap(find.text('인증 시작'));
      await tester.pumpAndSettle();
      expect(model.attempt!.registrationLabel, 'sample-account');
      final original = api.calls.single;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: ServerVerificationPage(
            model: model,
            accounts: accounts,
            // A different route hint must not replace the pending target.
            initialRegistrationId: secondCharacterId,
            onLogin: () {},
            onVerified: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('원정대: sample-account'), findsOneWidget);
      expect(find.text('인증 시작 결과 확인 필요'), findsOneWidget);
      expect(find.text('인증 요청 다시 시도'), findsOneWidget);
      expect(api.calls, hasLength(1));
      expect(find.text('인증 시작'), findsNothing);
      api.respond = (_) async => fixture.snapshot(status: 'expired');
      await tester.ensureVisible(find.text('인증 요청 다시 시도'));
      await tester.tap(find.text('인증 요청 다시 시도'));
      await tester.pumpAndSettle();
      expect(api.calls.map((c) => c.method), ['POST', 'POST', 'GET']);
      expect(api.calls[1].key, original.key);
      expect(identical(api.calls[1].body, original.body), isTrue);
      expect(api.calls[1].body, {
        'source': 'registration',
        'registration_id': registrationId,
        'target_character': {
          'server_name': 'sample-server',
          'character_name': 'sample',
        },
        'expected_registration_version': 1,
      });
      expect(model.canStart, isTrue);
      expect(find.text('인증 시작'), findsOneWidget);
    },
  );

  testWidgets(
    'accepted start retains target across failed GET and logout clears context',
    (tester) async {
      api.respond = (method) async {
        if (method == 'GET') {
          throw const AccountReadException('NETWORK_UNAVAILABLE');
        }
        return fixture.snapshot();
      };
      await model.start(characterName: ' original-character ');
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('캐릭터: original-character'), findsOneWidget);
      expect(find.text('현재 인증 상태 확인 필요'), findsOneWidget);
      expect(find.text('인증 요청 다시 시도'), findsNothing);
      expect(find.text('인증 결과 다시 확인'), findsOneWidget);
      expect(api.calls.where((c) => c.method == 'POST'), hasLength(1));
      session.change(authenticated: false);
      await tester.pumpAndSettle();
      expect(model.attempt, isNull);
      expect(find.text('캐릭터: original-character'), findsNothing);
    },
  );

  testWidgets(
    'unrecoverable start without ID does not offer a nonexistent state lookup',
    (tester) async {
      api.respond = (_) async =>
          throw const AccountReadException('IDEMPOTENCY_EXPIRED', status: 409);
      await model.start(characterName: 'original-character');
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('캐릭터: original-character'), findsOneWidget);
      expect(find.text('인증 결과 다시 확인'), findsNothing);
      expect(find.text('이전 요청을 확인할 수 없어 새 인증을 시작할 수 없습니다.'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '인증 요청 다시 시도'),
      );
      expect(button.onPressed, isNull);
      expect(model.canStart, isFalse);
      expect(api.calls, hasLength(1));
    },
  );

  testWidgets(
    'registration context is selected; successful result ID is handed off after refresh',
    (tester) async {
      final ids = <String>[];
      await tester.pumpWidget(page(handoff: (id) async => ids.add(id)));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        registrationId,
      );
      await model.start(registrationId: registrationId);
      await tester.pumpAndSettle();
      expect(ids, [registrationId]);
    },
  );

  testWidgets(
    'historical verified state never redirects a newly opened verification page',
    (tester) async {
      model.value = ServerAccountVerification.fromJson(
        fixture.snapshot(status: 'verified'),
      );
      var handoffs = 0;
      await tester.pumpWidget(
        page(
          handoff: (_) async {
            handoffs++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(handoffs, 0);
    },
  );

  testWidgets(
    'logout during post-verification refresh blocks late navigation',
    (tester) async {
      final entered = Completer<void>(), release = Completer<void>();
      var handoffs = 0;
      await tester.pumpWidget(
        page(
          reload: () async {
            entered.complete();
            await release.future;
          },
          handoff: (_) async {
            handoffs++;
          },
        ),
      );
      await tester.pumpAndSettle();
      await model.start(registrationId: registrationId);
      await tester.pump();
      await entered.future;
      session.change(authenticated: false);
      release.complete();
      await tester.pumpAndSettle();
      expect(handoffs, 0);
    },
  );

  testWidgets(
    'ownership/canonical handoff failure is recoverable without restarting verification',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        page(
          handoff: (_) async {
            if (attempts++ == 0) {
              throw StateError('current ownership read failed');
            }
          },
        ),
      );
      await tester.pumpAndSettle();
      await model.start(registrationId: registrationId);
      await tester.pumpAndSettle();
      expect(find.text('목록 다시 조회'), findsOneWidget);
      await tester.tap(find.text('목록 다시 조회'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('목록 다시 조회'), findsNothing);
      expect(api.calls.where((c) => c.method == 'POST'), hasLength(1));
    },
  );
}
