import '../../../account/domain/role_summary.dart';

/// Read-only explanation, deliberately outside canonical schedule/CAS data.
class CoordinationWait {
  CoordinationWait.fromJson(Map<String, dynamic> value)
    : status = value['status'] as String,
      missingMembers = value['missing_members'] as int? {
    roleShape(value, 'status missing_members');
    roleCheck(
      {
        'waiting_members',
        'no_earlier_candidate',
        'pending',
        'unavailable',
        'not_applicable',
      }.contains(status),
    );
    roleCheck(
      status == 'waiting_members'
          ? missingMembers != null &&
                missingMembers! >= 1 &&
                missingMembers! <= 8
          : missingMembers == null,
    );
  }
  final String status;
  final int? missingMembers;
  String? get message => switch (status) {
    'waiting_members' => '$missingMembers명 더 모이면 조율합니다.',
    'no_earlier_candidate' => '모두 가능한 더 이른 시간이 없어 기본 출발을 유지합니다.',
    'pending' => '출발 시간 확정을 기다리고 있습니다.',
    'unavailable' => '조율에 필요한 정보를 확인하지 못했습니다.',
    _ => null,
  };
}
