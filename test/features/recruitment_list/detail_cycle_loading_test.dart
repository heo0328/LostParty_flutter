import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/presentation/widgets/member_cycle_selector.dart';
import 'package:lost_party/features/recruitment_list/data/backend_recruitment_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/backend_recruitment.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/backend_recruitment_detail_page.dart';

import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;

void main() {
  for (final fails in [false, true]) {
    testWidgets(
      'detail blocks return to C until delayed N ${fails ? '500 failure' : 'success'} completes',
      (tester) async {
        final session = ReadSessionFake();
        final gateway = cycles.CycleGateway();
        final waiting = Completer<BackendRecruitmentDetail>();
        final reads = <String>[];
        BackendRecruitmentDetail detail(String target) =>
            BackendRecruitmentRepository.parseCycleDetail(
              cycles.detail(target),
              base.roomId,
              target,
            );
        gateway.onCycleDetail = (target) async {
          reads.add(target);
          return target == cycles.n ? waiting.future : detail(target);
        };
        await tester.pumpWidget(
          MaterialApp(
            home: BackendRecruitmentDetailPage(
              gateway: gateway,
              session: session,
              roomId: base.roomId,
              target: cycles.c,
              onLogin: () {},
              onCreateAnother: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        MemberCycleSelector selector() => tester.widget<MemberCycleSelector>(
          find.byType(MemberCycleSelector),
        );
        expect(selector().enabled, true);
        final previousFrame = selector().onChanged;
        await tester.tap(find.text('다음 주'));
        // Also fence callbacks retained from the enabled frame before rebuild.
        previousFrame(cycles.c);
        await tester.pump();
        expect(selector().value, cycles.n);
        expect(selector().enabled, false);
        expect(
          tester
              .widget<SegmentedButton<String>>(
                find.byType(SegmentedButton<String>),
              )
              .onSelectionChanged,
          isNull,
        );
        await tester.tap(find.text('이번 주'));
        await tester.pump();
        expect(reads, [cycles.c, cycles.n]);
        expect(selector().value, cycles.n);

        if (fails) {
          waiting.completeError(
            const AccountReadException('INTERNAL_ERROR', status: 500),
          );
        } else {
          waiting.complete(detail(cycles.n));
        }
        await tester.pumpAndSettle();
        expect(selector().enabled, true);
        expect(selector().value, cycles.n);
        expect(find.text('상세 다시 불러오기'), fails ? findsOne : findsNothing);

        await tester.tap(find.text('이번 주'));
        await tester.pumpAndSettle();
        expect(selector().value, cycles.c);
        expect(selector().enabled, true);
        expect(find.text('상세 다시 불러오기'), findsNothing);
        expect(reads, [cycles.c, cycles.n, cycles.c]);
        expect(gateway.writes, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
      },
    );
  }
}
