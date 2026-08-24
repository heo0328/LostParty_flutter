import '../entities/recruitment_aggregate.dart';
import '../state/recruitment_state_machine.dart';

abstract class RecruitmentStateRepository {
  Future<bool> create(RecruitmentAggregate aggregate);

  Future<RecruitmentAggregate?> getById(String recruitmentId);

  Future<List<PublicRecruitmentSummary>> getPublicRecruitments();

  Future<RecruitmentAggregate?> updateIfRevision({
    required String recruitmentId,
    required int expectedRevision,
    required RecruitmentState nextState,
    required DateTime updatedAt,
  });

  Future<RecruitmentAggregate?> updateAggregateIfRevision({
    required String recruitmentId,
    required int expectedRevision,
    required String title,
    required RecruitmentMetadata metadata,
    required RecruitmentState nextState,
    required DateTime updatedAt,
  });

  Future<bool> deleteIfRevision({
    required String recruitmentId,
    required int expectedRevision,
  });

  Future<int> supersedePendingApplications({
    required String applicantUserId,
    required String characterId,
    required String raidId,
    required String excludingRecruitmentId,
    required DateTime updatedAt,
  });

  Future<int> countPendingApplications({
    required String applicantUserId,
    required String characterId,
    required String raidId,
  });
}
