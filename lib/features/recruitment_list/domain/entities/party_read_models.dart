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
    this.status = 'active',
    this.leaderCharacterName,
    this.leaderClassName,
    this.raidStartAt,
  });

  final String id;
  final String title;
  final String leaderPlayerId;
  final String? leaderCharacterName;
  final String? leaderClassName;
  final RecruitmentMetadata metadata;
  final String currentCycleKey;
  final int memberCount;
  final int maxMemberCount;
  final int revision;
  final DateTime updatedAt;
  final bool isOwnedByCurrentPlayer;
  /// Firestore `status`. 1회성 완료 후 해산 전은 `completed`로 진행 중에 남긴다.
  final String status;
  final DateTime? raidStartAt;

  bool get isAwaitingDisband => status == 'completed';
}

/// 공개 상세·확정 멤버 상세에 공통으로 쓰는 파티 표시 전용 모델.
/// PlayerId·권한 플래그는 presentation에 노출하지 않는다.
class PartyMemberDisplay {
  const PartyMemberDisplay({
    required this.playerId,
    required this.characterName,
    required this.className,
    required this.role,
    required this.partyIndex,
    this.characterId,
    this.slotIndex,
    this.itemLevel,
    this.combatPower,
  });

  /// 명령 대상용. UI 문구에는 노출하지 않는다.
  final String playerId;
  /// 캐릭터 변경 후보 필터용. UI 문구에는 노출하지 않는다.
  final String? characterId;
  final String? characterName;
  final String? className;
  final PartyRole role;
  final int partyIndex;
  final int? slotIndex;
  final double? itemLevel;
  final double? combatPower;

  int compareByPartySlot(PartyMemberDisplay other) {
    final byParty = partyIndex.compareTo(other.partyIndex);
    if (byParty != 0) return byParty;
    final leftSlot = slotIndex;
    final rightSlot = other.slotIndex;
    if (leftSlot != null && rightSlot != null) {
      final bySlot = leftSlot.compareTo(rightSlot);
      if (bySlot != 0) return bySlot;
    } else if (leftSlot != null) {
      return -1;
    } else if (rightSlot != null) {
      return 1;
    }
    return (characterName ?? '').compareTo(other.characterName ?? '');
  }
}

class PartySlotCell {
  const PartySlotCell({
    required this.partyIndex,
    required this.slotIndex,
    this.member,
  });

  final int partyIndex;
  final int slotIndex;
  final PartyMemberDisplay? member;

  bool get isOccupied => member != null;
  bool get isLeaderSeat => partyIndex == 0 && slotIndex == 0;
}

class PartySlotBoard {
  const PartySlotBoard({
    required this.partyCount,
    required this.membersPerParty,
    required this.cells,
    required this.unassignedMembers,
  });

  final int partyCount;
  final int membersPerParty;
  final List<PartySlotCell> cells;
  final List<PartyMemberDisplay> unassignedMembers;

  factory PartySlotBoard.fromMembers({
    required List<PartyMemberDisplay> members,
    required int membersPerParty,
    required int maxMemberCount,
  }) {
    final perParty = membersPerParty > 0 ? membersPerParty : 4;
    final rawPartyCount = maxMemberCount > 0
        ? (maxMemberCount / perParty).ceil()
        : 1;
    final partyCount = rawPartyCount < 1 ? 1 : rawPartyCount;
    final occupied = <String, PartyMemberDisplay>{};
    final unassigned = <PartyMemberDisplay>[];
    for (final member in members) {
      final slotIndex = member.slotIndex;
      if (slotIndex == null ||
          member.partyIndex < 0 ||
          member.partyIndex >= partyCount ||
          slotIndex < 0 ||
          slotIndex >= perParty) {
        unassigned.add(member);
        continue;
      }
      final key = '${member.partyIndex}:$slotIndex';
      if (occupied.containsKey(key)) {
        unassigned.add(member);
        continue;
      }
      occupied[key] = member;
    }
    return PartySlotBoard(
      partyCount: partyCount,
      membersPerParty: perParty,
      cells: [
        for (var partyIndex = 0; partyIndex < partyCount; partyIndex++)
          for (var slotIndex = 0; slotIndex < perParty; slotIndex++)
            PartySlotCell(
              partyIndex: partyIndex,
              slotIndex: slotIndex,
              member: occupied['$partyIndex:$slotIndex'],
            ),
      ],
      unassignedMembers: unassigned,
    );
  }

  List<PartySlotCell> cellsForParty(int partyIndex) => [
    for (final cell in cells)
      if (cell.partyIndex == partyIndex) cell,
  ];
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
    this.rejectionCount = 0,
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
  final int rejectionCount;
  final String? resolutionReason;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final DateTime updatedAt;
}

/// 상세의 완료 취소 등에 쓰는 회차 Snapshot. 민감 ID를 UI에 노출하지 않는다.
class PartyCycleSnapshot {
  const PartyCycleSnapshot({
    required this.cycleKey,
    required this.status,
    required this.completionRevision,
  });

  final String cycleKey;
  final String status;
  final int completionRevision;

  bool get isCompleted => status == 'completed';
  bool get isCompletionCancelled => status == 'completionCancelled';
}
