import '../../../group/data/mappers/group_active_recruitment_write_plan.dart';
import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_create_command.dart';

class PartyAtomicVisibilityWritePlan {
  PartyAtomicVisibilityWritePlan({
    required PartyCommandAggregate aggregate,
    required String nextVisibility,
    required int groupActiveRecruitmentCount,
    required int groupRevision,
    required Object serverTimestamp,
  }) : _values = _build(
         aggregate: aggregate,
         nextVisibility: nextVisibility,
         groupActiveRecruitmentCount: groupActiveRecruitmentCount,
         groupRevision: groupRevision,
         serverTimestamp: serverTimestamp,
       );

  final _PartyAtomicVisibilityValues _values;

  Map<String, Object?> get recruitmentPatch => _values.recruitmentPatch;
  Map<String, Object?> get groupPatch => _values.groupPatch;
  Map<String, Object?>? get listingDocument => _values.listingDocument;
  bool get deleteListing => _values.deleteListing;

  static _PartyAtomicVisibilityValues _build({
    required PartyCommandAggregate aggregate,
    required String nextVisibility,
    required int groupActiveRecruitmentCount,
    required int groupRevision,
    required Object serverTimestamp,
  }) {
    if (aggregate.status != PartyRecruitmentStatus.active ||
        aggregate.groupId == null ||
        !RecruitmentVisibility.isValid(nextVisibility) ||
        nextVisibility == aggregate.visibility) {
      throw StateError('현재 모집의 공개 범위를 변경할 수 없습니다.');
    }
    if (nextVisibility == RecruitmentVisibility.group &&
        !aggregate.canBecomeGroupOnly) {
      throw StateError('비그룹 참가자 또는 신청자가 남아 있습니다.');
    }

    final groupPlan = nextVisibility == RecruitmentVisibility.group
        ? GroupActiveRecruitmentWritePlan.open(
            recruitmentId: aggregate.recruitmentId,
            currentCount: groupActiveRecruitmentCount,
            groupRevision: groupRevision,
            serverTimestamp: serverTimestamp,
          )
        : GroupActiveRecruitmentWritePlan.close(
            recruitmentId: aggregate.recruitmentId,
            currentCount: groupActiveRecruitmentCount,
            groupRevision: groupRevision,
            serverTimestamp: serverTimestamp,
          );
    final nextRevision = aggregate.revision + 1;
    final recruitmentPatch = Map<String, Object?>.unmodifiable({
      'visibility': nextVisibility,
      'groupActiveRecruitmentCountAfter':
          groupPlan.groupPatch['activeRecruitmentCount'],
      'revision': nextRevision,
      'updatedAt': serverTimestamp,
    });
    return _PartyAtomicVisibilityValues(
      recruitmentPatch: recruitmentPatch,
      groupPatch: groupPlan.groupPatch,
      listingDocument: nextVisibility == RecruitmentVisibility.group
          ? Map.unmodifiable({
              'recruitmentId': aggregate.recruitmentId,
              'groupId': aggregate.groupId,
              'visibility': RecruitmentVisibility.group,
              'status': aggregate.status.name,
              'sourceRevision': nextRevision,
              'updatedAt': serverTimestamp,
            })
          : null,
      deleteListing: nextVisibility == RecruitmentVisibility.public,
    );
  }
}

class _PartyAtomicVisibilityValues {
  const _PartyAtomicVisibilityValues({
    required this.recruitmentPatch,
    required this.groupPatch,
    required this.listingDocument,
    required this.deleteListing,
  });

  final Map<String, Object?> recruitmentPatch;
  final Map<String, Object?> groupPatch;
  final Map<String, Object?>? listingDocument;
  final bool deleteListing;
}
