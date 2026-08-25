import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_read_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/recruitment_list_page.dart';

import '../../../support/party_read_fakes.dart';

void main() {
  testWidgets('첫 성공 없이 오류면 전체 오류와 재시도를 보여 준다', (tester) async {
    final firstPage = StreamController<PublicRecruitmentPage>.broadcast();
    addTearDown(firstPage.close);
    final repository = FakePartyReadRepository(
      publicFirstPage: firstPage.stream,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentListPage(
          partyReadRepository: repository,
          cycleKey: '2026-08-19',
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    firstPage.addError(
      const PartyReadException(PartyReadFailureType.unavailable),
    );
    await tester.pump();

    expect(find.text('일시적으로 연결할 수 없습니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('publicListRetryButton')), findsOneWidget);
  });

  testWidgets('빈 캐시 목록은 빈 상태와 오프라인 안내를 함께 보여 준다', (tester) async {
    final firstPage = StreamController<PublicRecruitmentPage>.broadcast();
    addTearDown(firstPage.close);
    final repository = FakePartyReadRepository(
      publicFirstPage: firstPage.stream,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentListPage(
          partyReadRepository: repository,
          cycleKey: '2026-08-19',
        ),
      ),
    );

    firstPage.add(
      const PublicRecruitmentPage(
        items: [],
        hasMore: false,
        isFromCache: true,
      ),
    );
    await tester.pump();

    expect(find.text('현재 모집 중인 파티가 없습니다.'), findsOneWidget);
    expect(find.textContaining('오프라인'), findsOneWidget);
  });

  testWidgets('목록 카드는 raid-status 상세로 이동하고 추가 오류 재시도를 제공한다', (
    tester,
  ) async {
    final firstPage = StreamController<PublicRecruitmentPage>.broadcast();
    addTearDown(firstPage.close);
    var failNext = true;
    final repository = FakePartyReadRepository(
      publicFirstPage: firstPage.stream,
      loadNextPage: ({
        required String cycleKey,
        required PublicRecruitmentPageCursor cursor,
        int limit = publicRecruitmentPageSize,
      }) async {
        if (failNext) {
          failNext = false;
          throw const PartyReadException(PartyReadFailureType.unavailable);
        }
        return PublicRecruitmentPage(
          items: [_summary('c')],
          hasMore: false,
          isFromCache: false,
        );
      },
    );

    final router = GoRouter(
      initialLocation: '/recruitments',
      routes: [
        GoRoute(
          path: '/recruitments',
          builder: (context, state) => RecruitmentListPage(
            partyReadRepository: repository,
            cycleKey: '2026-08-19',
          ),
        ),
        GoRoute(
          path: '/raid-status/:id',
          builder: (context, state) => Scaffold(
            body: Text('detail:${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    firstPage.add(
      PublicRecruitmentPage(
        items: [for (var i = 0; i < 12; i++) _summary('item-$i')],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('item-11'),
        isFromCache: false,
      ),
    );
    await tester.pump();
    expect(find.text('모집 item-0'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pump();
    await tester.pump();

    expect(find.text('일시적으로 연결할 수 없습니다.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('publicListAppendRetryButton')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('publicListAppendRetryButton')));
    await tester.pump();
    await tester.pump();
    expect(find.text('모집 c'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 4000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모집 item-0'));
    await tester.pumpAndSettle();
    expect(find.text('detail:item-0'), findsOneWidget);
  });
}

PublicRecruitmentSummary _summary(String id) => PublicRecruitmentSummary(
  id: id,
  title: '모집 $id',
  leaderUserId: 'leader',
  metadata: const RecruitmentMetadata(
    catalogVersion: 'v1',
    raidId: 'raid',
    difficultyId: 'normal',
    raidName: '레이드',
    difficultyName: '노말',
    difficultyAlias: '노말',
    gateCount: 2,
    minItemLevel: 1600,
    minCombatPower: null,
    experienceLevel: null,
    maxPlayHours: null,
  ),
  memberCount: 1,
  maxMemberCount: 8,
  isRecruiting: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 8, 20),
);
