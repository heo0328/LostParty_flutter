import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/state/recruitment_state_machine.dart';

void main() {
  const machine = RecruitmentStateMachine();

  test('신청을 pending 상태로 한 번만 등록한다', () {
    final initial = _state();
    final first = machine.apply(state: initial, application: _application());
    final duplicate = machine.apply(
      state: first.state,
      application: _application(characterId: 'another'),
    );

    expect(first.isSuccess, isTrue);
    expect(
      first.state.applications['applicant']!.status,
      RecruitmentApplicationStatus.pending,
    );
    expect(duplicate.failure, RecruitmentCommandFailure.duplicateApplication);
    expect(identical(duplicate.state, first.state), isTrue);
  });

  test('승인 없는 정책은 신청과 동시에 파티원으로 가입시킨다', () {
    final result = machine.apply(
      state: _state(approvalPolicy: const ApprovalPolicy.directJoin()),
      application: _application(),
    );

    expect(result.isSuccess, isTrue);
    expect(
      result.state.applications['applicant']!.status,
      RecruitmentApplicationStatus.approved,
    );
    expect(
      result.state.members.map((member) => member.userId),
      contains('applicant'),
    );
  });

  test('현재 파티원과 모집 마감 상태의 신청을 거절한다', () {
    final memberApplication = _application(applicantUserId: 'leader');
    final memberResult = machine.apply(
      state: _state(),
      application: memberApplication,
    );
    final closedResult = machine.apply(
      state: _state(isRecruiting: false),
      application: _application(),
    );

    expect(memberResult.failure, RecruitmentCommandFailure.alreadyMember);
    expect(closedResult.failure, RecruitmentCommandFailure.recruitmentClosed);
  });

  test('새 신청 명령은 pending 상태의 투표 없는 신청만 허용한다', () {
    final result = machine.apply(
      state: _state(),
      application: RecruitmentApplication(
        applicantUserId: 'applicant',
        characterId: 'character',
        className: '발키리',
        requestedRole: PartyRole.dealer,
        status: RecruitmentApplicationStatus.approved,
      ),
    );

    expect(result.failure, RecruitmentCommandFailure.invalidApplication);
  });

  test('신청 시점에 역할 자리와 동일 딜러 직업을 미리 검증한다', () {
    final state = _state(
      members: [
        _member('leader', '바드', PartyRole.support),
        _member('dealer', '발키리', PartyRole.dealer),
      ],
    );
    final support = machine.apply(
      state: state,
      application: _application(role: PartyRole.support, className: '도화가'),
    );
    final duplicateDealer = machine.apply(
      state: state,
      application: _application(className: '발키리'),
    );

    expect(support.failure, RecruitmentCommandFailure.compositionRejected);
    expect(
      support.compositionFailure,
      PartyCompositionFailure.supportSlotsFull,
    );
    expect(
      duplicateDealer.compositionFailure,
      PartyCompositionFailure.duplicateDealerClass,
    );
  });

  test('신청자만 pending 신청을 철회할 수 있다', () {
    final pending = _appliedState(_state());
    final unauthorized = machine.withdraw(
      state: pending,
      applicantUserId: 'applicant',
      actorUserId: 'leader',
    );
    final withdrawn = machine.withdraw(
      state: pending,
      applicantUserId: 'applicant',
      actorUserId: 'applicant',
    );

    expect(unauthorized.failure, RecruitmentCommandFailure.unauthorized);
    expect(withdrawn.isSuccess, isTrue);
    expect(
      withdrawn.state.applications['applicant']!.status,
      RecruitmentApplicationStatus.withdrawn,
    );
  });

  test('종료된 신청은 다른 캐릭터로 다시 신청할 수 있다', () {
    final state = _state().copyWith(
      applications: {
        'applicant': _application().copyWith(
          status: RecruitmentApplicationStatus.superseded,
        ),
      },
    );

    final reapplied = machine.apply(
      state: state,
      application: _application(
        characterId: 'other-character',
        className: '소서리스',
      ),
    );

    expect(reapplied.isSuccess, isTrue);
    expect(
      reapplied.state.applications['applicant']!.characterId,
      'other-character',
    );
    expect(
      reapplied.state.applications['applicant']!.status,
      RecruitmentApplicationStatus.pending,
    );
  });

  test('파티 자리가 허용하면 캐릭터 변경과 함께 역할도 변경한다', () {
    final state = _state(
      members: [
        _member('leader', '블레이드', PartyRole.dealer),
        _member('dealer', '소서리스', PartyRole.dealer),
      ],
    );

    final changed = machine.changeCharacter(
      state: state,
      actorUserId: 'leader',
      characterId: 'support-character',
      className: '바드',
      role: PartyRole.support,
    );

    expect(changed.isSuccess, isTrue);
    expect(changed.state.members.first.role, PartyRole.support);
    expect(changed.state.members.first.characterId, 'support-character');
  });

  test('같은 캐릭터도 저장된 반대 역할로 바로 변경할 수 있다', () {
    final state = _state(
      members: [
        _member('leader', '바드', PartyRole.support),
        _member('dealer', '소서리스', PartyRole.dealer),
      ],
    );

    final changed = machine.changeCharacter(
      state: state,
      actorUserId: 'leader',
      characterId: 'leader-character',
      className: '바드',
      role: PartyRole.dealer,
    );

    expect(changed.isSuccess, isTrue);
    expect(changed.state.members.first.role, PartyRole.dealer);
  });

  test('파티장 전용 정책은 파티장의 승인만 허용하고 즉시 가입시킨다', () {
    final pending = _appliedState(_state());
    final outsiderVote = machine.vote(
      state: pending,
      applicantUserId: 'applicant',
      voterUserId: 'outsider',
      decision: ApplicationVoteDecision.approve,
    );
    final approved = machine.vote(
      state: pending,
      applicantUserId: 'applicant',
      voterUserId: 'leader',
      decision: ApplicationVoteDecision.approve,
    );

    expect(outsiderVote.failure, RecruitmentCommandFailure.unauthorized);
    expect(approved.isSuccess, isTrue);
    expect(
      approved.state.members.map((member) => member.userId),
      contains('applicant'),
    );
    expect(
      approved.state.applications['applicant']!.status,
      RecruitmentApplicationStatus.approved,
    );
  });

  test('파티원 승인 정책은 현재 파티원 한 명의 승인으로 가입시킨다', () {
    final state = _state(
      approvalPolicy: const ApprovalPolicy.anyMember(),
      members: [
        _member('leader', '바드', PartyRole.support),
        _member('member', '블레이드', PartyRole.dealer),
      ],
    );
    final approved = machine.vote(
      state: _appliedState(state),
      applicantUserId: 'applicant',
      voterUserId: 'member',
      decision: ApplicationVoteDecision.approve,
    );

    expect(approved.state.members, hasLength(3));
  });

  test('정족수는 서로 다른 파티원의 지정 인원 동의를 요구한다', () {
    final state = _state(
      approvalPolicy: ApprovalPolicy.quorum(requiredApprovals: 2),
      members: [
        _member('leader', '바드', PartyRole.support),
        _member('member', '블레이드', PartyRole.dealer),
      ],
    );
    final first = machine.vote(
      state: _appliedState(state),
      applicantUserId: 'applicant',
      voterUserId: 'leader',
      decision: ApplicationVoteDecision.approve,
    );
    final duplicate = machine.vote(
      state: first.state,
      applicantUserId: 'applicant',
      voterUserId: 'leader',
      decision: ApplicationVoteDecision.approve,
    );
    final second = machine.vote(
      state: first.state,
      applicantUserId: 'applicant',
      voterUserId: 'member',
      decision: ApplicationVoteDecision.approve,
    );

    expect(first.state.members, hasLength(2));
    expect(duplicate.failure, RecruitmentCommandFailure.duplicateVote);
    expect(second.state.members, hasLength(3));
  });

  test('파티장 동의 필수 정족수는 인원수와 파티장 표를 모두 요구한다', () {
    final state = _state(
      approvalPolicy: ApprovalPolicy.quorum(
        requiredApprovals: 2,
        leaderVoteRequired: true,
      ),
      members: [
        _member('leader', '바드', PartyRole.support),
        _member('m1', '블레이드', PartyRole.dealer),
        _member('m2', '소서리스', PartyRole.dealer),
      ],
    );
    final first = _approve(machine, _appliedState(state), 'm1');
    final second = _approve(machine, first.state, 'm2');
    final leader = _approve(machine, second.state, 'leader');

    expect(second.state.members, hasLength(3));
    expect(leader.state.members, hasLength(4));
  });

  test('정족수 판정에서는 더 이상 파티원이 아닌 사용자의 표를 제외한다', () {
    final state = _state(
      approvalPolicy: ApprovalPolicy.quorum(requiredApprovals: 2),
      members: [
        _member('leader', '바드', PartyRole.support),
        _member('old-member', '블레이드', PartyRole.dealer),
      ],
    );
    final oldVote = _approve(machine, _appliedState(state), 'old-member');
    final changedParty = oldVote.state.copyWith(
      members: [
        _member('leader', '바드', PartyRole.support),
        _member('new-member', '소서리스', PartyRole.dealer),
      ],
    );
    final leaderVote = _approve(machine, changedParty, 'leader');

    expect(leaderVote.state.members, hasLength(2));
    expect(
      leaderVote.state.applications['applicant']!.status,
      RecruitmentApplicationStatus.pending,
    );
  });

  test('권한 있는 한 명의 거절로 신청을 종료하고 재처리를 막는다', () {
    final pending = _appliedState(_state());
    final rejected = machine.vote(
      state: pending,
      applicantUserId: 'applicant',
      voterUserId: 'leader',
      decision: ApplicationVoteDecision.reject,
    );
    final retry = machine.vote(
      state: rejected.state,
      applicantUserId: 'applicant',
      voterUserId: 'leader',
      decision: ApplicationVoteDecision.approve,
    );

    expect(
      rejected.state.applications['applicant']!.status,
      RecruitmentApplicationStatus.rejected,
    );
    expect(retry.failure, RecruitmentCommandFailure.applicationNotPending);
  });

  test('승인 직전 자리가 사라지면 투표와 가입을 모두 반영하지 않는다', () {
    final pending = _appliedState(_state());
    final racedState = pending.copyWith(
      members: [
        _member('leader', '바드', PartyRole.support),
        _member('d1', '블레이드', PartyRole.dealer),
        _member('d2', '소서리스', PartyRole.dealer),
        _member('d3', '데모닉', PartyRole.dealer),
      ],
    );
    final result = machine.vote(
      state: racedState,
      applicantUserId: 'applicant',
      voterUserId: 'leader',
      decision: ApplicationVoteDecision.approve,
    );

    expect(result.failure, RecruitmentCommandFailure.compositionRejected);
    expect(identical(result.state, racedState), isTrue);
    expect(result.state.applications['applicant']!.votes, isEmpty);
  });

  test('마지막 자리 가입은 모집을 닫고 역할별 인원을 함께 갱신한다', () {
    final state = _state(
      members: [
        _member('leader', '바드', PartyRole.support),
        _member('d1', '블레이드', PartyRole.dealer),
        _member('d2', '소서리스', PartyRole.dealer),
      ],
    );
    final result = _approve(machine, _appliedState(state), 'leader');

    expect(result.state.isRecruiting, isFalse);
    expect(result.state.dealerCount, 3);
    expect(result.state.supportCount, 1);
    expect(result.state.members.map((member) => member.partyIndex).toSet(), {
      0,
    });
  });
}

RecruitmentCommandResult _approve(
  RecruitmentStateMachine machine,
  RecruitmentState state,
  String voterUserId,
) => machine.vote(
  state: state,
  applicantUserId: 'applicant',
  voterUserId: voterUserId,
  decision: ApplicationVoteDecision.approve,
);

RecruitmentState _appliedState(RecruitmentState state) =>
    const RecruitmentStateMachine()
        .apply(state: state, application: _application())
        .state;

RecruitmentApplication _application({
  String applicantUserId = 'applicant',
  String characterId = 'character',
  String className = '발키리',
  PartyRole role = PartyRole.dealer,
}) => RecruitmentApplication(
  applicantUserId: applicantUserId,
  characterId: characterId,
  className: className,
  requestedRole: role,
);

RecruitmentState _state({
  ApprovalPolicy approvalPolicy = const ApprovalPolicy.leaderOnly(),
  List<RecruitmentPartyMember>? members,
  bool isRecruiting = true,
}) => RecruitmentState(
  leaderUserId: 'leader',
  approvalPolicy: approvalPolicy,
  compositionPolicy: const PartyCompositionPolicy(
    RecruitmentPartyRules(
      partyCount: 1,
      membersPerParty: 4,
      supportsPerParty: 1,
      maxDealersPerClassPerParty: 1,
    ),
  ),
  members: members ?? [_member('leader', '바드', PartyRole.support)],
  isRecruiting: isRecruiting,
);

RecruitmentPartyMember _member(
  String userId,
  String className,
  PartyRole role,
) => RecruitmentPartyMember(
  userId: userId,
  characterId: '$userId-character',
  className: className,
  role: role,
  partyIndex: 0,
);
