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
  });
}
