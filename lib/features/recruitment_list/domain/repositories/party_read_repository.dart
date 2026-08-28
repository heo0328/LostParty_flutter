import '../entities/party_read_models.dart';
import '../entities/recruitment_aggregate.dart';

enum PartyReadFailureType { permissionDenied, unavailable, contract, unknown }

class PartyReadException implements Exception {
  const PartyReadException(this.type);

  final PartyReadFailureType type;
}

abstract class PartyReadRepository {
  /// 공개 모집 첫 페이지를 실시간 구독한다. 페이지 크기는 [publicRecruitmentPageSize].
  /// [currentPlayerId]는 책임자·확정 멤버 방을 data 계층에서 제외할 때 쓴다.
  Stream<PublicRecruitmentPage> watchPublicRecruitmentFirstPage({
    required String cycleKey,
    required String currentPlayerId,
    int limit = publicRecruitmentPageSize,
  });

  /// [cursor] 이후 다음 페이지를 일회성 조회한다. 추가 listener를 만들지 않는다.
  Future<PublicRecruitmentPage> loadPublicRecruitmentNextPage({
    required String cycleKey,
    required String currentPlayerId,
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

  /// 모집의 확정 멤버를 실시간 구독한다. PlayerId는 Domain DTO에 담지 않는다.
  Stream<PartyReadSnapshot<PartyMemberDisplay>> watchRecruitmentMembers(
    String recruitmentId,
  );

  /// 모집의 신청 목록을 실시간 구독한다. 리더·멤버 읽기 권한에 의존한다.
  Stream<PartyReadSnapshot<PartyApplicationSummary>> watchRecruitmentApplications(
    String recruitmentId,
  );

  Stream<PartyReadDetailSnapshot<PartyApplicationSummary?>> watchMyApplication({
    required String recruitmentId,
    required String playerId,
  });

  /// 모집의 현재 회차 문서를 구독한다. 문서가 없으면 `item == null`.
  Stream<PartyReadDetailSnapshot<PartyCycleSnapshot?>> watchRecruitmentCycle({
    required String recruitmentId,
    required String cycleKey,
  });
}
