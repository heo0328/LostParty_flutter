import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';

void main() {
  test('파티장 전용 승인은 파티장 한 명의 동의를 요구한다', () {
    const policy = ApprovalPolicy.leaderOnly();

    expect(policy.mode, ApprovalMode.leaderOnly);
    expect(policy.requiredApprovals, 1);
    expect(policy.leaderVoteRequired, isTrue);
  });

  test('파티원 승인은 현재 멤버 한 명의 동의를 요구한다', () {
    const policy = ApprovalPolicy.anyMember();

    expect(policy.mode, ApprovalMode.anyMember);
    expect(policy.requiredApprovals, 1);
    expect(policy.leaderVoteRequired, isFalse);
  });

  test('정족수 승인은 지정한 서로 다른 인원수를 표현한다', () {
    final policy = ApprovalPolicy.quorum(
      requiredApprovals: 3,
      leaderVoteRequired: true,
    );

    expect(policy.mode, ApprovalMode.quorum);
    expect(policy.requiredApprovals, 3);
    expect(policy.leaderVoteRequired, isTrue);
  });

  test('정족수 1명은 파티원 승인과 중복되므로 허용하지 않는다', () {
    expect(
      () => ApprovalPolicy.quorum(requiredApprovals: 1),
      throwsArgumentError,
    );
  });
}
