import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/datasources/local_recruitment_list_data_source.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/recruitment_card.dart';

void main() {
  testWidgets('shows the catalog raid, difficulty and user alias', (
    tester,
  ) async {
    final recruitment =
        (await LocalRecruitmentListDataSource().fetchRecruitments()).first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecruitmentCard(recruitment: recruitment)),
      ),
    );

    expect(find.text('4막 - 노말 (4막노말) · 1-2관문'), findsOneWidget);
    expect(find.text('리더: 세인트바드 (바드)'), findsOneWidget);
    expect(find.text('멤버 6/8'), findsOneWidget);
    expect(find.text('딜러 4/6'), findsOneWidget);
    expect(find.text('서포터 2/2'), findsOneWidget);
    expect(find.text('최소 전투력 250000 / 숙련도 클경 / 최대 시간 3시간'), findsOneWidget);
  });

  testWidgets('shows the unlimited play time as until clear', (tester) async {
    final recruitment = (await LocalRecruitmentListDataSource()
        .fetchRecruitments())[2];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecruitmentCard(recruitment: recruitment)),
      ),
    );

    expect(find.textContaining('숙련도 트라이'), findsOneWidget);
    expect(find.textContaining('최대 시간 클리어 시까지'), findsOneWidget);
  });
}
