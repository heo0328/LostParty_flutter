import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/theme/app_theme.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/local_recruitment_card.dart';

void main() {
  testWidgets('shows the public recruitment information hierarchy', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: LocalRecruitmentCard(
            recruitment: _summary(),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('4막 하드 모집'), findsOneWidget);
    expect(find.text('모집 중'), findsOneWidget);
    expect(find.text('하드'), findsOneWidget);
    expect(find.text('카제로스 4막 · 1-2관문'), findsOneWidget);
    expect(find.text('시작 시간 미정'), findsOneWidget);
    expect(find.text('멤버 6/8 · 남은 자리 2'), findsOneWidget);
    expect(find.text('최소 전투력 250,000 · 숙련도 클경'), findsOneWidget);

    await tester.tap(find.byType(LocalRecruitmentCard));
    expect(tapped, isTrue);
  });
}

PublicRecruitmentSummary _summary() => PublicRecruitmentSummary(
  id: 'raid-1',
  title: '4막 하드 모집',
  leaderUserId: 'player-1',
  metadata: RecruitmentMetadata(
    catalogVersion: 'v1',
    raidId: 'kazeros-act4',
    difficultyId: 'hard',
    raidName: '카제로스 4막',
    difficultyName: '하드',
    difficultyAlias: '4막하드',
    gateCount: 2,
    minItemLevel: 1700,
    minCombatPower: 250000,
    experienceLevel: ExperienceLevel.clearExp,
    maxPlayHours: null,
  ),
  memberCount: 6,
  maxMemberCount: 8,
  isRecruiting: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 8, 26),
);
