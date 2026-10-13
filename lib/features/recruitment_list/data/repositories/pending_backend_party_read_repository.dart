import '../../domain/entities/party_read_models.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/repositories/party_read_repository.dart';

/// No public/private Backend contract yet. Preserve the existing list/filter UI
/// without making Firebase requests or pretending an empty query succeeded.
class PendingBackendPartyReadRepository implements PartyReadRepository {
  static const _error = PartyReadException(PartyReadFailureType.unavailable);
  @override
  Stream<PublicRecruitmentPage> watchPublicRecruitmentFirstPage({
    required String cycleKey,
    required String currentPlayerId,
    int limit = publicRecruitmentPageSize,
  }) => Stream.error(_error);
  @override
  Future<PublicRecruitmentPage> loadPublicRecruitmentNextPage({
    required String cycleKey,
    required String currentPlayerId,
    required PublicRecruitmentPageCursor cursor,
    int limit = publicRecruitmentPageSize,
  }) => Future.error(_error);
  @override
  Stream<PartyReadSnapshot<ActiveRaidSummary>> watchActiveRaids({
    required String playerId,
  }) => Stream.error(_error);
  @override
  Stream<PartyReadSnapshot<PartyApplicationSummary>> watchApplications({
    required String playerId,
    required String cycleKey,
  }) => Stream.error(_error);
  @override
  Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>> watchRecruitment(
    String recruitmentId,
  ) => Stream.error(_error);
  @override
  Stream<PartyReadSnapshot<PartyMemberDisplay>> watchRecruitmentMembers(
    String recruitmentId,
  ) => Stream.error(_error);
  @override
  Stream<PartyReadSnapshot<PartyApplicationSummary>>
  watchRecruitmentApplications(String recruitmentId) => Stream.error(_error);
  @override
  Stream<PartyReadDetailSnapshot<PartyApplicationSummary?>> watchMyApplication({
    required String recruitmentId,
    required String playerId,
  }) => Stream.error(_error);
  @override
  Stream<PartyReadDetailSnapshot<PartyCycleSnapshot?>> watchRecruitmentCycle({
    required String recruitmentId,
    required String cycleKey,
  }) => Stream.error(_error);
}
