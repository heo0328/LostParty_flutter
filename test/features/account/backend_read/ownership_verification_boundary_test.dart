import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/ownership_command_store.dart';
import 'package:lost_party/features/account/data/server_account_verification_client.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/ownership_command.dart';
import 'package:lost_party/features/account/presentation/pages/server_verification_page.dart';
import 'package:lost_party/features/account/presentation/viewmodels/ownership_dispute_controller.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_verification_view_model.dart';
import '../../../support/server_account_read_fakes.dart'
    show ReadSessionFake, ReadApiFake;
import 'ownership_dispute_client_test.dart' show OwnershipApiFake, JournalFake;
import 'ownership_dispute_fixtures.dart';
import 'server_verification_view_model_test.dart' as v1;

void main() {
  late ReadSessionFake session;
  late OwnershipApiFake api;
  late OwnershipDisputeController controller;
  late ServerVerificationViewModel legacy;
  late Map<String, dynamic> current;
  setUp(() async {
    session = ReadSessionFake()..userId = ownerId;
    current = proofJson();
    api = OwnershipApiFake()
      ..respond = () async {
        final call = api.calls.last;
        if (call.path == OwnershipCommand.proofsPath) {
          return pageJson(
            current['equipment_status'] == 'pending' ? [current] : [],
          );
        }
        if (call.path == OwnershipCommand.disputesPath) return pageJson([]);
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
    legacy = ServerVerificationViewModel(
      ServerAccountVerificationClient(
        v1.VerificationStateApi()..respond = (_) async => v1.snapshot(),
        session,
      ),
    );
  });
  tearDown(() {
    legacy.dispose();
    controller.dispose();
    session.dispose();
  });
  Widget page({
    required Future<void> Function() onVerified,
    required VoidCallback onCompleted,
    String? proof,
    String? dispute,
  }) => MaterialApp(
    home: ServerVerificationPage(
      model: legacy,
      ownership: controller,
      accounts: ServerAccountReadRepository(ReadApiFake(), session),
      onLogin: () {},
      onVerified: onVerified,
      onCompleted: onCompleted,
      proofId: proof,
      disputeId: dispute,
    ),
  );
  testWidgets(
    'equipment pass opening dispute never triggers ownership success handoff',
    (tester) async {
      var refreshed = 0, completed = 0;
      await tester.pumpWidget(
        page(
          onVerified: () async {
            refreshed++;
          },
          onCompleted: () {
            completed++;
          },
        ),
      );
      await tester.pumpAndSettle();
      current = {
        ...proofJson(),
        'version': 2,
        'equipment_status': 'passed',
        'ownership_outcome': 'dispute_opened',
        'result_code': 'DISPUTE_OPENED',
        'dispute_id': disputeId,
        'ended_at': wireNow,
        'allowed_actions': ['view_dispute'],
      };
      await tester.runAsync(() async {
        await controller.execute(
          OwnershipCommand.versioned(
            session,
            controller.scope!,
            operation: OwnershipOperation.confirm,
            key: commandKey,
            createdAt: clockNow,
            id: proofId,
            version: 1,
          ),
        );
        await controller.refresh();
      });
      await tester.pumpAndSettle();
      expect(find.text('인증 도전 시작'), findsOneWidget);
      expect(refreshed, 0);
      expect(completed, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'logout during verified account refresh prevents completion navigation',
    (tester) async {
      final refresh = Completer<void>();
      var completed = 0, calls = 0;
      await tester.pumpWidget(
        page(
          onVerified: () {
            calls++;
            return refresh.future;
          },
          onCompleted: () {
            completed++;
          },
        ),
      );
      await tester.pumpAndSettle();
      current = {
        ...proofJson(),
        'version': 2,
        'equipment_status': 'passed',
        'ownership_outcome': 'verified',
        'result_code': 'VERIFIED',
        'registration_id': regId,
        'ended_at': wireNow,
        'allowed_actions': ['open_registration'],
      };
      await tester.runAsync(() async {
        await controller.execute(
          OwnershipCommand.versioned(
            session,
            controller.scope!,
            operation: OwnershipOperation.confirm,
            key: commandKey,
            createdAt: clockNow,
            id: proofId,
            version: 1,
          ),
        );
        await controller.refresh();
      });
      await tester.pump();
      expect(controller.selectedProof?.outcome, 'verified');
      expect(
        controller.proofIsCurrent(proofId),
        isTrue,
        reason:
            'busy=${controller.commandBusy}, proof=${controller.proofFailure(proofId)?.code}, feed=${controller.proofsFailure?.code}, current=${controller.proofsCurrent}, calls=${api.calls.map((c) => c.path).join(',')}',
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(calls, 1);
      session.change(authenticated: false);
      refresh.complete();
      await tester.pumpAndSettle();
      expect(completed, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'V1 unfinished proof keeps V1 operations after V2 dependency is injected',
    (tester) async {
      await legacy.start(characterName: 'Hero');
      await tester.pumpWidget(
        page(onVerified: () async {}, onCompleted: () {}),
      );
      await tester.pumpAndSettle();
      expect(find.text('인증·도전 이력'), findsNothing);
      expect(find.text('장비 변경 확인'), findsOneWidget);
      expect(api.calls.where((c) => c.key != null), isEmpty);
      session.change(authenticated: false);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'conflicting explicit IDs reject entry without granting actions',
    (tester) async {
      await tester.pumpWidget(
        page(
          onVerified: () async {},
          onCompleted: () {},
          proof: proofId,
          dispute: disputeId,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('올바르지 않은 인증 대상입니다. 이전 화면에서 다시 진입해 주세요.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '장비 변경 확인'),
      );
      expect(button.onPressed, isNull);
      expect(api.calls.where((c) => c.key != null), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
