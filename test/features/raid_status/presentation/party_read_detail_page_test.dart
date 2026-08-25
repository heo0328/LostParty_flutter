import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/presentation/pages/party_read_detail_page.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_read_repository.dart';

import '../../../support/party_read_fakes.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>>
    recruitment,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PartyReadDetailPage(
          recruitmentId: 'recruitment-1',
          partyReadRepository: FakePartyReadRepository(
            recruitment: recruitment,
          ),
        ),
      ),
    );
  }

  testWidgets('첫 snapshot 전에는 로딩을 표시한다', (tester) async {
    final pending =
        StreamController<PartyReadDetailSnapshot<PublicRecruitmentSummary>>();
    addTearDown(pending.close);

    await pumpPage(tester, recruitment: pending.stream);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('모집 정보를 찾을 수 없습니다.'), findsNothing);
  });

  testWidgets('문서가 없으면 누락 안내를 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        const PartyReadDetailSnapshot(item: null, isFromCache: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('모집 정보를 찾을 수 없습니다.'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsNothing);
  });

  testWidgets('읽기 전용 상세를 표시하고 쓰기 안내를 둔다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.textContaining('4막 - 노말'), findsOneWidget);
    expect(find.textContaining('2/8명'), findsOneWidget);
    expect(find.textContaining('조회 전용'), findsOneWidget);
    expect(find.text('모집 수정'), findsNothing);
  });

  testWidgets('캐시 snapshot이면 오프라인 안내를 함께 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오프라인 상태입니다. 마지막으로 받은 내용을 표시합니다.'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsOneWidget);
  });

  testWidgets('목록 없이 발생한 오류는 실패 안내로 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.error(
        const PartyReadException(PartyReadFailureType.permissionDenied),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('조회 권한을 확인하지 못했습니다.'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsNothing);
  });
}

PublicRecruitmentSummary _summary() => PublicRecruitmentSummary(
  id: 'recruitment-1',
  title: '4막 노말 모집',
  leaderUserId: 'player-1',
  metadata: const RecruitmentMetadata(
    catalogVersion: '2026-08-01',
    raidId: 'act4',
    difficultyId: 'normal',
    raidName: '4막',
    difficultyName: '노말',
    difficultyAlias: '노말',
    gateCount: 2,
    minItemLevel: 1680,
    minCombatPower: null,
    experienceLevel: null,
    maxPlayHours: null,
  ),
  memberCount: 2,
  maxMemberCount: 8,
  isRecruiting: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 8, 20),
);
