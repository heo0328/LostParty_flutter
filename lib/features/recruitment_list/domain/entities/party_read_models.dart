import 'recruitment_aggregate.dart';
import 'recruitment_application.dart';
import 'party_recruitment.dart';

/// 공개 목록 페이지 크기. Repository·ViewModel이 동일한 값을 사용한다.
const int publicRecruitmentPageSize = 20;

class PartyReadSnapshot<T> {
  const PartyReadSnapshot({required this.items, required this.isFromCache});

  final List<T> items;
  final bool isFromCache;
}

/// Repository가 해석하는 불투명 cursor. Firestore DocumentSnapshot을 Domain에 노출하지 않는다.
abstract class PublicRecruitmentPageCursor {
  const PublicRecruitmentPageCursor();
}

class PublicRecruitmentPage {
  const PublicRecruitmentPage({
    required this.items,
    required this.hasMore,
    required this.isFromCache,
    this.nextCursor,
  });

  final List<PublicRecruitmentSummary> items;
  final PublicRecruitmentPageCursor? nextCursor;
  final bool hasMore;
  final bool isFromCache;
}

/// 문서 누락은 `item == null`로 두고, 캐시 여부는 목록과 같은 계약으로 전달한다.
class PartyReadDetailSnapshot<T> {
  const PartyReadDetailSnapshot({
    required this.item,
    required this.isFromCache,
  });

  final T? item;
  final bool isFromCache;
}

class ActiveRaidSummary {
  const ActiveRaidSummary({
    required this.id,
    required this.title,
    required this.leaderPlayerId,
    required this.metadata,
    required this.currentCycleKey,
    required this.memberCount,
    required this.maxMemberCount,
    required this.revision,
    required this.updatedAt,
    required this.isOwnedByCurrentPlayer,
    this.raidStartAt,
  });

  final String id;
  final String title;
  final String leaderPlayerId;
  final RecruitmentMetadata metadata;
  final String currentCycleKey;
  final int memberCount;
  final int maxMemberCount;
  final int revision;
  final DateTime updatedAt;
  final bool isOwnedByCurrentPlayer;
  final DateTime? raidStartAt;
}

class PartyApplicationSummary {
  const PartyApplicationSummary({
    required this.recruitmentId,
    required this.applicantPlayerId,
    required this.cycleKey,
    required this.characterId,
    required this.characterName,
    required this.className,
    required this.requestedRole,
    required this.status,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.resolutionReason,
    this.decidedAt,
  });

  final String recruitmentId;
  final String applicantPlayerId;
  final String cycleKey;
  final String characterId;
  final String characterName;
  final String className;
  final PartyRole requestedRole;
  final RecruitmentApplicationStatus status;
  final int revision;
  final String? resolutionReason;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final DateTime updatedAt;
}
