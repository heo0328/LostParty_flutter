import 'party_create_command.dart';

class PartyVisibilityCommand {
  const PartyVisibilityCommand({
    required this.recruitmentId,
    required this.visibility,
    required this.expectedRecruitmentRevision,
  });

  final String recruitmentId;
  final String visibility;
  final int expectedRecruitmentRevision;
}

enum PartyVisibilityFailure {
  unauthenticated,
  playerBindingMissing,
  notFound,
  unauthorized,
  recruitmentClosed,
  notGroupLinked,
  notGroupMember,
  nonGroupParticipants,
  pendingNonGroupApplications,
  revisionConflict,
  permissionDenied,
  temporarilyUnavailable,
  invalidRequest,
  unknown,
}

class PartyVisibilityResult {
  const PartyVisibilityResult.success() : failure = null;
  const PartyVisibilityResult.failure(this.failure);

  final PartyVisibilityFailure? failure;
  bool get isSuccess => failure == null;
}

class PartyVisibilityCommandValidator {
  const PartyVisibilityCommandValidator();

  PartyVisibilityFailure? validate(PartyVisibilityCommand command) {
    if (command.recruitmentId.trim().isEmpty ||
        command.expectedRecruitmentRevision < 1) {
      return PartyVisibilityFailure.invalidRequest;
    }
    if (!RecruitmentVisibility.isValid(command.visibility)) {
      return PartyVisibilityFailure.invalidRequest;
    }
    return null;
  }
}

String partyVisibilityFailureMessage(PartyVisibilityFailure failure) =>
    switch (failure) {
      PartyVisibilityFailure.unauthenticated ||
      PartyVisibilityFailure.playerBindingMissing =>
        '계정 연결을 준비하지 못했습니다.',
      PartyVisibilityFailure.notFound => '모집 정보를 찾지 못했습니다.',
      PartyVisibilityFailure.unauthorized => '파티장만 공개 범위를 바꿀 수 있습니다.',
      PartyVisibilityFailure.recruitmentClosed => '이미 종료된 모집입니다.',
      PartyVisibilityFailure.notGroupLinked =>
        '그룹에 연결된 레이드만 공개 범위를 바꿀 수 있습니다.',
      PartyVisibilityFailure.notGroupMember =>
        '그룹 전용으로 바꾸려면 해당 그룹에 남아 있어야 합니다.',
      PartyVisibilityFailure.nonGroupParticipants =>
        '그룹에 없는 참가자가 있습니다. 정리한 뒤 그룹 전용으로 바꿔 주세요.',
      PartyVisibilityFailure.pendingNonGroupApplications =>
        '그룹에 없는 신청자가 대기 중입니다. 거절한 뒤 다시 시도해 주세요.',
      PartyVisibilityFailure.revisionConflict =>
        '모집 상태가 바뀌었습니다. 다시 확인해 주세요.',
      PartyVisibilityFailure.permissionDenied =>
        '공개 범위 변경 권한을 확인하지 못했습니다.',
      PartyVisibilityFailure.temporarilyUnavailable =>
        '네트워크 연결이 불안정합니다.',
      PartyVisibilityFailure.invalidRequest => '요청을 확인하지 못했습니다.',
      PartyVisibilityFailure.unknown => '공개 범위를 바꾸지 못했습니다.',
    };
