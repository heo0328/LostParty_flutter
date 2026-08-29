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
      return 'authBindings에서 PlayerId를 찾을 수 없습니다.';
    }
    if (!bindingActive) {
      return 'authBindings/$authUid status가 active가 아닙니다.';
    }
    if (!playerExists) {
      return 'players/$playerId 문서가 없습니다. Firebase Console에서 생성해 주세요.';
    }
    if (!playerActive) {
      return 'players/$playerId status가 active가 아닙니다.';
    }
    if (!assignmentActive) {
      return 'operatorAssignments/$playerId status가 active가 아닙니다.';
    }
    return null;
  }

  List<String> get summaryLines => [
    'Auth ${authUid ?? '-'}',
    'Player ${playerId ?? '-'}',
    'binding ${bindingActive ? 'active' : 'blocked'}',
    'players ${playerExists ? (playerActive ? 'active' : 'inactive') : 'missing'}',
    'operatorAssignments ${assignmentActive ? 'active' : 'inactive'}',
  ];

  String get diagnosticSummary {
    final issueLine = issue;
    return [
      ...summaryLines,
      if (issueLine != null) '원인: $issueLine' else '클라이언트 기준 운영자 쓰기 준비 OK',
    ].join('\n');
  }
}
