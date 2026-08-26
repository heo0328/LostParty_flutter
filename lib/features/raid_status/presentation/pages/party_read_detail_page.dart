import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
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
import '../../../recruitment_list/domain/repositories/party_membership_command_repository.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';
import '../../../recruitment_list/domain/entities/party_membership_command.dart';
import '../../../recruitment_list/domain/services/recruitment_leader_candidate_service.dart';
import '../viewmodels/party_read_detail_view_model.dart';

class PartyReadDetailPage extends StatefulWidget {
  const PartyReadDetailPage({
    required this.recruitmentId,
    required this.partyReadRepository,
    this.applicationCommandRepository,
    this.joinCommandRepository,
    this.membershipCommandRepository,
    this.candidateService,
    this.playerId,
    super.key,
  });

  final String recruitmentId;
  final PartyReadRepository partyReadRepository;
  final PartyApplicationCommandRepository? applicationCommandRepository;
  final PartyJoinCommandRepository? joinCommandRepository;
  final PartyMembershipCommandRepository? membershipCommandRepository;
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
    );
    _bindDetailSubscriptions();
  }

  @override
  void didUpdateWidget(covariant PartyReadDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final recruitmentChanged =
        oldWidget.recruitmentId != widget.recruitmentId;
    final playerChanged = oldWidget.playerId != widget.playerId;
    final repositoryChanged =
        oldWidget.partyReadRepository != widget.partyReadRepository;
    if (!recruitmentChanged && !playerChanged && !repositoryChanged) {
      return;
    }
    _bindDetailSubscriptions(restartRecruitment: recruitmentChanged || repositoryChanged);
  }

  void _bindDetailSubscriptions({bool restartRecruitment = false}) {
    _myApplicationSubscription?.cancel();
    _myApplicationSubscription = null;
    _membersSubscription?.cancel();
    _membersSubscription = null;
    _applicationsSubscription?.cancel();
    _applicationsSubscription = null;

    if (restartRecruitment) {
      _viewModel.restart(
        () => widget.partyReadRepository.watchRecruitment(widget.recruitmentId),
      );
    } else {
      _viewModel.start();
    }

    _membersLoading = true;
    _members = const [];
    _membersFailure = null;
    _membersFromCache = false;
    _myApplication = null;
    _myApplicationLoading = false;
    _applications = const [];
    _applicationsLoading = false;
    _applicationsFailure = null;

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
    if (mounted) setState(() {});
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
      final hasVerified = candidates.any(
        (candidate) =>
            candidate.serverCharacterId != null &&
            candidate.serverCharacterId!.isNotEmpty,
      );
      final message = !hasVerified
          ? '서버에 연결된 인증 캐릭터가 없습니다. 설정에서 게임계정 인증을 완료한 뒤 다시 시도해 주세요.'
          : '신청 가능한 역할·조건에 맞는 캐릭터가 없습니다. 캐릭터 역할 세팅과 입장 레벨을 확인해 주세요.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
          cycleKey: summary.targetCycleKey.isNotEmpty
              ? summary.targetCycleKey
              : summary.currentCycleKey,
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
        cycleKey: summary.targetCycleKey.isNotEmpty
            ? summary.targetCycleKey
            : summary.currentCycleKey,
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
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                maxMemberCount: summary.maxMemberCount,
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
              if (_canApplicantAction && !_isLeader(summary) && !_isConfirmedMember)
                _ApplicationActions(
                  summary: summary,
                  myApplication: _myApplication,
                  loadingApplication: _myApplicationLoading,
                  submitting: _submitting,
                  onApply: () => _openApplySheet(summary),
                  onWithdraw: _withdraw,
                )
              else if (!_canApplicantAction &&
                  !_canManageApplications &&
                  !_canUseMembershipCommands)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Text(
                    '이 화면은 조회 전용입니다. 신청과 수정은 아직 연결되지 않았습니다.',
                  ),
                ),
              if (_isConfirmedMember && _canUseMembershipCommands)
                _MembershipSelfActions(
                  canLeave: summary.memberCount > 1,
                  submitting: _submitting,
                  onChangeCharacter: () => _openChangeCharacterSheet(summary),
                  onLeave: () => _confirmLeave(summary),
                ),
              if (_isLeader(summary) &&
                  _canUseMembershipCommands &&
                  summary.memberCount > 1)
                _KickMembersSection(
                  members: _members
                      .where((member) => member.playerId != widget.playerId)
                      .toList(growable: false),
                  submitting: _submitting,
                  onKick: (member) => _confirmKick(summary, member),
                ),
              if (_canDeleteRecruitment(summary))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                  child: OutlinedButton.icon(
                    key: const ValueKey('deleteOwnRecruitmentButton'),
                    onPressed: _submitting
                        ? null
                        : () => _confirmDeleteRecruitment(summary),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('모집 삭제'),
                  ),
                ),
            ],
            ),
          );
        },
      ),
    );
  }

  bool get _canUseMembershipCommands =>
      widget.membershipCommandRepository != null &&
      widget.playerId != null &&
      widget.playerId!.isNotEmpty;

  bool get _isConfirmedMember =>
      widget.playerId != null &&
      _members.any((member) => member.playerId == widget.playerId);

  bool _canDeleteRecruitment(PublicRecruitmentSummary summary) =>
      _isLeader(summary) &&
      _canUseMembershipCommands &&
      summary.memberCount <= 1;

  Future<void> _openChangeCharacterSheet(
    PublicRecruitmentSummary summary,
  ) async {
    final candidateService = widget.candidateService;
    final repository = widget.membershipCommandRepository;
    if (candidateService == null ||
        repository == null ||
        !_isConfirmedMember ||
        _submitting) {
      return;
    }
    final me = _members.firstWhere(
      (member) => member.playerId == widget.playerId,
    );
    final candidates = await candidateService.load(
      RecruitmentLeaderCandidateQuery(
        raidId: summary.metadata.raidId,
        difficultyId: summary.metadata.difficultyId,
        minItemLevel: summary.metadata.minItemLevel,
        startAt: summary.metadata.raidStartAt ?? DateTime.now(),
        maxPlayHours: summary.metadata.maxPlayHours,
      ),
    );
    if (!mounted) return;

    final eligible = <({RecruitmentLeaderCandidate candidate, double? combatPower})>[];
    for (final candidate in candidates) {
      final serverId = candidate.serverCharacterId;
      if (serverId == null || serverId.isEmpty) continue;
      if (me.characterId != null && me.characterId == serverId) continue;
      final option = candidate.optionFor(me.role);
      if (option == null || !option.canSelect) continue;
      if (!candidate.canSelect) continue;
      eligible.add((candidate: candidate, combatPower: option.combatPower));
    }
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '변경할 수 있는 같은 역할의 인증 캐릭터가 없습니다. 역할 세팅과 입장 레벨을 확인해 주세요.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<_ApplySelection>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ChangeCharacterCandidateSheet(
        role: me.role,
        entries: eligible,
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _submitting = true);
    final result = await repository.changeCharacter(
      PartyChangeCharacterCommand(
        recruitmentId: widget.recruitmentId,
        newCharacterId: selected.serverCharacterId,
        expectedRecruitmentRevision: summary.revision,
        combatPower: selected.combatPower,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('참가 캐릭터를 변경했습니다.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_membershipFailureMessage(result.failure!))),
    );
  }

  Future<void> _confirmLeave(PublicRecruitmentSummary summary) async {
    if (!_canUseMembershipCommands ||
        !_isConfirmedMember ||
        summary.memberCount <= 1 ||
        _submitting) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('파티에서 탈퇴할까요?'),
        content: Text(
          _isLeader(summary)
              ? '책임자 권한이 다음 멤버에게 넘어갑니다. 자리는 비워 두고 남은 멤버를 앞으로 당기지 않습니다.'
              : '탈퇴하면 자리가 비워지며 남은 멤버를 앞으로 당기지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmLeavePartyButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final result = await widget.membershipCommandRepository!.leave(
      PartyRemoveMemberCommand(
        recruitmentId: widget.recruitmentId,
        targetPlayerId: widget.playerId!,
        expectedRecruitmentRevision: summary.revision,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('파티에서 탈퇴했습니다.')));
      Navigator.of(context).maybePop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_membershipFailureMessage(result.failure!))),
    );
  }

  Future<void> _confirmKick(
    PublicRecruitmentSummary summary,
    PartyMemberDisplay member,
  ) async {
    if (!_isLeader(summary) ||
        !_canUseMembershipCommands ||
        member.playerId == widget.playerId ||
        _submitting) {
      return;
    }
    final name = member.characterName?.trim().isNotEmpty == true
        ? member.characterName!.trim()
        : '선택한 파티원';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('파티원을 추방할까요?'),
        content: Text(
          '$name 님을 추방합니다. 자리는 비워 두고 남은 멤버를 앞으로 당기지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmKickMemberButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('추방'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final result = await widget.membershipCommandRepository!.kick(
      PartyRemoveMemberCommand(
        recruitmentId: widget.recruitmentId,
        targetPlayerId: member.playerId,
        expectedRecruitmentRevision: summary.revision,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('파티원을 추방했습니다.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_membershipFailureMessage(result.failure!))),
    );
  }

  Future<void> _confirmDeleteRecruitment(
    PublicRecruitmentSummary summary,
  ) async {
    if (!_canDeleteRecruitment(summary) || _submitting) return;
    if (summary.memberCount > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '다른 파티원이 있는 방의 해산은 아직 지원하지 않습니다. 멤버가 나만 있을 때 삭제할 수 있습니다.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('모집을 삭제할까요?'),
        content: const Text(
          '방이 모집 목록에서 사라지고 해산 처리됩니다. 이 동작은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmDeleteOwnRecruitmentButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final result = await widget.membershipCommandRepository!.leave(
      PartyRemoveMemberCommand(
        recruitmentId: widget.recruitmentId,
        targetPlayerId: widget.playerId!,
        expectedRecruitmentRevision: summary.revision,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모집을 삭제했습니다.')));
      Navigator.of(context).maybePop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_membershipFailureMessage(result.failure!))),
    );
  }

  bool _isLeader(PublicRecruitmentSummary summary) =>
      widget.playerId != null && widget.playerId == summary.leaderUserId;
}

class _PartyCompositionSection extends StatelessWidget {
  const _PartyCompositionSection({
    required this.members,
    required this.membersPerParty,
    required this.maxMemberCount,
    required this.loading,
    required this.failure,
    required this.isFromCache,
  });

  /// 파티 그룹 2열 후보 breakpoint. 기기 종류가 아니라 가용 폭만 본다.
  /// 펼친 폴드의 구성판 가용 폭(패딩 제외)이 보통 650~690dp라 720은 미달한다.
  static const double partyGroupBreakpoint = 600;

  final List<PartyMemberDisplay> members;
  final int membersPerParty;
  final int maxMemberCount;
  final bool loading;
  final PartyReadFailureType? failure;
  final bool isFromCache;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final board = PartySlotBoard.fromMembers(
      members: members,
      membersPerParty: membersPerParty,
      maxMemberCount: maxMemberCount,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('파티 구성', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          if (isFromCache)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '오프라인 캐시의 파티원 정보입니다.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (loading)
            const LinearProgressIndicator()
          else if (failure != null && members.isEmpty)
            Text(_failureMessage(failure!))
          else ...[
            if (failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(_failureMessage(failure!)),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final useWidePartyGroups =
                    constraints.maxWidth >= partyGroupBreakpoint;
                final raidLeaderLabel =
                    board.partyCount > 1 ? '공대장' : '파티장';
                return Column(
                  key: const ValueKey('partyCompositionBoard'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (useWidePartyGroups)
                      _WidePartyGroups(
                        board: board,
                        raidLeaderLabel: raidLeaderLabel,
                      )
                    else
                      for (
                        var partyIndex = 0;
                        partyIndex < board.partyCount;
                        partyIndex++
                      )
                        _PartyGroupColumn(
                          key: ValueKey('partyGroup-$partyIndex'),
                          partyIndex: partyIndex,
                          cells: board.cellsForParty(partyIndex),
                          raidLeaderLabel: raidLeaderLabel,
                        ),
                    if (board.unassignedMembers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          bottom: AppSpacing.xxs,
                        ),
                        child: Text(
                          '자리 미정',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      for (final member in board.unassignedMembers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _UnassignedMemberCard(member: member),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 넓은 화면: 파티 제목을 좌우로 두고, 같은 자리(1~4번) Slot Card 높이를 맞춘다.
class _WidePartyGroups extends StatelessWidget {
  const _WidePartyGroups({
    required this.board,
    required this.raidLeaderLabel,
  });

  final PartySlotBoard board;
  final String raidLeaderLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leftCells = board.cellsForParty(0);
    final rightCells =
        board.partyCount > 1 ? board.cellsForParty(1) : const <PartySlotCell>[];
    final slotCount = leftCells.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          key: const ValueKey('partyGroupRow'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                key: const ValueKey('partyGroup-0'),
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.xxs,
                ),
                child: Text('1파티', style: theme.textTheme.titleSmall),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: board.partyCount > 1
                  ? Padding(
                      key: const ValueKey('partyGroup-1'),
                      padding: const EdgeInsets.only(
                        top: AppSpacing.xs,
                        bottom: AppSpacing.xxs,
                      ),
                      child: Text('2파티', style: theme.textTheme.titleSmall),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        for (var slotIndex = 0; slotIndex < slotCount; slotIndex++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SlotCard(
                      cell: leftCells[slotIndex],
                      raidLeaderLabel: raidLeaderLabel,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: slotIndex < rightCells.length
                        ? _SlotCard(
                            cell: rightCells[slotIndex],
                            raidLeaderLabel: raidLeaderLabel,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PartyGroupColumn extends StatelessWidget {
  const _PartyGroupColumn({
    super.key,
    required this.partyIndex,
    required this.cells,
    required this.raidLeaderLabel,
  });

  final int partyIndex;
  final List<PartySlotCell> cells;
  final String raidLeaderLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.xs,
            bottom: AppSpacing.xxs,
          ),
          child: Text(
            '${partyIndex + 1}파티',
            style: theme.textTheme.titleSmall,
          ),
        ),
        _SlotCardGrid(cells: cells, raidLeaderLabel: raidLeaderLabel),
      ],
    );
  }
}

class _SlotCardGrid extends StatelessWidget {
  const _SlotCardGrid({
    required this.cells,
    required this.raidLeaderLabel,
  });

  final List<PartySlotCell> cells;
  final String raidLeaderLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final cell in cells)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _SlotCard(cell: cell, raidLeaderLabel: raidLeaderLabel),
          ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.cell, required this.raidLeaderLabel});

  final PartySlotCell cell;
  final String raidLeaderLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final member = cell.member;
    final seatLabel = '${cell.slotIndex + 1}번';
    return Card(
      key: ValueKey('slotCard-${cell.partyIndex}-${cell.slotIndex}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: member == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(seatLabel, style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('빈자리', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '현재 별도 참가 조건 없음',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(seatLabel, style: theme.textTheme.titleSmall),
                        if (cell.isLeaderSeat)
                          _RoleBadge(label: raidLeaderLabel),
                        _RoleBadge(label: _roleLabel(member.role)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    _CharacterNameText(name: member.characterName),
                    Text(
                      member.className?.trim().isNotEmpty == true
                          ? member.className!.trim()
                          : '정보 없음',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      member.combatPower != null
                          ? '전투력 ${DisplayNumberFormatter.integer(member.combatPower!)}'
                          : '전투력 정보 없음',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      member.itemLevel != null
                          ? '아이템 Lv. ${DisplayNumberFormatter.integer(member.itemLevel!)}'
                          : '아이템 레벨 정보 없음',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _UnassignedMemberCard extends StatelessWidget {
  const _UnassignedMemberCard({required this.member});

  final PartyMemberDisplay member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('자리 정보 없음', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xxs),
            _CharacterNameText(name: member.characterName),
            Text(
              [
                member.className?.trim().isNotEmpty == true
                    ? member.className!.trim()
                    : '정보 없음',
                _roleLabel(member.role),
                if (member.combatPower != null)
                  '전투력 ${DisplayNumberFormatter.integer(member.combatPower!)}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterNameText extends StatelessWidget {
  const _CharacterNameText({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final label = name?.trim().isNotEmpty == true ? name!.trim() : '정보 없음';
    return Tooltip(
      message: label,
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
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
          else if (application?.status ==
              RecruitmentApplicationStatus.pending) ...[
            Text(
              '${application!.characterName} · ${_roleLabel(application.requestedRole)} 승인 대기',
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('withdrawApplicationButton'),
              onPressed: submitting ? null : onWithdraw,
              child: Text(submitting ? '처리 중...' : '신청 철회'),
            ),
          ] else if (!summary.isRecruiting)
            const Text('현재 모집이 마감되어 신청할 수 없습니다.')
          else ...[
            if (application != null) ...[
              Text(_applicationStatusLabel(application)),
              if (application.rejectionCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '이 방에서 ${application.rejectionCount}회 거절되었습니다. '
                  '다른 캐릭터로 다시 신청할 수 있습니다.',
                ),
              ],
              const SizedBox(height: 12),
            ],
            FilledButton(
              key: const ValueKey('openApplicationButton'),
              onPressed: submitting ? null : onApply,
              child: Text(
                submitting
                    ? '처리 중...'
                    : (isDirectJoin
                          ? '바로 가입'
                          : (application == null ? '지원하기' : '다시 지원하기')),
              ),
            ),
          ],
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

class _MembershipSelfActions extends StatelessWidget {
  const _MembershipSelfActions({
    required this.canLeave,
    required this.submitting,
    required this.onChangeCharacter,
    required this.onLeave,
  });

  final bool canLeave;
  final bool submitting;
  final VoidCallback onChangeCharacter;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('내 참가', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.tonalIcon(
            key: const ValueKey('changeParticipatingCharacterButton'),
            onPressed: submitting ? null : onChangeCharacter,
            icon: const Icon(Icons.swap_horiz),
            label: Text(submitting ? '처리 중...' : '참가 캐릭터 변경'),
          ),
          if (canLeave) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: const ValueKey('leavePartyButton'),
              onPressed: submitting ? null : onLeave,
              icon: const Icon(Icons.logout),
              label: const Text('파티 탈퇴'),
            ),
          ],
        ],
      ),
    );
  }
}

class _KickMembersSection extends StatelessWidget {
  const _KickMembersSection({
    required this.members,
    required this.submitting,
    required this.onKick,
  });

  final List<PartyMemberDisplay> members;
  final bool submitting;
  final ValueChanged<PartyMemberDisplay> onKick;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('파티원 추방', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final member in members)
            Card(
              key: ValueKey('kickMemberCard-${member.playerId}'),
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                title: Text(
                  member.characterName?.trim().isNotEmpty == true
                      ? member.characterName!.trim()
                      : '정보 없음',
                ),
                subtitle: Text(
                  [
                    member.className?.trim().isNotEmpty == true
                        ? member.className!.trim()
                        : '정보 없음',
                    _roleLabel(member.role),
                  ].join(' · '),
                ),
                trailing: TextButton(
                  key: ValueKey('kickMemberButton-${member.playerId}'),
                  onPressed: submitting ? null : () => onKick(member),
                  child: const Text('추방'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChangeCharacterCandidateSheet extends StatelessWidget {
  const _ChangeCharacterCandidateSheet({
    required this.role,
    required this.entries,
  });

  final PartyRole role;
  final List<({RecruitmentLeaderCandidate candidate, double? combatPower})>
  entries;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text('변경할 캐릭터 (${_roleLabel(role)})'),
          ),
          for (final entry in entries)
            ListTile(
              key: ValueKey(
                'change-candidate-${entry.candidate.localCharacterId}',
              ),
              title: Text(entry.candidate.characterId),
              subtitle: Text(
                '${entry.candidate.accountLabel} · ${entry.candidate.className}',
              ),
              onTap: () => Navigator.pop(
                context,
                _ApplySelection(
                  serverCharacterId: entry.candidate.serverCharacterId!,
                  role: role,
                  combatPower: entry.combatPower,
                ),
              ),
            ),
        ],
      ),
    );
  }
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
      PartyApplicationFailure.permissionDenied =>
        '신청 권한을 확인하지 못했습니다. 앱을 최신으로 켠 뒤 다시 시도해 주세요.',
      PartyApplicationFailure.temporarilyUnavailable => '네트워크 연결이 불안정합니다.',
      PartyApplicationFailure.invalidRequest =>
        '신청 주차 또는 요청 정보가 모집과 맞지 않습니다. 상세를 새로고침한 뒤 다시 시도해 주세요.',
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

String _membershipFailureMessage(PartyMembershipFailure failure) =>
    switch (failure) {
      PartyMembershipFailure.unauthenticated ||
      PartyMembershipFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
      PartyMembershipFailure.notFound => '모집 또는 멤버 정보를 찾지 못했습니다.',
      PartyMembershipFailure.unauthorized => '이 동작을 할 권한이 없습니다.',
      PartyMembershipFailure.ownershipLost => '캐릭터 소유권을 확인하지 못했습니다.',
      PartyMembershipFailure.invalidCharacter =>
        '변경할 캐릭터를 확인하지 못했습니다. 인증과 입장 레벨을 확인해 주세요.',
      PartyMembershipFailure.recruitmentClosed => '이미 종료된 모집입니다.',
      PartyMembershipFailure.alreadyCurrentCharacter => '이미 참가 중인 캐릭터입니다.',
      PartyMembershipFailure.participationConflict =>
        '다른 확정 참가와 충돌합니다. 캐릭터를 다시 선택해 주세요.',
      PartyMembershipFailure.roleMismatch ||
      PartyMembershipFailure.invalidComposition =>
        '현재 파티 구성과 맞지 않는 캐릭터입니다.',
      PartyMembershipFailure.revisionConflict =>
        '모집 상태가 바뀌었습니다. 다시 확인해 주세요.',
      PartyMembershipFailure.unsupportedOnSpark => '현재 환경에서 지원하지 않는 동작입니다.',
      PartyMembershipFailure.permissionDenied => '권한을 확인하지 못했습니다.',
      PartyMembershipFailure.temporarilyUnavailable => '네트워크 연결이 불안정합니다.',
      PartyMembershipFailure.invalidRequest => '요청을 확인하지 못했습니다.',
      PartyMembershipFailure.unknown => '멤버 명령을 처리하지 못했습니다.',
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

String _applicationStatusLabel(PartyApplicationSummary application) =>
    switch (application.status) {
      RecruitmentApplicationStatus.pending => '승인 대기',
      RecruitmentApplicationStatus.approved => '승인됨',
      RecruitmentApplicationStatus.rejected => '거절됨',
      RecruitmentApplicationStatus.withdrawn => '철회함',
      RecruitmentApplicationStatus.superseded => '다른 신청으로 대체됨',
    };
