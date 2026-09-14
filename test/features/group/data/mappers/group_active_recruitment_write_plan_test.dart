import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/data/mappers/group_active_recruitment_write_plan.dart';

void main() {
  final timestamp = Object();

  test('그룹 모집 생성은 그룹 원본 활성 수를 같은 revision으로 증가시킨다', () {
    final plan = GroupActiveRecruitmentWritePlan.open(
      recruitmentId: 'recruitment-1',
      currentCount: 2,
      groupRevision: 7,
      serverTimestamp: timestamp,
    );

    expect(plan.groupPatch, {
      'activeRecruitmentCount': 3,
      'lastRecruitmentId': 'recruitment-1',
      'revision': 8,
      'updatedAt': timestamp,
    });
  });

  test('그룹 모집 종료·공개 전환은 활성 수를 0 아래로 내리지 않는다', () {
    final plan = GroupActiveRecruitmentWritePlan.close(
      recruitmentId: 'recruitment-1',
      currentCount: 1,
      groupRevision: 7,
      serverTimestamp: timestamp,
    );

    expect(plan.groupPatch['activeRecruitmentCount'], 0);
    expect(
      () => GroupActiveRecruitmentWritePlan.close(
        recruitmentId: 'recruitment-1',
        currentCount: 0,
        groupRevision: 7,
        serverTimestamp: timestamp,
      ),
      throwsArgumentError,
    );
  });

  test('그룹 해산은 활성 모집 수가 정확히 0일 때만 허용한다', () {
    expect(
      () => GroupActiveRecruitmentWritePlan.validateDisband(
        activeRecruitmentCount: 0,
      ),
      returnsNormally,
    );
    expect(
      () => GroupActiveRecruitmentWritePlan.validateDisband(
        activeRecruitmentCount: 1,
      ),
      throwsStateError,
    );
  });
}
