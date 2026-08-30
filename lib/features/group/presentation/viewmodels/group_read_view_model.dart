import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_summary.dart';
import '../../domain/repositories/group_read_repository.dart';

String groupReadFailureMessage(Object error) {
  if (error is! GroupReadException) return '그룹 정보를 불러오지 못했습니다.';
  return switch (error.type) {
    GroupReadFailureType.permissionDenied => '그룹 정보를 볼 권한을 확인하지 못했습니다.',
    GroupReadFailureType.unavailable =>
      '일시적으로 불러올 수 없습니다. 새로고침한 뒤 다시 시도해 주세요.',
    GroupReadFailureType.contract => '그룹 데이터 형식이 올바르지 않습니다.',
    GroupReadFailureType.unknown => '그룹 정보를 불러오지 못했습니다.',
  };
}

/// 계약 §11. 만료 시각이 지난 pending 요청은 쓰기 없이 즉시 `만료`로 표시한다.
String groupRequestStatusLabel(GroupRelation relation, {DateTime? now}) {
  final status = relation.requestStatus;
  if (status == null) return '멤버';
  if (status == GroupRequestStatus.pending &&
      relation.isExpiredAt(now ?? DateTime.now())) {
    return '만료';
  }
  return switch (status) {
    GroupRequestStatus.pending => '대기 중',
    GroupRequestStatus.accepted => '수락됨',
    GroupRequestStatus.rejected => '거절됨',
    GroupRequestStatus.cancelled => '취소됨',
    GroupRequestStatus.expired => '만료',
    GroupRequestStatus.blocked => '가입 불가',
  };
}

bool isActionableGroupInvitation(GroupRelation relation, {DateTime? now}) =>
    relation.relation == GroupRelationKind.invited &&
    relation.requestStatus == GroupRequestStatus.pending &&
    !relation.isExpiredAt(now ?? DateTime.now());

class GroupSearchViewModel {
  const GroupSearchViewModel({required this.readRepository});

  final GroupReadRepository readRepository;

  Future<List<GroupPublicSummary>> search(String query) =>
      readRepository.searchGroups(query: query);
}
