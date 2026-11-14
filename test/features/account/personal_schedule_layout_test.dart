import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/theme/app_theme.dart';
import 'package:lost_party/features/account/data/play_availability_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/play_availability_view_model.dart';
import 'package:lost_party/features/account/presentation/viewmodels/personal_schedule_view_model.dart';
import 'package:lost_party/features/account/presentation/widgets/account_page_typography.dart';
import 'package:lost_party/features/account/presentation/widgets/personal_schedule_section.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_read/play_availability_test.dart'
    show Api, Access, response, settle;
import 'backend_read/personal_schedule_test.dart'
    show ReservationsFake, pageJson, reservationJson;
import 'package:lost_party/features/account/domain/personal_reservations.dart';

void main() {
  for (final width in [320.0, 720.0, 1600.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('schedule all days width $width scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = ReadSessionFake(), access = Access(), api = Api();
        api.current = response(
          version: 2,
          rows: [
            for (var day = 1; day <= 7; day++)
              {
                'weekday': day,
                'start': '18:00',
                'end': '01:00',
                'end_day_offset': 1,
              },
          ],
        );
        final editor = PlayAvailabilityViewModel(
          repository: BackendPlayAvailabilityRepository(api),
          session: session,
          accessChanges: access,
          hasVerifiedAccount: () => access.verified,
        )..initialize();
        final repository = ReservationsFake();
        repository.onPage = (key, cursor) async => ReservationPage.fromJson(
          pageJson(
            items: [
              reservationJson(id: 2),
              reservationJson(
                start: '2026-11-18T12:00:01Z',
                end: '2026-11-18T12:00:02Z',
              ),
            ],
          ),
          key: key,
        );
        final schedule = PersonalScheduleViewModel(
          repository: repository,
          session: session,
        );
        addTearDown(() {
          editor.dispose();
          schedule.dispose();
          access.dispose();
          session.dispose();
        });
        await tester.runAsync(settle);
        editor.toggle();
        schedule.expanded = true;
        await schedule.reload();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1600),
                textScaler: TextScaler.linear(scale),
              ),
              child: AccountPageTypography(
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: PersonalScheduleSection(
                      schedule: schedule,
                      editor: editor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('내 예약'), findsOneWidget);
        expect(find.text('합성 레이드'), findsNothing);
        expect(
          find.byTooltip('합성 레이드, 합성 캐릭터, 26-11-18 21:00 ~ 21:00'),
          findsOneWidget,
        );
        final target = find.byTooltip('합성 레이드, 합성 캐릭터, 26-11-18 21:00 ~ 21:00');
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('이동'), findsOneWidget);
        expect(find.text('26-11-18 21:00 ~ 21:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('합성 레이드'), findsNothing);
      });
    }
  }
}
