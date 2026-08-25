import '../entities/party_read_models.dart';
import '../entities/recruitment_aggregate.dart';

enum PartyReadFailureType { permissionDenied, unavailable, contract, unknown }

class PartyReadException implements Exception {
  const PartyReadException(this.type);

  final PartyReadFailureType type;
}

abstract class PartyReadRepository {
  /// 공개 모집 첫 페이지를 실시간 구독한다. 페이지 크기는 [publicRecruitmentPageSize].
  Stream<PublicRecruitmentPage> watchPublicRecruitmentFirstPage({
    required String cycleKey,
    int limit = publicRecruitmentPageSize,
  });

  /// [cursor] 이후 다음 페이지를 일회성 조회한다. 추가 listener를 만들지 않는다.
  Future<PublicRecruitmentPage> loadPublicRecruitmentNextPage({
    required String cycleKey,
    required PublicRecruitmentPageCursor cursor,
    int limit = publicRecruitmentPageSize,
  });

  Stream<PartyReadSnapshot<ActiveRaidSummary>> watchActiveRaids({
    required String playerId,
  });

  Stream<PartyReadSnapshot<PartyApplicationSummary>> watchApplications({
    required String playerId,
    required String cycleKey,
  });

  Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>> watchRecruitment(
    String recruitmentId,
  );

  Stream<PartyReadDetailSnapshot<PartyApplicationSummary?>> watchMyApplication({
    required String recruitmentId,
    required String playerId,
  });
}
