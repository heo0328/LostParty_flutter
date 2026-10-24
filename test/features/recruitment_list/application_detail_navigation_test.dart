import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/domain/member_cycle_models.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_account_view_model.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_weekly_view_model.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_read_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/cycle_own_rooms_page.dart';
import '../../support/server_account_read_fakes.dart';
import '../account/backend_read/member_cycles_test.dart' as f1;
import 'cycle_interaction_test.dart' as f3;
import 'cycle_recruitment_test.dart' as f2;

class _Account extends ChangeNotifier implements MemberAccountViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Weekly extends ChangeNotifier implements MemberWeeklyViewModel {
  @override
  final model = _Account();
  @override
  final cycles = MemberCycles.fromJson(f1.cycles());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }
}

void main() {
  for (final target in [f1.current, f1.next]) {
    testWidgets(
      'application card opens general detail at exact $target, never member reader',
      (tester) async {
        final session = ReadSessionFake(), weekly = _Weekly();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
        final calls = <RequestOptions>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (r, h) {
              calls.add(r);
              final applications = r.path.endsWith('raid-room-applications');
              h.resolve(
                Response(
                  requestOptions: r,
                  statusCode: 200,
                  data: f2.envelope(target, {
                    'items': [if (applications) f3.appWire(target)['data']],
                    if (applications)
                      'applications_revision': 1
                    else
                      'membership_head': 1,
                    'next_cursor': null,
                    'evaluated_at': f2.nowStamp,
                  }),
                ),
              );
            },
          ),
        );
        (String, String)? application;
        await tester.pumpWidget(
          MaterialApp(
            home: CycleOwnRoomsPage(
              weekly: weekly,
              initialTarget: target,
              repository: CycleReadRepository(
                DioBackendAccountReadApi(dio, session),
                membershipProfile: true,
              ),
              scopeKey: () => 'env/${session.userId}/${session.generation}',
              onLogin: () => fail('unexpected login'),
              onRoom: (_, _) => fail('application must not use member detail'),
              onApplicationRoom: (room, t) => application = (room, t),
              onRecord: (_, _, _) => fail('application must not use record'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('신청 중'));
        await tester.pumpAndSettle();
        expect(find.text('승인 대기'), findsOneWidget);
        await tester.tap(find.text('신청한 모집'));
        expect(application, (f3.room, target));
        final request = calls.last;
        expect(request.queryParameters['target_cycle_key'], target);
        expect(request.queryParameters.containsKey('reader_profile'), false);
        expect(calls.every((r) => r.method == 'GET'), true);
        await tester.pumpWidget(const SizedBox.shrink());
        weekly.dispose();
        session.dispose();
        dio.close(force: true);
      },
    );
  }
}
