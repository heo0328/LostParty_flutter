class OperatorWriteReadiness {
  const OperatorWriteReadiness({
    required this.authUid,
    required this.playerId,
    required this.bindingActive,
    required this.playerExists,
    required this.playerActive,
    required this.assignmentActive,
  });

  final String? authUid;
  final String? playerId;
  final bool bindingActive;
  final bool playerExists;
  final bool playerActive;
  final bool assignmentActive;

  bool get canWrite =>
      bindingActive && playerExists && playerActive && assignmentActive;

  String? get issue {
    if (authUid == null || authUid!.isEmpty) {
      return '로그인 상태를 확인할 수 없습니다.';
    }
    if (playerId == null || playerId!.isEmpty) {
      return '로그인한 사용자의 연결 정보를 확인할 수 없습니다.';
    }
    if (!bindingActive) {
      return '로그인한 사용자의 연결이 비활성 상태입니다.';
    }
    if (!playerExists) {
      return '사용자 정보를 확인할 수 없습니다. 서버의 사용자 상태를 확인해 주세요.';
    }
    if (!playerActive) {
      return '현재 사용자가 비활성 상태입니다.';
    }
    if (!assignmentActive) {
      return '운영자 권한이 활성화되지 않았습니다.';
    }
    return null;
  }

  List<String> get summaryLines => [
    '로그인 ${authUid ?? '-'}',
    '사용자 ${playerId ?? '-'}',
    '사용자 연결 ${bindingActive ? '활성' : '확인 필요'}',
    '사용자 상태 ${playerExists ? (playerActive ? '활성' : '비활성') : '미확인'}',
    '운영자 권한 ${assignmentActive ? '활성' : '비활성'}',
  ];

  String get diagnosticSummary {
    final issueLine = issue;
    return [
      ...summaryLines,
      if (issueLine != null) '원인: $issueLine' else '클라이언트 기준 운영자 쓰기 준비 OK',
    ].join('\n');
  }
}
