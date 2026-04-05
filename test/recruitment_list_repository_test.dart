import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/datasources/local_recruitment_list_data_source.dart';
import 'package:lost_party/features/recruitment_list/data/repositories/recruitment_list_repository_impl.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';

void main() {
  late LocalRecruitmentListDataSource dataSource;
  late RecruitmentListRepositoryImpl repository;

  setUp(() {
    dataSource = LocalRecruitmentListDataSource();
    repository = RecruitmentListRepositoryImpl(
      localDataSource: dataSource,
    );
  });

  group('RecruitmentListRepositoryImpl', () {
    test('should return recruitment list from data source', () async {
      final result = await repository.getRecruitments();

      expect(result, isNotEmpty);
      expect(result.length, 6);
      expect(result.first, isA<PartyRecruitment>());
    });

    test('repository result should match data source result', () async {
      final fromDataSource = await dataSource.fetchRecruitments();
      final fromRepository = await repository.getRecruitments();

      expect(fromRepository.length, fromDataSource.length);

      // 첫 번째 데이터 비교
      expect(fromRepository.first.id, fromDataSource.first.id);
      expect(fromRepository.first.title, fromDataSource.first.title);
      expect(
        fromRepository.first.raid.raidId,
        fromDataSource.first.raid.raidId,
      );
    });

    test('should contain various recruitment statuses', () async {
      final result = await repository.getRecruitments();

      final hasRecruiting = result.any(
        (item) => item.recruitmentStatus.status ==
            RecruitmentStatusType.recruiting,
      );

      final hasClosed = result.any(
        (item) =>
            item.recruitmentStatus.status ==
            RecruitmentStatusType.closed,
      );

      final hasCompleted = result.any(
        (item) =>
            item.recruitmentStatus.status ==
            RecruitmentStatusType.completed,
      );

      expect(hasRecruiting, true);
      expect(hasClosed, true);
      expect(hasCompleted, true);
    });

    test('should include null maxPlayHours case', () async {
      final result = await repository.getRecruitments();

      final hasNull = result.any(
        (item) => item.schedule.maxPlayHours == null,
      );

      expect(hasNull, true);
    });
  });
}