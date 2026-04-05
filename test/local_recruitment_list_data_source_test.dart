import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/datasources/local_recruitment_list_data_source.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';

void main() {
  late LocalRecruitmentListDataSource dataSource;

  setUp(() {
    dataSource = LocalRecruitmentListDataSource();
  });

  group('LocalRecruitmentListDataSource', () {
    test('fetchRecruitments should return non-empty recruitment list', () async {
      final recruitments = await dataSource.fetchRecruitments();

      expect(recruitments, isNotEmpty);
      expect(recruitments.length, 6);
      expect(recruitments.first, isA<PartyRecruitment>());
    });

    test('first recruitment should contain expected mock values', () async {
      final recruitments = await dataSource.fetchRecruitments();
      final first = recruitments.first;

      expect(first.id, 'recruitment_001');
      expect(first.title, '노말 카멘 1-3관 딜러 구해요');
      expect(first.raid.raidId, 'kamen_normal');
      expect(first.raid.gateProgress.startGate, 1);
      expect(first.raid.gateProgress.endGate, 3);
      expect(first.leader.characterName, '세인트바드');
      expect(first.leader.className, '바드');
      expect(first.leader.role, PartyRole.support);
    });

    test('recruitment status values should be mapped correctly', () async {
      final recruitments = await dataSource.fetchRecruitments();
      final first = recruitments.first;

      expect(first.recruitmentStatus.status, RecruitmentStatusType.recruiting);
      expect(first.recruitmentStatus.roles.dealer.currentCount, 4);
      expect(first.recruitmentStatus.roles.dealer.targetCount, 6);
      expect(first.recruitmentStatus.roles.dealer.remainingCount, 2);

      expect(first.recruitmentStatus.roles.support.currentCount, 2);
      expect(first.recruitmentStatus.roles.support.targetCount, 2);
      expect(first.recruitmentStatus.roles.support.remainingCount, 0);
    });

    test('should include a recruitment with null maxPlayHours', () async {
      final recruitments = await dataSource.fetchRecruitments();

      final hasNullMaxPlayHours = recruitments.any(
        (item) => item.schedule.maxPlayHours == null,
      );

      expect(hasNullMaxPlayHours, true);
    });

    test('should include closed and completed statuses', () async {
      final recruitments = await dataSource.fetchRecruitments();

      final hasClosed = recruitments.any(
        (item) => item.recruitmentStatus.status == RecruitmentStatusType.closed,
      );
      final hasCompleted = recruitments.any(
        (item) => item.recruitmentStatus.status == RecruitmentStatusType.completed,
      );

      expect(hasClosed, true);
      expect(hasCompleted, true);
    });
  });
}