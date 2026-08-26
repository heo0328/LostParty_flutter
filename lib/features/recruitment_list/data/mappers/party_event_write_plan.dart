import '../../domain/entities/party_event.dart';

/// Player Event 문서 ID·payload 작성 경계.
///
/// 완료 계열 ID/필드는 기존 형식과 하위 호환을 유지한다.
/// application revision과 recruitment revision 기준을 섞지 않는다.
class PartyEventWritePlan {
  const PartyEventWritePlan._();

  /// 회차 완료 계열. `recruitmentId + cycleKey + completionRevision + type`
  static String id({
    required String recruitmentId,
    required String cycleKey,
    required int eventRevision,
    required String type,
  }) =>
      '${recruitmentId}_${cycleKey}_${eventRevision}_$type';

  /// 신청 계열. `recruitmentId + applicationPlayerId + applicationRevision + type`
  static String applicationId({
    required String recruitmentId,
    required String applicationPlayerId,
    required int applicationRevision,
    required String type,
  }) =>
      '${recruitmentId}_${applicationPlayerId}_${applicationRevision}_$type';

  /// 멤버십 계열. `recruitmentId + targetPlayerId + recruitmentRevision + type`
  static String membershipId({
    required String recruitmentId,
    required String targetPlayerId,
    required int recruitmentRevision,
    required String type,
  }) =>
      '${recruitmentId}_${targetPlayerId}_${recruitmentRevision}_$type';

  /// 종료·해산. `recruitmentId + cycleKey + recruitmentRevision + type`
  static String lifecycleId({
    required String recruitmentId,
    required String cycleKey,
    required int recruitmentRevision,
    required String type,
  }) =>
      id(
        recruitmentId: recruitmentId,
        cycleKey: cycleKey,
        eventRevision: recruitmentRevision,
        type: type,
      );

  static Map<String, Object?> cycle({
    required String eventId,
    required String type,
    required String playerId,
    required String recruitmentId,
    required String cycleKey,
    required String raidId,
    required String difficultyId,
    required int eventRevision,
    required Map<String, Object?> memberSnapshot,
    required Object serverTimestamp,
    required Object expiresAt,
  }) =>
      {
        'schemaVersion': 1,
        'eventId': eventId,
        'type': type,
        'playerId': playerId,
        'recruitmentId': recruitmentId,
        'cycleKey': cycleKey,
        'raidId': raidId,
        'difficultyId': difficultyId,
        'eventRevision': eventRevision,
        'characterId': memberSnapshot['characterId'],
        'characterNameSnapshot': memberSnapshot['characterNameSnapshot'],
        'classNameSnapshot': memberSnapshot['classNameSnapshot'],
        'role': memberSnapshot['role'],
        'partyIndex': memberSnapshot['partyIndex'],
        'occurredAt': serverTimestamp,
        'expiresAt': expiresAt,
      };

  /// 신청·재신청·철회·승인·거절 투영본.
  static Map<String, Object?> application({
    required String eventId,
    required PartyEventType type,
    required String recipientPlayerId,
    required String recruitmentId,
    required int applicationRevision,
    required String actorPlayerId,
    required String applicantCharacterNameSnapshot,
    required Object serverTimestamp,
    required Object expiresAt,
    String? applicantClassNameSnapshot,
    String? applicantRole,
    String? raidId,
    String? difficultyId,
    int? rejectionCount,
  }) {
    assert(
      type == PartyEventType.applicationSubmitted ||
          type == PartyEventType.applicationApproved ||
          type == PartyEventType.applicationRejected ||
          type == PartyEventType.applicationWithdrawn,
      'application payload requires an application event type',
    );
    return {
      'schemaVersion': 1,
      'eventId': eventId,
      'type': type.wireName,
      'playerId': recipientPlayerId,
      'recruitmentId': recruitmentId,
      'eventRevision': applicationRevision,
      'actorPlayerId': actorPlayerId,
      'characterNameSnapshot': applicantCharacterNameSnapshot,
      'classNameSnapshot': ?applicantClassNameSnapshot,
      'role': ?applicantRole,
      'raidId': ?raidId,
      'difficultyId': ?difficultyId,
      'rejectionCount': ?rejectionCount,
      'occurredAt': serverTimestamp,
      'expiresAt': expiresAt,
    };
  }

  /// 즉시 가입·탈퇴·추방·캐릭터 변경·이동 투영본.
  static Map<String, Object?> membership({
    required String eventId,
    required PartyEventType type,
    required String recipientPlayerId,
    required String recruitmentId,
    required int recruitmentRevision,
    required String actorPlayerId,
    required Object serverTimestamp,
    required Object expiresAt,
    String? targetPlayerId,
    String? characterNameSnapshot,
    String? classNameSnapshot,
    String? role,
    String? previousCharacterNameSnapshot,
    String? targetCharacterNameSnapshot,
    String? raidId,
    String? difficultyId,
    int? partyIndex,
    int? slotIndex,
    int? previousPartyIndex,
    int? previousSlotIndex,
  }) {
    assert(
      type == PartyEventType.memberJoined ||
          type == PartyEventType.memberLeft ||
          type == PartyEventType.memberKicked ||
          type == PartyEventType.memberCharacterChanged ||
          type == PartyEventType.memberMoved,
      'membership payload requires a membership event type',
    );
    return {
      'schemaVersion': 1,
      'eventId': eventId,
      'type': type.wireName,
      'playerId': recipientPlayerId,
      'recruitmentId': recruitmentId,
      'eventRevision': recruitmentRevision,
      'actorPlayerId': actorPlayerId,
      'targetPlayerId': ?targetPlayerId,
      'characterNameSnapshot': ?characterNameSnapshot,
      'classNameSnapshot': ?classNameSnapshot,
      'role': ?role,
      'previousCharacterNameSnapshot': ?previousCharacterNameSnapshot,
      'targetCharacterNameSnapshot': ?targetCharacterNameSnapshot,
      'raidId': ?raidId,
      'difficultyId': ?difficultyId,
      'partyIndex': ?partyIndex,
      'slotIndex': ?slotIndex,
      'previousPartyIndex': ?previousPartyIndex,
      'previousSlotIndex': ?previousSlotIndex,
      'occurredAt': serverTimestamp,
      'expiresAt': expiresAt,
    };
  }

  /// 종료·해산 투영본. 완료 3종은 [cycle]을 사용한다.
  static Map<String, Object?> lifecycle({
    required String eventId,
    required PartyEventType type,
    required String recipientPlayerId,
    required String recruitmentId,
    required String cycleKey,
    required int recruitmentRevision,
    required Object serverTimestamp,
    required Object expiresAt,
    String? actorPlayerId,
    String? raidId,
    String? difficultyId,
    String? characterNameSnapshot,
    String? endReason,
  }) {
    assert(
      type == PartyEventType.partyEnded || type == PartyEventType.partyDisbanded,
      'lifecycle payload requires partyEnded or partyDisbanded',
    );
    return {
      'schemaVersion': 1,
      'eventId': eventId,
      'type': type.wireName,
      'playerId': recipientPlayerId,
      'recruitmentId': recruitmentId,
      'cycleKey': cycleKey,
      'eventRevision': recruitmentRevision,
      'actorPlayerId': ?actorPlayerId,
      'raidId': ?raidId,
      'difficultyId': ?difficultyId,
      'characterNameSnapshot': ?characterNameSnapshot,
      'endReason': ?endReason,
      'occurredAt': serverTimestamp,
      'expiresAt': expiresAt,
    };
  }
}
