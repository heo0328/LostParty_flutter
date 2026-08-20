import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/datasources/local_recruitment_list_data_source.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/shared/raid_catalog/data/datasources/asset_raid_catalog_data_source.dart';
import 'package:lost_party/shared/raid_catalog/data/repositories/raid_catalog_repository_impl.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/domain/validation/raid_catalog_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalRecruitmentListDataSource dataSource;

  setUp(() {
    dataSource = LocalRecruitmentListDataSource();
  });

  group('LocalRecruitmentListDataSource', () {
    test(
      'fetchRecruitments should return non-empty recruitment list',
      () async {
        final recruitments = await dataSource.fetchRecruitments();

        expect(recruitments, isNotEmpty);
        expect(recruitments.length, 6);
        expect(recruitments.first, isA<PartyRecruitment>());
      },
    );

    test('first recruitment should contain expected mock values', () async {
      final recruitments = await dataSource.fetchRecruitments();
      final first = recruitments.first;

      expect(first.id, 'recruitment_001');
      expect(first.title, '4막 노말 딜러 구해요');
      expect(first.raid.raidId, 'kazeros_act4');
      expect(first.raid.difficultyId, 'normal');
      expect(first.raid.gateProgress.startGate, 1);
      expect(first.raid.gateProgress.endGate, 2);
      expect(first.leader.characterName, '세인트바드');
      expect(first.leader.className, '바드');
      expect(first.leader.role, PartyRole.support);
    });

    test('every mock recruitment references the bundled catalog', () async {
      final catalog = await RaidCatalogRepositoryImpl(
        dataSource: AssetRaidCatalogDataSource(),
      ).loadCatalog();
      final recruitments = await dataSource.fetchRecruitments();
      const validator = RaidCatalogValidator();

      for (final recruitment in recruitments) {
        final raid = recruitment.raid;
        expect(
          validator.validateReference(
            catalog,
            RaidCatalogReference(
              catalogVersion: raid.catalogVersion,
              raidId: raid.raidId,
              difficultyId: raid.difficultyId,
              selectedGates: {
                for (
                  var gate = raid.gateProgress.startGate;
                  gate <= raid.gateProgress.endGate;
                  gate++
                )
                  gate,
              },
            ),
          ),
          isEmpty,
          reason: recruitment.id,
        );
      }
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
        (item) =>
            item.recruitmentStatus.status == RecruitmentStatusType.completed,
      );

      expect(hasClosed, true);
      expect(hasCompleted, true);
    });
  });
}
