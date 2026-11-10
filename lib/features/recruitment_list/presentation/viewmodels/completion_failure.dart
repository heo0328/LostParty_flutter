import '../../../account/domain/account_read_session.dart';

/// Presentation only. Never decides whether an original command may be retried.
String? completionFailureMessage(String? code, {bool unresolved = false}) {
  if (unresolved) return '결과를 확인하지 못했습니다. 다시 시도해 주세요.';
  return switch (code) {
    'COMMAND_CONTEXT_EXPIRED' ||
    'CONTEXT_EXPIRED' => '확인 시간이 지났습니다. 다시 확인해 주세요.',
    'CYCLE_CHANGED' || 'TARGET_CYCLE_UNAVAILABLE' => '정보가 변경되었습니다. 다시 확인해 주세요.',
    'TARGET_CONTEXT_STALE' || 'REVISION_CONFLICT' => '정보가 변경되었습니다. 다시 확인해 주세요.',
    'TARGET_LEADER_REQUIRED' => '권한이 없습니다.',
    'WEEKLY_PARTICIPANT_REQUIRED' || 'PERMISSION_DENIED' => '권한이 없습니다.',
    'SESSION_EXPIRED' ||
    'SESSION_REVOKED' ||
    'UNAUTHENTICATED' => '다시 로그인해 주세요.',
    'ROUND_NOT_ACTIVE' || 'ROOM_NOT_ACTIVE' => '진행 가능한 대상이 없습니다. 다시 확인해 주세요.',
    'CONTEXT_INVALID' ||
    'INVALID_REQUEST' ||
    'TARGET_SCOPE_MISMATCH' => '정보를 확인하지 못했습니다. 다시 확인해 주세요.',
    'TARGET_CYCLE_NOT_CURRENT' ||
    'PLAY_NOT_STARTED' => '해당 주차 수요일 오전 10시부터 완료 처리할 수 있습니다.',
    'CLIENT_UPGRADE_REQUIRED' => '앱을 업데이트해 주세요.',
    'RECRUITMENT_COMMAND_NOT_READY' ||
    'GROUP_FEATURE_NOT_READY' => '지금은 처리할 수 없습니다. 잠시 후 다시 확인해 주세요.',
    'ROOM_REVIEW_REQUIRED' => '결과를 확인할 수 없습니다.',
    'REQUEST_IN_PROGRESS' => '처리 중입니다. 잠시 후 다시 시도해 주세요.',
    'IDEMPOTENCY_CONFLICT' ||
    'IDEMPOTENCY_EXPIRED' ||
    'REQUEST_REVIEW_REQUIRED' => '결과를 확인할 수 없습니다.',
    'NETWORK_UNAVAILABLE' ||
    'SERVICE_UNAVAILABLE' => '결과를 확인하지 못했습니다. 다시 시도해 주세요.',
    _ => null,
  };
}

/// Only safe, bounded diagnostic fields reach the clipboard or screen.
String completionDiagnostic(String code, AccountReadException? error) {
  final lines = <String>[];
  if (RegExp(r'^[A-Z][A-Z0-9_]{0,79}$').hasMatch(code)) {
    lines.add('오류 코드: $code');
  }
  final status = error?.status;
  if (status != null && status >= 100 && status <= 599) {
    lines.add('HTTP 상태: $status');
  }
  final id = error?.requestId;
  if (id != null &&
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id)) {
    lines.add('요청 식별자: $id');
  }
  return lines.join('\n');
}
