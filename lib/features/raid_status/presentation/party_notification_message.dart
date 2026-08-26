import '../../recruitment_list/domain/entities/party_event.dart';

/// 계약 문구 템플릿. 자유 문구를 저장하지 않고 type + Snapshot으로 만든다.
class PartyNotificationMessage {
  const PartyNotificationMessage._();

  static String format({
    required String type,
    String? characterNameSnapshot,
    String? previousCharacterNameSnapshot,
    String? targetCharacterNameSnapshot,
  }) {
    final known = PartyEventType.tryParse(type);
    final name = _name(characterNameSnapshot) ?? '누군가';
    final previous = _name(previousCharacterNameSnapshot);
    final target =
        _name(targetCharacterNameSnapshot ?? characterNameSnapshot) ?? '누군가';
    return switch (known) {
      PartyEventType.applicationSubmitted => '$name님이 가입을 신청했습니다.',
      PartyEventType.applicationApproved => '가입 신청이 승인되었습니다.',
      PartyEventType.applicationRejected => '가입 신청이 거절되었습니다.',
      PartyEventType.applicationWithdrawn => '$name님이 가입 신청을 철회했습니다.',
      PartyEventType.memberJoined => '$name님이 파티에 참가했습니다.',
      PartyEventType.memberLeft => '$name님이 파티에서 탈퇴했습니다.',
      PartyEventType.memberKicked => '$target님이 파티에서 제외되었습니다.',
      PartyEventType.memberCharacterChanged => previous == null
          ? '참가 캐릭터가 $name(으)로 변경되었습니다.'
          : '$previous님이 참가 캐릭터를 $name(으)로 변경했습니다.',
      PartyEventType.memberMoved => '$target님의 위치가 변경되었습니다.',
      PartyEventType.partyCompleted => '파티 회차가 완료되었습니다.',
      PartyEventType.partyCompletionCancelled =>
        '파티 완료가 취소되었습니다. 기록을 확인해주세요.',
      PartyEventType.partyIncompleteEnded => '파티 회차가 미완료로 종료되었습니다.',
      PartyEventType.partyEnded => '파티 모집이 종료되었습니다.',
      PartyEventType.partyDisbanded => '파티 모집이 해산되었습니다.',
      null => '파티 알림이 도착했습니다.',
    };
  }

  static String routeFor({
    required String type,
    required String recruitmentId,
  }) {
    final known = PartyEventType.tryParse(type);
    return switch (known) {
      PartyEventType.partyDisbanded ||
      PartyEventType.partyEnded ||
      PartyEventType.partyCompleted ||
      PartyEventType.partyCompletionCancelled ||
      PartyEventType.partyIncompleteEnded ||
      null =>
        '/raid-status',
      PartyEventType.applicationSubmitted ||
      PartyEventType.applicationApproved ||
      PartyEventType.applicationRejected ||
      PartyEventType.applicationWithdrawn ||
      PartyEventType.memberJoined ||
      PartyEventType.memberLeft ||
      PartyEventType.memberKicked ||
      PartyEventType.memberCharacterChanged ||
      PartyEventType.memberMoved =>
        '/raid-status/$recruitmentId',
    };
  }

  static String? _name(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
