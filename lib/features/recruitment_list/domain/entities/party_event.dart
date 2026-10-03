/// 파티 명령 결과로 기록되는 Player Event type.
///
/// Firestore wire 값은 [wireName]과 같다. 알 수 없는 미래 type은
/// [PartyEventType.tryParse]가 null을 반환하며, 완료 히스토리 sync는
/// 이를 전체 실패로 만들지 않고 건너뛴다.
enum PartyEventType {
  applicationSubmitted,
  applicationApproved,
  applicationRejected,
  applicationWithdrawn,
  memberJoined,
  memberLeft,
  memberKicked,
  memberCharacterChanged,
  memberMoved,
  ownershipParticipantRemoved,
  ownershipPeerRemoved,
  ownershipLeaderRemoved,
  partyCompleted,
  partyCompletionCancelled,
  partyIncompleteEnded,
  partyEnded,
  partyDisbanded;

  String get wireName => name;

  /// Drift 완료 기록 Projection 대상 여부.
  bool get isRaidHistoryEvent =>
      this == PartyEventType.partyCompleted ||
      this == PartyEventType.partyCompletionCancelled ||
      this == PartyEventType.partyIncompleteEnded;

  /// 앱 내부 알림 목록 후보. UI 문구는 type별 템플릿으로 만든다.
  bool get isNotificationCandidate => this != PartyEventType.partyEnded;

  /// 레이드 현황 카드와 모집 상세에서 방 단위로 확인하는 이벤트다.
  bool get isRoomAttentionEvent =>
      this == PartyEventType.applicationSubmitted ||
      this == PartyEventType.memberJoined ||
      this == PartyEventType.memberKicked ||
      this == PartyEventType.memberCharacterChanged ||
      this == PartyEventType.memberMoved;

  static PartyEventType? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final type in PartyEventType.values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

/// 현재 Player의 자기 경로에서 읽은 파티 이벤트.
///
/// [playerId]는 수신자(경로 Player)다. AuthUid·자유 문구·FCM 토큰은 담지 않는다.
class PartyEvent {
  const PartyEvent({
    required this.eventId,
    required this.type,
    required this.playerId,
    required this.recruitmentId,
    required this.eventRevision,
    required this.occurredAt,
    required this.expiresAt,
    this.cycleKey,
    this.raidId,
    this.difficultyId,
    this.actorPlayerId,
    this.targetPlayerId,
    this.characterId,
    this.characterNameSnapshot,
    this.classNameSnapshot,
    this.role,
    this.partyIndex,
    this.slotIndex,
    this.actorCharacterNameSnapshot,
    this.targetCharacterNameSnapshot,
    this.previousCharacterNameSnapshot,
    this.knownType,
  });

  final String eventId;
  final String type;
  final PartyEventType? knownType;
  final String playerId;
  final String recruitmentId;
  final int eventRevision;
  final DateTime occurredAt;
  final DateTime expiresAt;
  final String? cycleKey;
  final String? raidId;
  final String? difficultyId;
  final String? actorPlayerId;
  final String? targetPlayerId;
  final String? characterId;
  final String? characterNameSnapshot;
  final String? classNameSnapshot;
  final String? role;
  final int? partyIndex;
  final int? slotIndex;
  final String? actorCharacterNameSnapshot;
  final String? targetCharacterNameSnapshot;
  final String? previousCharacterNameSnapshot;

  bool get isRaidHistoryEvent => knownType?.isRaidHistoryEvent ?? false;
}
