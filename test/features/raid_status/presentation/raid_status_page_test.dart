import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/raid_status/presentation/pages/raid_status_page.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_read_repository.dart';

import '../../../support/party_read_fakes.dart';

void main() {
  Future<FakePartyEventSyncService> pumpPage(
    WidgetTester tester, {
    Stream<PartyReadSnapshot<ActiveRaidSummary>>? activeRaids,
  }) async {
    final database = AccountDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final syncService = FakePartyEventSyncService();

    await tester.pumpWidget(
      MaterialApp(
        home: RaidStatusPage(
          partyReadRepository: FakePartyReadRepository(
            activeRaids: activeRaids,
          ),
          accountDatabase: database,
          eventSyncService: syncService,
          playerId: 'player-1',
          cycleKey: '2026-08-19',
        ),
      ),
    );
    return syncService;
  }

  testWidgets('첫 snapshot 전에는 로딩을 표시한다', (tester) async {
    final pending = StreamController<PartyReadSnapshot<ActiveRaidSummary>>();
    addTearDown(pending.close);

    await pumpPage(tester, activeRaids: pending.stream);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('진행 중인 레이드가 없습니다.'), findsNothing);
  });

  testWidgets('빈 목록은 빈 상태로 표시한다', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('진행 중인 레이드가 없습니다.'), findsOneWidget);
    expect(find.text('오프라인 상태입니다. 마지막으로 받은 내용을 표시합니다.'), findsNothing);
  });

  testWidgets('진행 중인 파티를 목록으로 표시한다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.value(
        PartyReadSnapshot(items: [_activeRaid()], isFromCache: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.textContaining('4막 - 노말'), findsOneWidget);
    expect(find.text('내가 만든 방'), findsOneWidget);
    expect(find.text('진행 중인 레이드가 없습니다.'), findsNothing);
  });

  testWidgets('캐시 snapshot이면 오프라인 안내를 함께 표시한다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.value(
        PartyReadSnapshot(items: [_activeRaid()], isFromCache: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오프라인 상태입니다. 마지막으로 받은 내용을 표시합니다.'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsOneWidget);
  });

  testWidgets('목록 없이 발생한 오류는 실패 안내로 표시한다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.error(
        const PartyReadException(PartyReadFailureType.permissionDenied),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('조회 권한을 확인하지 못했습니다.'), findsOneWidget);
    expect(find.text('진행 중인 레이드가 없습니다.'), findsNothing);
  });

  testWidgets('진입 시 이벤트 동기화를 실행하고 완료 기록 빈 상태를 표시한다', (tester) async {
    final syncService = await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(syncService.syncCount, 1);

    await tester.tap(find.byKey(const ValueKey('raidHistoryTab')));
    await tester.pumpAndSettle();

    expect(find.text('완료 기록이 없습니다.'), findsOneWidget);
  });
}

ActiveRaidSummary _activeRaid() => ActiveRaidSummary(
  id: 'recruitment-1',
  title: '4막 노말 모집',
  leaderPlayerId: 'player-1',
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
  currentCycleKey: '2026-08-19',
  memberCount: 2,
  maxMemberCount: 8,
  revision: 1,
  updatedAt: DateTime.utc(2026, 8, 20),
  isOwnedByCurrentPlayer: true,
);
