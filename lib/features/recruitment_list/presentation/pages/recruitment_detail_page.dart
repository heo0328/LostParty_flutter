import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/entities/recruitment_application.dart';
import '../../domain/policies/approval_policy.dart';
import '../../domain/repositories/recruitment_state_repository.dart';
import '../../domain/services/recruitment_application_candidate_service.dart';
import '../../domain/services/recruitment_command_service.dart';
import '../../domain/state/recruitment_state_machine.dart';

class RecruitmentDetailPage extends StatefulWidget {
  const RecruitmentDetailPage({
    required this.recruitmentId,
    required this.repository,
    required this.commandService,
    required this.candidateService,
    super.key,
  });
  final String recruitmentId;
  final RecruitmentStateRepository repository;
  final RecruitmentCommandService commandService;
  final RecruitmentApplicationCandidateService candidateService;
  @override
  State<RecruitmentDetailPage> createState() => _RecruitmentDetailPageState();
}

class _RecruitmentDetailPageState extends State<RecruitmentDetailPage> {
  late Future<RecruitmentAggregate?> _future = _load();
  bool _submitting = false;
  Future<RecruitmentAggregate?> _load() =>
      widget.repository.getById(widget.recruitmentId);
  void _reload() => setState(() {
    _future = _load();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('모집 상세')),
    body: FutureBuilder<RecruitmentAggregate?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final aggregate = snapshot.data;
        if (aggregate == null) {
          return const Center(child: Text('모집 정보를 찾을 수 없습니다.'));
        }
        final metadata = aggregate.metadata;
        final state = aggregate.state;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              aggregate.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              '${metadata.raidName} - ${metadata.difficultyName} (${metadata.difficultyAlias})',
            ),
            Text(
              '1-${metadata.gateCount}관문 · ${state.members.length}/${state.compositionPolicy.rules.totalMembers}명',
            ),
            const Divider(height: 32),
            Text('모집 조건', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '입장 레벨 ${DisplayNumberFormatter.integer(metadata.minItemLevel)}',
            ),
            Text(
              metadata.minCombatPower == null
                  ? '최소 전투력 제한 없음'
                  : '최소 전투력 ${DisplayNumberFormatter.integer(metadata.minCombatPower!)}',
            ),
            Text(
              metadata.experienceLevel == null
                  ? '클리어 경험 제한 없음'
                  : '숙련도 ${_experience(metadata.experienceLevel!)}',
            ),
            Text(
              '최대 시간 ${metadata.maxPlayHours == null ? '클리어 시까지' : '${metadata.maxPlayHours}시간'}',
            ),
            Text('가입 승인 ${_approval(state.approvalPolicy)}'),
            const Divider(height: 32),
            _pendingApplicationsSection(aggregate),
            if (_shouldShowPendingApplications(aggregate))
              const Divider(height: 32),
            _applicationSection(aggregate),
            const Divider(height: 32),
            Text('파티 구성', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (
              var party = 0;
              party < state.compositionPolicy.rules.partyCount;
              party++
            ) ...[
              Text(
                '${party + 1}파티',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final member in state.members.where(
                (member) => member.partyIndex == party,
              ))
                ListTile(
                  key: ValueKey('partyMember-${member.userId}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    member.role == PartyRole.support
                        ? Icons.health_and_safety
                        : Icons.sports_martial_arts,
                  ),
                  title: Text(member.characterId),
                  subtitle: Text('${member.className} · ${_role(member.role)}'),
                  trailing:
                      member.userId == widget.commandService.currentUserId
                      ? TextButton(
                          key: const ValueKey('openCharacterChangeButton'),
                          onPressed: _submitting
                              ? null
                              : () => _showCandidates(
                                  aggregate,
                                  characterChange: true,
                                ),
                          child: const Text('캐릭터 변경'),
                        )
                      : null,
                ),
              if (!state.members.any((member) => member.partyIndex == party))
                const Text('아직 파티원이 없습니다.'),
            ],
          ],
        );
      },
    ),
  );

  Widget _applicationSection(RecruitmentAggregate aggregate) {
    final userId = widget.commandService.currentUserId;
    if (userId == null) return const Text('로그인 후 신청할 수 있습니다.');
    final application = aggregate.state.applications[userId];
    if (application?.status == RecruitmentApplicationStatus.approved) {
      return const Text(
        '가입이 승인되었습니다. 현재 파티원입니다.',
        key: ValueKey('approvedApplicationStatus'),
      );
    }
    if (aggregate.state.members.any((member) => member.userId == userId)) {
      return const Text('현재 파티원입니다.');
    }
    if (application?.status == RecruitmentApplicationStatus.pending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('가입 승인 대기 중입니다.'),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('withdrawApplicationButton'),
            onPressed: _submitting ? null : _withdraw,
            child: const Text('신청 철회'),
          ),
        ],
      );
    }
    if (application?.status == RecruitmentApplicationStatus.rejected) {
      return const Text(
        '가입 신청이 거절되었습니다.',
        key: ValueKey('rejectedApplicationStatus'),
      );
    }
    if (application?.status == RecruitmentApplicationStatus.superseded) {
      return const Text(
        '같은 캐릭터의 다른 파티 참가가 확정되어 신청이 종료되었습니다.',
        key: ValueKey('supersededApplicationStatus'),
      );
    }
    if (!aggregate.state.isRecruiting) return const Text('모집이 마감되었습니다.');
    return FilledButton(
      key: const ValueKey('openApplicationButton'),
      onPressed: _submitting ? null : () => _showCandidates(aggregate),
      child: const Text('지원하기'),
    );
  }

  bool _shouldShowPendingApplications(RecruitmentAggregate aggregate) {
    final userId = widget.commandService.currentUserId;
    return userId != null &&
        aggregate.state.members.any((member) => member.userId == userId);
  }

  Widget _pendingApplicationsSection(RecruitmentAggregate aggregate) {
    if (!_shouldShowPendingApplications(aggregate)) {
      return const SizedBox.shrink();
    }
    final pending = aggregate.state.applications.values
        .where(
          (application) =>
              application.status == RecruitmentApplicationStatus.pending,
        )
        .toList(growable: false);
    final canVote = _canCurrentUserVote(aggregate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('가입 신청 관리', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          const Text('대기 중인 가입 신청이 없습니다.')
        else
          for (final application in pending)
            Card(
              key: ValueKey(
                'pendingApplication-${application.applicantUserId}',
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      application.characterId,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${application.className} · ${_role(application.requestedRole)}',
                    ),
                    Text(_voteStatus(aggregate, application)),
                    if (canVote) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: ValueKey(
                                'rejectApplication-${application.applicantUserId}',
                              ),
                              onPressed: _submitting
                                  ? null
                                  : () => _vote(
                                      application.applicantUserId,
                                      ApplicationVoteDecision.reject,
                                    ),
                              child: const Text('거절'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              key: ValueKey(
                                'approveApplication-${application.applicantUserId}',
                              ),
                              onPressed: _submitting
                                  ? null
                                  : () => _vote(
                                      application.applicantUserId,
                                      ApplicationVoteDecision.approve,
                                    ),
                              child: const Text('승인'),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('현재 승인 정책에서는 투표 권한이 없습니다.'),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  bool _canCurrentUserVote(RecruitmentAggregate aggregate) {
    final userId = widget.commandService.currentUserId;
    if (userId == null) return false;
    final isMember = aggregate.state.members.any(
      (member) => member.userId == userId,
    );
    if (!isMember) return false;
    return switch (aggregate.state.approvalPolicy.mode) {
      ApprovalMode.leaderOnly => userId == aggregate.state.leaderUserId,
      ApprovalMode.directJoin => false,
      ApprovalMode.anyMember || ApprovalMode.quorum => true,
    };
  }

  String _voteStatus(
    RecruitmentAggregate aggregate,
    RecruitmentApplication application,
  ) {
    final policy = aggregate.state.approvalPolicy;
    return switch (policy.mode) {
      ApprovalMode.leaderOnly => '파티장 승인 대기',
      ApprovalMode.directJoin => '승인 없이 바로 가입',
      ApprovalMode.anyMember =>
        '현재 투표 승인 ${application.approvalCount} · 거절 ${application.rejectionCount}',
      ApprovalMode.quorum =>
        '현재 승인 ${application.approvalCount}/${policy.requiredApprovals} · 거절 ${application.rejectionCount}',
    };
  }

  Future<void> _showCandidates(
    RecruitmentAggregate aggregate, {
    bool characterChange = false,
  }) async {
    final candidates = characterChange
        ? await widget.candidateService.loadForCharacterChange(aggregate)
        : await widget.candidateService.load(aggregate);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  characterChange ? '변경할 캐릭터 선택' : '신청 캐릭터와 역할 선택',
                ),
              ),
              if (aggregate.metadata.experienceLevel != null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('클리어 경험 조건은 신청자가 직접 확인해야 합니다.'),
                ),
              Expanded(
                child: candidates.isEmpty
                    ? const Center(child: Text('저장된 역할 세팅이 없습니다.'))
                    : ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          return ListTile(
                            key: ValueKey(
                              'candidate-${candidate.characterId}-${candidate.role.name}',
                            ),
                            enabled: candidate.canApply,
                            title: Text(candidate.characterId),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${candidate.accountLabel} · ${candidate.className} · ${_role(candidate.role)}',
                                ),
                                if (candidate.participationStatuses.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final status
                                            in candidate.participationStatuses)
                                          _participationStatusChip(status),
                                      ],
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    candidate.canApply
                                        ? '신청 가능'
                                        : candidate.rejectionReasons.join(
                                            ' · ',
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: candidate.canApply
                                ? () async {
                                    Navigator.pop(sheetContext);
                                    final hasPending = candidate
                                        .participationStatuses
                                        .any(
                                          (status) =>
                                              status.type ==
                                                  CandidateParticipationStatusType
                                                      .pendingSameRaid,
                                        );
                                    if (hasPending &&
                                        (characterChange ||
                                            aggregate
                                                    .state
                                                    .approvalPolicy
                                                    .mode ==
                                                ApprovalMode.directJoin)) {
                                      final confirmed = await _confirmPendingCancellation(
                                        candidate,
                                        characterChange: characterChange,
                                      );
                                      if (!confirmed) return;
                                    }
                                    if (characterChange) {
                                      await _changeCharacter(
                                        candidate,
                                        cancelPendingApplications: hasPending,
                                      );
                                    } else {
                                      await _apply(candidate, aggregate);
                                    }
                                  }
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _participationStatusChip(CandidateParticipationStatus status) {
    final color = status.isBlocking
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.tertiary;
    final label = switch (status.type) {
      CandidateParticipationStatusType.pendingSameRaid =>
        '동일 레이드 신청 중 ${status.count}개',
      CandidateParticipationStatusType.activeSameRaid => '동일 레이드 참가 중',
      CandidateParticipationStatusType.overlappingSchedule => '동시간대 다른 파티 참가 중',
      CandidateParticipationStatusType.uncertainSchedule => '참가 일정 확인 필요',
      CandidateParticipationStatusType.weeklyRaidClear => '이번 주 동일 레이드 완료',
    };
    return Chip(
      avatar: Icon(
        status.isBlocking ? Icons.block : Icons.info_outline,
        size: 16,
        color: color,
      ),
      label: Text(label),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<bool> _confirmPendingCancellation(
    RecruitmentApplicationCandidate candidate,
    {bool characterChange = false,}
  ) async {
    final count = candidate.participationStatuses
        .where(
          (status) =>
              status.type == CandidateParticipationStatusType.pendingSameRaid,
        )
        .fold(0, (sum, status) => sum + status.count);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('기존 신청을 취소할까요?'),
            content: Text(
              '${candidate.characterId} 캐릭터의 동일 레이드 신청 $count건이 있습니다. '
              '${characterChange ? '캐릭터를 변경하면' : '바로 참가하면'} 기존 신청이 모두 종료됩니다.',
            ),
            actions: [
              TextButton(
                key: const ValueKey('keepPendingApplicationsButton'),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('돌아가기'),
              ),
              FilledButton(
                key: const ValueKey('cancelPendingAndJoinButton'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  characterChange ? '신청 취소하고 변경' : '신청 취소하고 참가',
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _changeCharacter(
    RecruitmentApplicationCandidate candidate,
    {required bool cancelPendingApplications,}
  ) async {
    setState(() => _submitting = true);
    final result = await widget.commandService.changeCharacter(
      recruitmentId: widget.recruitmentId,
      characterId: candidate.characterId,
      className: candidate.className,
      cancelPendingApplications: cancelPendingApplications,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    _message(
      result.isSuccess
          ? '파티 캐릭터를 변경했습니다.'
          : result.domainFailure ==
                RecruitmentCommandFailure.participationConflict
          ? '다른 확정 참가 또는 겹치는 일정이 있어 변경할 수 없습니다.'
          : '캐릭터 변경 조건을 다시 확인해주세요.',
    );
    _reload();
  }

  Future<void> _apply(
    RecruitmentApplicationCandidate candidate,
    RecruitmentAggregate aggregate,
  ) async {
    setState(() => _submitting = true);
    final result = await widget.commandService.apply(
      recruitmentId: widget.recruitmentId,
      characterId: candidate.characterId,
      className: candidate.className,
      role: candidate.role,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    _message(
      result.isSuccess
          ? aggregate.state.approvalPolicy.mode == ApprovalMode.directJoin
                ? '파티에 참가했습니다.'
                : '가입을 신청했습니다.'
          : result.domainFailure ==
                RecruitmentCommandFailure.participationConflict
          ? '이미 확정된 참가 또는 겹치는 일정이 있어 가입할 수 없습니다.'
          : '신청 조건을 다시 확인해주세요.',
    );
    _reload();
  }

  Future<void> _withdraw() async {
    setState(() => _submitting = true);
    final result = await widget.commandService.withdraw(widget.recruitmentId);
    if (!mounted) return;
    setState(() => _submitting = false);
    _message(result.isSuccess ? '신청을 철회했습니다.' : '신청을 철회하지 못했습니다.');
    _reload();
  }

  Future<void> _vote(
    String applicantUserId,
    ApplicationVoteDecision decision,
  ) async {
    setState(() => _submitting = true);
    final result = await widget.commandService.vote(
      recruitmentId: widget.recruitmentId,
      applicantUserId: applicantUserId,
      decision: decision,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    _message(
      result.isSuccess
          ? decision == ApplicationVoteDecision.approve
                ? result
                              .aggregate!
                              .state
                              .applications[applicantUserId]!
                              .status ==
                          RecruitmentApplicationStatus.approved
                      ? '가입 신청을 승인했습니다.'
                      : '승인 투표를 반영했습니다.'
                : '가입 신청을 거절했습니다.'
          : _voteFailureMessage(result),
    );
    _reload();
  }

  String _voteFailureMessage(LocalRecruitmentResult result) {
    if (result.failure == LocalRecruitmentFailure.revisionConflict) {
      return '다른 변경이 먼저 반영되었습니다. 최신 상태를 다시 확인해주세요.';
    }
    return switch (result.domainFailure) {
      RecruitmentCommandFailure.unauthorized => '승인 또는 거절 권한이 없습니다.',
      RecruitmentCommandFailure.duplicateVote => '이미 이 신청에 투표했습니다.',
      RecruitmentCommandFailure.applicationNotFound => '가입 신청을 찾을 수 없습니다.',
      RecruitmentCommandFailure.applicationNotPending => '이미 처리된 가입 신청입니다.',
      RecruitmentCommandFailure.compositionRejected =>
        '현재 파티 구성 조건으로는 승인할 수 없습니다.',
      RecruitmentCommandFailure.participationConflict =>
        '이미 다른 파티 참가가 확정되었거나 일정이 겹치는 캐릭터입니다.',
      _ => '가입 신청을 처리하지 못했습니다. 다시 확인해주세요.',
    };
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  String _role(PartyRole role) => role == PartyRole.support ? '서포터' : '딜러';
  String _experience(ExperienceLevel value) => switch (value) {
    ExperienceLevel.tryLevel => '트라이',
    ExperienceLevel.clearExp => '클경',
    ExperienceLevel.multiClearExp => '다클경',
    ExperienceLevel.semiExperienced => '반숙',
    ExperienceLevel.experienced => '숙련',
  };
  String _approval(ApprovalPolicy policy) => switch (policy.mode) {
    ApprovalMode.leaderOnly => '파티장 승인',
    ApprovalMode.directJoin => '승인 없이 바로 가입',
    ApprovalMode.anyMember => '파티원 승인',
    ApprovalMode.quorum => '${policy.requiredApprovals}명 이상 동의',
  };
}
