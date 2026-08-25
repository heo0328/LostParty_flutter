import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../../shared/formatters/korea_time_formatter.dart';
import '../../../recruitment_list/domain/entities/party_application_command.dart';
import '../../../recruitment_list/domain/entities/party_join_command.dart';
import '../../../recruitment_list/domain/entities/party_read_models.dart';
import '../../../recruitment_list/domain/entities/party_recruitment.dart';
import '../../../recruitment_list/domain/entities/recruitment_aggregate.dart';
import '../../../recruitment_list/domain/entities/recruitment_application.dart';
import '../../../recruitment_list/domain/policies/approval_policy.dart';
import '../../../recruitment_list/domain/repositories/party_application_command_repository.dart';
import '../../../recruitment_list/domain/repositories/party_join_command_repository.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';
import '../../../recruitment_list/domain/services/recruitment_leader_candidate_service.dart';
import '../viewmodels/party_read_detail_view_model.dart';

class PartyReadDetailPage extends StatefulWidget {
  const PartyReadDetailPage({
    required this.recruitmentId,
    required this.partyReadRepository,
    this.applicationCommandRepository,
    this.joinCommandRepository,
    this.candidateService,
    this.playerId,
    super.key,
  });

  final String recruitmentId;
  final PartyReadRepository partyReadRepository;
  final PartyApplicationCommandRepository? applicationCommandRepository;
  final PartyJoinCommandRepository? joinCommandRepository;
  final RecruitmentLeaderCandidateService? candidateService;
  final String? playerId;

  @override
  State<PartyReadDetailPage> createState() => _PartyReadDetailPageState();
}

class _PartyReadDetailPageState extends State<PartyReadDetailPage> {
  late final PartyReadDetailViewModel<PublicRecruitmentSummary> _viewModel;
  StreamSubscription<PartyReadDetailSnapshot<PartyApplicationSummary?>>?
  _myApplicationSubscription;
  StreamSubscription<PartyReadSnapshot<PartyMemberDisplay>>?
  _membersSubscription;
  StreamSubscription<PartyReadSnapshot<PartyApplicationSummary>>?
  _applicationsSubscription;
  PartyApplicationSummary? _myApplication;
  List<PartyMemberDisplay> _members = const [];
  List<PartyApplicationSummary> _applications = const [];
  bool _membersLoading = true;
  bool _applicationsLoading = false;
  PartyReadFailureType? _membersFailure;
  PartyReadFailureType? _applicationsFailure;
  bool _membersFromCache = false;
  bool _myApplicationLoading = false;
  bool _submitting = false;

  bool get _canApplicantAction =>
      widget.candidateService != null &&
      widget.playerId != null &&
      widget.playerId!.isNotEmpty &&
      (widget.applicationCommandRepository != null ||
          widget.joinCommandRepository != null);

  bool get _canManageApplications =>
      widget.joinCommandRepository != null &&
      widget.playerId != null &&
      widget.playerId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _viewModel = PartyReadDetailViewModel<PublicRecruitmentSummary>(
      streamFactory: () =>
          widget.partyReadRepository.watchRecruitment(widget.recruitmentId),
    )..start();
    _membersSubscription = widget.partyReadRepository
        .watchRecruitmentMembers(widget.recruitmentId)
        .listen(_onMembers, onError: _onMembersError);
    if (_canApplicantAction) {
      _myApplicationLoading = true;
      _myApplicationSubscription = widget.partyReadRepository
          .watchMyApplication(
            recruitmentId: widget.recruitmentId,
            playerId: widget.playerId!,
          )
          .listen(_onMyApplication, onError: (_) {
            if (!mounted) return;
            setState(() => _myApplicationLoading = false);
          });
    }
    if (_canManageApplications) {
      _applicationsLoading = true;
      _applicationsSubscription = widget.partyReadRepository
          .watchRecruitmentApplications(widget.recruitmentId)
          .listen(_onApplications, onError: _onApplicationsError);
    }
  }

  @override
  void dispose() {
    _myApplicationSubscription?.cancel();
    _membersSubscription?.cancel();
    _applicationsSubscription?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  void _onMembers(PartyReadSnapshot<PartyMemberDisplay> snapshot) {
    if (!mounted) return;
    setState(() {
      _members = snapshot.items;
      _membersLoading = false;
      _membersFailure = null;
      _membersFromCache = snapshot.isFromCache;
    });
  }

  void _onMembersError(Object error) {
    if (!mounted) return;
    setState(() {
      _membersLoading = false;
      _membersFailure = error is PartyReadException
          ? error.type
          : PartyReadFailureType.unknown;
    });
  }

  void _onApplications(PartyReadSnapshot<PartyApplicationSummary> snapshot) {
    if (!mounted) return;
    setState(() {
      _applications = snapshot.items;
      _applicationsLoading = false;
      _applicationsFailure = null;
    });
  }

  void _onApplicationsError(Object error) {
    if (!mounted) return;
    setState(() {
      _applicationsLoading = false;
      _applicationsFailure = error is PartyReadException
          ? error.type
          : PartyReadFailureType.unknown;
    });
  }

  void _onMyApplication(
    PartyReadDetailSnapshot<PartyApplicationSummary?> snapshot,
  ) {
    if (!mounted) return;
    setState(() {
      _myApplication = snapshot.item;
      _myApplicationLoading = false;
    });
  }

  Future<void> _openApplySheet(PublicRecruitmentSummary summary) async {
    final candidateService = widget.candidateService;
    if (candidateService == null || _submitting) return;
    final isDirectJoin = summary.approvalMode == ApprovalMode.directJoin;
    if (isDirectJoin && widget.joinCommandRepository == null) return;
    if (!isDirectJoin && widget.applicationCommandRepository == null) return;

    final startAt = summary.metadata.raidStartAt ?? DateTime.now();
    final candidates = await candidateService.load(
      RecruitmentLeaderCandidateQuery(
        raidId: summary.metadata.raidId,
        difficultyId: summary.metadata.difficultyId,
        minItemLevel: summary.metadata.minItemLevel,
        startAt: startAt,
        maxPlayHours: summary.metadata.maxPlayHours,
      ),
    );
    if (!mounted) return;

    final eligible = candidates
        .where(
          (candidate) =>
              candidate.canSelect &&
              candidate.serverCharacterId != null &&
              candidate.serverCharacterId!.isNotEmpty,
        )
        .toList(growable: false);
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '신청할 수 있는 인증된 캐릭터가 없습니다. 내 계정에서 정보를 새로고침한 뒤 다시 시도해 주세요.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<_ApplySelection>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ApplyCandidateSheet(
        candidates: eligible,
        isDirectJoin: isDirectJoin,
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _submitting = true);
    if (isDirectJoin) {
      final result = await widget.joinCommandRepository!.joinDirectly(
        PartyDirectJoinCommand(
          recruitmentId: widget.recruitmentId,
          characterId: selected.serverCharacterId,
          role: selected.role,
          cycleKey: summary.currentCycleKey,
          expectedRecruitmentRevision: summary.revision,
          combatPower: selected.combatPower,
        ),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      if (result.isSuccess) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('파티에 참가했습니다.')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_joinFailureMessage(result.failure!))),
      );
      return;
    }

    final result = await widget.applicationCommandRepository!.apply(
      PartyApplyCommand(
        recruitmentId: widget.recruitmentId,
        characterId: selected.serverCharacterId,
        requestedRole: selected.role,
        cycleKey: summary.currentCycleKey,
        combatPower: selected.combatPower,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가입을 신청했습니다.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_applicationFailureMessage(result.failure!))),
    );
  }

  Future<void> _withdraw() async {
    final repository = widget.applicationCommandRepository;
    final application = _myApplication;
    if (repository == null ||
        application == null ||
        application.status != RecruitmentApplicationStatus.pending ||
        _submitting) {
      return;
    }

    setState(() => _submitting = true);
    final result = await repository.withdraw(
      PartyWithdrawApplicationCommand(
        recruitmentId: widget.recruitmentId,
        expectedRevision: application.revision,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신청을 철회했습니다.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_applicationFailureMessage(result.failure!))),
    );
  }

  Future<void> _decideApplication({
    required PublicRecruitmentSummary summary,
    required PartyApplicationSummary application,
    required bool approve,
  }) async {
    final repository = widget.joinCommandRepository;
    if (repository == null || _submitting) return;
    setState(() => _submitting = true);
    final command = PartyDecideApplicationCommand(
      recruitmentId: widget.recruitmentId,
      applicantPlayerId: application.applicantPlayerId,
      expectedApplicationRevision: application.revision,
      expectedRecruitmentRevision: summary.revision,
    );
    final result = approve
        ? await repository.approve(command)
        : await repository.reject(command);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? '가입 신청을 승인했습니다.' : '가입 신청을 거절했습니다.'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_joinFailureMessage(result.failure!))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('모집 상세')),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          final state = _viewModel.state;
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.failure != null && state.item == null) {
            return _MessageView(
              icon: Icons.error_outline,
              title: _failureMessage(state.failure!),
              description: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
            );
          }
          if (state.isMissing) {
            return const _MessageView(
              icon: Icons.search_off_outlined,
              title: '모집 정보를 찾을 수 없습니다.',
              description: '방이 삭제되었거나 조회 권한이 없습니다.',
            );
          }

          final summary = state.item!;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (state.isFromCache)
                const _Notice(
                  icon: Icons.cloud_off_outlined,
                  message: '오프라인 상태입니다. 마지막으로 받은 내용을 표시합니다.',
                ),
              if (state.hasFailureWithItem)
                _Notice(
                  icon: Icons.error_outline,
                  message: _failureMessage(state.failure!),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  summary.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              _DetailLine(
                label: '파티장',
                value: _leaderDetailLabel(summary),
              ),
              _DetailLine(label: '레이드', value: _raidLabel(summary.metadata)),
              _DetailLine(label: '일정', value: _scheduleLabel(summary.metadata)),
              _DetailLine(
                label: '인원',
                value:
                    '${summary.memberCount}/${summary.maxMemberCount}명'
                    '${summary.isRecruiting ? ' · 모집 중' : ' · 모집 마감'}',
              ),
              _DetailLine(
                label: '조건',
                value: _requirementLabel(summary.metadata),
              ),
              _DetailLine(
                label: '가입',
                value: _approvalModeLabel(summary.approvalMode),
              ),
              _PartyCompositionSection(
                members: _members,
                membersPerParty: summary.membersPerParty,
                loading: _membersLoading,
                failure: _membersFailure,
                isFromCache: _membersFromCache,
              ),
              if (_isLeader(summary))
                _PendingApplicationsSection(
                  applications: _applications,
                  loading: _applicationsLoading,
                  failure: _applicationsFailure,
                  submitting: _submitting,
                  canDecide:
                      summary.approvalMode != ApprovalMode.directJoin &&
                      widget.joinCommandRepository != null,
                  onApprove: (application) => _decideApplication(
                    summary: summary,
                    application: application,
                    approve: true,
                  ),
                  onReject: (application) => _decideApplication(
                    summary: summary,
                    application: application,
                    approve: false,
                  ),
                ),
              if (_canApplicantAction && !_isLeader(summary))
                _ApplicationActions(
                  summary: summary,
                  myApplication: _myApplication,
                  loadingApplication: _myApplicationLoading,
                  submitting: _submitting,
                  onApply: () => _openApplySheet(summary),
                  onWithdraw: _withdraw,
                )
              else if (!_canApplicantAction && !_canManageApplications)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Text(
                    '이 화면은 조회 전용입니다. 신청과 수정은 아직 연결되지 않았습니다.',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _isLeader(PublicRecruitmentSummary summary) =>
      widget.playerId != null && widget.playerId == summary.leaderUserId;
}

class _PartyCompositionSection extends StatelessWidget {
  const _PartyCompositionSection({
    required this.members,
    required this.membersPerParty,
    required this.loading,
    required this.failure,
    required this.isFromCache,
  });

  final List<PartyMemberDisplay> members;
  final int membersPerParty;
  final bool loading;
  final PartyReadFailureType? failure;
  final bool isFromCache;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('파티 구성', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (isFromCache)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '오프라인 캐시의 파티원 정보입니다.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (loading)
            const LinearProgressIndicator()
          else if (failure != null && members.isEmpty)
            Text(_failureMessage(failure!))
          else if (members.isEmpty)
            const Text('표시할 파티원이 없습니다.')
          else ...[
            if (failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_failureMessage(failure!)),
              ),
            for (final entry in _groupByParty(members, membersPerParty).entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  '${entry.key}파티',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              for (final member in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(_memberLine(member, membersPerParty)),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PendingApplicationsSection extends StatelessWidget {
  const _PendingApplicationsSection({
    required this.applications,
    required this.loading,
    required this.failure,
    required this.submitting,
    required this.canDecide,
    required this.onApprove,
    required this.onReject,
  });

  final List<PartyApplicationSummary> applications;
  final bool loading;
  final PartyReadFailureType? failure;
  final bool submitting;
  final bool canDecide;
  final ValueChanged<PartyApplicationSummary> onApprove;
  final ValueChanged<PartyApplicationSummary> onReject;

  @override
  Widget build(BuildContext context) {
    final pending = applications
        .where((item) => item.status == RecruitmentApplicationStatus.pending)
        .toList(growable: false);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('가입 신청 관리', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (loading)
            const LinearProgressIndicator()
          else if (failure != null && pending.isEmpty)
            Text(_failureMessage(failure!))
          else if (pending.isEmpty)
            const Text('대기 중인 가입 신청이 없습니다.')
          else ...[
            if (failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_failureMessage(failure!)),
              ),
            for (final application in pending)
              Card(
                key: ValueKey(
                  'pendingApplication-${application.applicantPlayerId}',
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${application.characterName} · ${application.className} · '
                        '${_roleLabel(application.requestedRole)}',
                      ),
                      const SizedBox(height: 4),
                      const Text('파티장 승인 대기'),
                      if (canDecide) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: ValueKey(
                                  'rejectApplication-${application.applicantPlayerId}',
                                ),
                                onPressed: submitting
                                    ? null
                                    : () => onReject(application),
                                child: const Text('거절'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                key: ValueKey(
                                  'approveApplication-${application.applicantPlayerId}',
                                ),
                                onPressed: submitting
                                    ? null
                                    : () => onApprove(application),
                                child: const Text('승인'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ApplicationActions extends StatelessWidget {
  const _ApplicationActions({
    required this.summary,
    required this.myApplication,
    required this.loadingApplication,
    required this.submitting,
    required this.onApply,
    required this.onWithdraw,
  });

  final PublicRecruitmentSummary summary;
  final PartyApplicationSummary? myApplication;
  final bool loadingApplication;
  final bool submitting;
  final VoidCallback onApply;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final application = myApplication;
    final isDirectJoin = summary.approvalMode == ApprovalMode.directJoin;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isDirectJoin ? '참가' : '신청',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (loadingApplication)
            const LinearProgressIndicator()
          else if (application?.status == RecruitmentApplicationStatus.pending) ...[
            Text(
              '${application!.characterName} · ${_roleLabel(application.requestedRole)} 승인 대기',
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('withdrawApplicationButton'),
              onPressed: submitting ? null : onWithdraw,
              child: Text(submitting ? '처리 중...' : '신청 철회'),
            ),
          ] else if (application != null) ...[
            Text(_applicationStatusLabel(application)),
            const SizedBox(height: 8),
            const Text('같은 방에 다시 신청하는 기능은 아직 연결되지 않았습니다.'),
          ] else if (!summary.isRecruiting)
            const Text('현재 모집이 마감되어 신청할 수 없습니다.')
          else
            FilledButton(
              key: const ValueKey('openApplicationButton'),
              onPressed: submitting ? null : onApply,
              child: Text(
                submitting
                    ? '처리 중...'
                    : (isDirectJoin ? '바로 가입' : '지원하기'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ApplySelection {
  const _ApplySelection({
    required this.serverCharacterId,
    required this.role,
    this.combatPower,
  });

  final String serverCharacterId;
  final PartyRole role;
  final double? combatPower;
}

class _ApplyCandidateSheet extends StatelessWidget {
  const _ApplyCandidateSheet({
    required this.candidates,
    required this.isDirectJoin,
  });

  final List<RecruitmentLeaderCandidate> candidates;
  final bool isDirectJoin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(isDirectJoin ? '참가할 캐릭터' : '신청할 캐릭터')),
          for (final candidate in candidates)
            for (final option in candidate.roles.where((role) => role.canSelect))
              ListTile(
                key: ValueKey(
                  'apply-candidate-${candidate.localCharacterId}-${option.role.name}',
                ),
                title: Text(candidate.characterId),
                subtitle: Text(
                  '${candidate.accountLabel} · ${candidate.className} · '
                  '${_roleLabel(option.role)} · 아이템 Lv. '
                  '${DisplayNumberFormatter.integer(option.itemLevel ?? 0)}',
                ),
                onTap: () => Navigator.pop(
                  context,
                  _ApplySelection(
                    serverCharacterId: candidate.serverCharacterId!,
                    role: option.role,
                    combatPower: option.combatPower,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _failureMessage(PartyReadFailureType failure) => switch (failure) {
  PartyReadFailureType.permissionDenied => '조회 권한을 확인하지 못했습니다.',
  PartyReadFailureType.unavailable => '네트워크 연결이 불안정합니다.',
  PartyReadFailureType.contract => '데이터 형식을 확인하지 못했습니다.',
  PartyReadFailureType.unknown => '모집을 불러오지 못했습니다.',
};

String _applicationFailureMessage(PartyApplicationFailure failure) =>
    switch (failure) {
      PartyApplicationFailure.unauthenticated ||
      PartyApplicationFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
      PartyApplicationFailure.notFound => '모집 또는 신청 정보를 찾지 못했습니다.',
      PartyApplicationFailure.ownershipLost => '캐릭터 소유권을 확인하지 못했습니다.',
      PartyApplicationFailure.invalidCharacter =>
        '참가할 수 없는 캐릭터입니다. 내 계정에서 정보를 새로고침한 뒤 다시 시도해 주세요.',
      PartyApplicationFailure.recruitmentClosed => '모집이 마감되어 신청할 수 없습니다.',
      PartyApplicationFailure.approvalModeMismatch => '이 방은 신청 방식이 다릅니다.',
      PartyApplicationFailure.capacityFull => '모집 정원이 가득 찼습니다.',
      PartyApplicationFailure.alreadyMember => '이미 이 방의 멤버입니다.',
      PartyApplicationFailure.applicationAlreadyExists => '이미 이 방에 신청했습니다.',
      PartyApplicationFailure.applicationNotPending => '철회할 수 있는 신청이 아닙니다.',
      PartyApplicationFailure.revisionConflict =>
        '신청 상태가 바뀌었습니다. 다시 확인해 주세요.',
      PartyApplicationFailure.permissionDenied => '신청 권한을 확인하지 못했습니다.',
      PartyApplicationFailure.temporarilyUnavailable => '네트워크 연결이 불안정합니다.',
      PartyApplicationFailure.invalidRequest => '신청 정보를 확인하지 못했습니다.',
      PartyApplicationFailure.unknown => '신청을 처리하지 못했습니다.',
    };

String _joinFailureMessage(PartyJoinFailure failure) => switch (failure) {
  PartyJoinFailure.unauthenticated ||
  PartyJoinFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
  PartyJoinFailure.notFound => '모집 또는 신청 정보를 찾지 못했습니다.',
  PartyJoinFailure.unauthorized => '승인 또는 거절 권한이 없습니다.',
  PartyJoinFailure.ownershipLost => '캐릭터 소유권을 확인하지 못했습니다.',
  PartyJoinFailure.invalidCharacter =>
    '참가할 수 없는 캐릭터입니다. 내 계정에서 정보를 새로고침한 뒤 다시 시도해 주세요.',
  PartyJoinFailure.recruitmentClosed => '모집이 마감되어 참가할 수 없습니다.',
  PartyJoinFailure.approvalModeMismatch => '이 방은 가입 방식이 다릅니다.',
  PartyJoinFailure.capacityFull ||
  PartyJoinFailure.roleCapacityFull => '모집 정원이 가득 찼습니다.',
  PartyJoinFailure.duplicateDealerClass => '같은 파티에 동일 직업 딜러가 이미 있습니다.',
  PartyJoinFailure.alreadyMember => '이미 이 방의 멤버입니다.',
  PartyJoinFailure.applicationNotPending => '처리할 수 있는 신청이 아닙니다.',
  PartyJoinFailure.participationConflict =>
    '이미 확정된 참가 또는 겹치는 일정이 있어 가입할 수 없습니다.',
  PartyJoinFailure.revisionConflict => '상태가 바뀌었습니다. 다시 확인해 주세요.',
  PartyJoinFailure.permissionDenied => '가입 권한을 확인하지 못했습니다.',
  PartyJoinFailure.temporarilyUnavailable => '네트워크 연결이 불안정합니다.',
  PartyJoinFailure.invalidRequest => '가입 정보를 확인하지 못했습니다.',
  PartyJoinFailure.unknown => '가입을 처리하지 못했습니다.',
};

String _approvalModeLabel(ApprovalMode mode) => switch (mode) {
  ApprovalMode.leaderOnly => '파티장 승인',
  ApprovalMode.directJoin => '승인 없이 바로 가입',
  ApprovalMode.anyMember => '파티원 승인',
  ApprovalMode.quorum => '정족수 승인',
};

String _raidLabel(RecruitmentMetadata metadata) {
  final difficulty = metadata.difficultyAlias == metadata.difficultyName
      ? metadata.difficultyName
      : '${metadata.difficultyName} (${metadata.difficultyAlias})';
  return '${metadata.raidName} - $difficulty · ${metadata.gateCount}관문';
}

String _scheduleLabel(RecruitmentMetadata metadata) {
  final startAt = metadata.raidStartAt;
  return startAt == null ? '시작 시간 미정' : KoreaTimeFormatter.dayAndTime(startAt);
}

String _requirementLabel(RecruitmentMetadata metadata) {
  final parts = [
    '최소 아이템 레벨 ${DisplayNumberFormatter.integer(metadata.minItemLevel)}',
    if (metadata.minCombatPower != null)
      '최소 전투력 ${DisplayNumberFormatter.integer(metadata.minCombatPower!)}',
    if (metadata.experienceLevel != null)
      '숙련도 ${_experienceLabel(metadata.experienceLevel!)}',
  ];
  return parts.join(' · ');
}

String _experienceLabel(ExperienceLevel level) => switch (level) {
  ExperienceLevel.tryLevel => '트라이',
  ExperienceLevel.clearExp => '클경',
  ExperienceLevel.multiClearExp => '다클경',
  ExperienceLevel.semiExperienced => '반숙',
  ExperienceLevel.experienced => '숙련',
};

String _roleLabel(PartyRole role) => switch (role) {
  PartyRole.dealer => '딜러',
  PartyRole.support => '서포터',
};

String _leaderDetailLabel(PublicRecruitmentSummary summary) {
  final name = summary.leaderCharacterName?.trim();
  final className = summary.leaderClassName?.trim();
  if (name == null || name.isEmpty) return '정보 없음';
  if (className == null || className.isEmpty) return name;
  return '$name · $className';
}

String _memberLine(PartyMemberDisplay member, int membersPerParty) {
  final seat = (member.partyIndex % membersPerParty) + 1;
  final parts = <String>[
    '$seat자리',
    member.characterName?.trim().isNotEmpty == true
        ? member.characterName!.trim()
        : '정보 없음',
    member.className?.trim().isNotEmpty == true
        ? member.className!.trim()
        : '정보 없음',
    if (member.combatPower != null)
      '전투력 ${DisplayNumberFormatter.integer(member.combatPower!)}'
    else
      '전투력 정보 없음',
    if (member.itemLevel != null)
      '아이템 Lv. ${DisplayNumberFormatter.integer(member.itemLevel!)}'
    else
      '아이템 레벨 정보 없음',
    _roleLabel(member.role),
  ];
  return parts.join(' · ');
}

Map<int, List<PartyMemberDisplay>> _groupByParty(
  List<PartyMemberDisplay> members,
  int membersPerParty,
) {
  final size = membersPerParty <= 0 ? 4 : membersPerParty;
  final grouped = <int, List<PartyMemberDisplay>>{};
  for (final member in members) {
    final partyNumber = (member.partyIndex ~/ size) + 1;
    grouped.putIfAbsent(partyNumber, () => <PartyMemberDisplay>[]).add(member);
  }
  final keys = grouped.keys.toList()..sort();
  return {for (final key in keys) key: grouped[key]!};
}

String _applicationStatusLabel(PartyApplicationSummary application) =>
    switch (application.status) {
      RecruitmentApplicationStatus.pending => '승인 대기',
      RecruitmentApplicationStatus.approved => '승인됨',
      RecruitmentApplicationStatus.rejected => '거절됨',
      RecruitmentApplicationStatus.withdrawn => '철회함',
      RecruitmentApplicationStatus.superseded => '다른 신청으로 대체됨',
    };
