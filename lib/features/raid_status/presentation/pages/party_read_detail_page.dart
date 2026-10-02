import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/character_build/build_integrity_snapshot.dart';
import '../../../../shared/character_build/gem_validation_line.dart';
import '../../../../shared/character_build/build_integrity_status_line.dart';
import '../../../../shared/character_build/party_gem_validation_snapshot.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../../shared/formatters/korea_time_formatter.dart';
import '../../../../shared/game_catalog/domain/entities/game_catalog.dart';
import '../../../../shared/game_catalog/domain/services/class_synergy_service.dart';
import '../../../recruitment_list/domain/entities/party_application_command.dart';
import '../../../account/data/local/account_database.dart';
import '../../../recruitment_list/domain/entities/party_event.dart';
import '../../../recruitment_list/domain/entities/party_create_command.dart';
import '../../../recruitment_list/domain/entities/party_cycle_command.dart';
import '../../../recruitment_list/domain/entities/party_join_command.dart';
import '../../../recruitment_list/domain/entities/party_read_models.dart';
import '../../../recruitment_list/domain/entities/party_recruitment.dart';
import '../../../recruitment_list/domain/entities/recruitment_aggregate.dart';
import '../../../recruitment_list/domain/entities/recruitment_application.dart';
import '../../../recruitment_list/domain/entities/party_visibility_command.dart';
import '../../../recruitment_list/domain/entities/party_raid_state_conflict.dart';
import '../../../recruitment_list/domain/policies/approval_policy.dart';
import '../../../recruitment_list/domain/policies/party_composition_policy.dart';
import '../../../recruitment_list/domain/policies/minimum_combat_power_policy.dart';
import '../../../recruitment_list/domain/repositories/party_application_command_repository.dart';
import '../../../recruitment_list/domain/repositories/party_cycle_command_repository.dart';
import '../../../recruitment_list/domain/repositories/party_join_command_repository.dart';
import '../../../recruitment_list/domain/repositories/party_membership_command_repository.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';
import '../../../recruitment_list/domain/repositories/party_visibility_command_repository.dart';
import '../../../recruitment_list/domain/entities/party_membership_command.dart';
import '../../../recruitment_list/domain/services/group_raid_qualification.dart';
import '../../../recruitment_list/domain/services/recruitment_leader_candidate_service.dart';
import '../../../recruitment_list/domain/services/lazy_cycle_reconciler.dart';
import '../../../group/domain/repositories/group_read_repository.dart';
import '../../../account/domain/entities/weekly_raid_claim_command.dart';
import '../../../account/domain/repositories/weekly_raid_claim_command_repository.dart';
import '../../domain/services/party_event_sync_service.dart';
import '../party_notification_message.dart';
import '../viewmodels/party_notification_view_model.dart';
import '../viewmodels/party_read_detail_view_model.dart';

class PartyReadDetailPage extends StatefulWidget {
  const PartyReadDetailPage({
    required this.recruitmentId,
    required this.partyReadRepository,
    this.applicationCommandRepository,
    this.joinCommandRepository,
    this.membershipCommandRepository,
    this.cycleCommandRepository,
    this.visibilityCommandRepository,
    this.eventSyncService,
    this.accountDatabase,
    this.candidateService,
    this.groupReadRepository,
    this.playerId,
    this.cycleReconciler,
    this.weeklyRaidClaimCommandRepository,
    super.key,
  });

  final String recruitmentId;
  final PartyReadRepository partyReadRepository;
  final PartyApplicationCommandRepository? applicationCommandRepository;
  final PartyJoinCommandRepository? joinCommandRepository;
  final PartyMembershipCommandRepository? membershipCommandRepository;
  final PartyCycleCommandRepository? cycleCommandRepository;
  final PartyVisibilityCommandRepository? visibilityCommandRepository;
  final PartyEventSyncService? eventSyncService;
  final AccountDatabase? accountDatabase;
  final RecruitmentLeaderCandidateService? candidateService;
  final GroupReadRepository? groupReadRepository;
  final String? playerId;
  final LazyCycleReconciler? cycleReconciler;
  final WeeklyRaidClaimCommandRepository? weeklyRaidClaimCommandRepository;

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
  StreamSubscription<PartyReadDetailSnapshot<PartyCycleSnapshot?>>?
  _cycleSubscription;
  PartyApplicationSummary? _myApplication;
  List<PartyMemberDisplay> _members = const [];
  List<PartyApplicationSummary> _applications = const [];
  PartyCycleSnapshot? _cycle;
  String? _subscribedCycleKey;
  bool _membersLoading = true;
  bool _applicationsLoading = false;
  PartyReadFailureType? _membersFailure;
  PartyReadFailureType? _applicationsFailure;
  bool _membersFromCache = false;
  bool _applicationsFromCache = false;
  bool _myApplicationLoading = false;
  bool _submitting = false;
  bool _staleAssignmentHealAttempted = false;
  Set<String> _lostGroupQualificationPlayerIds = const {};
  String? _qualificationLookupKey;
  int _qualificationLookupGeneration = 0;
  List<PartyNotificationItem> _roomEvents = const [];
  bool _roomEventsLoading = false;

  bool get _canApplicantAction =>
      widget.candidateService != null &&
      widget.playerId != null &&
      widget.playerId!.isNotEmpty &&
      (widget.applicationCommandRepository != null ||
          widget.joinCommandRepository != null);

  /// 즉시가입·승인 명령 repo 연결 여부. 신청 목록 Listen은 리더만 연다.
  bool get _hasJoinCommands =>
      widget.joinCommandRepository != null &&
      widget.playerId != null &&
      widget.playerId!.isNotEmpty;

  bool _canManageApplications(PublicRecruitmentSummary summary) =>
      _hasJoinCommands && _isLeader(summary);

  @override
  void initState() {
    super.initState();
    _viewModel = PartyReadDetailViewModel<PublicRecruitmentSummary>(
      streamFactory: () =>
          widget.partyReadRepository.watchRecruitment(widget.recruitmentId),
    );
    unawaited(widget.cycleReconciler?.reconcile(widget.recruitmentId));
    _bindDetailSubscriptions();
    unawaited(_initializeRoomEvents());
  }

  @override
  void didUpdateWidget(covariant PartyReadDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final recruitmentChanged = oldWidget.recruitmentId != widget.recruitmentId;
    final playerChanged = oldWidget.playerId != widget.playerId;
    final repositoryChanged =
        oldWidget.partyReadRepository != widget.partyReadRepository;
    if (!recruitmentChanged && !playerChanged && !repositoryChanged) {
      return;
    }
    _bindDetailSubscriptions(
      restartRecruitment: recruitmentChanged || repositoryChanged,
    );
    if (recruitmentChanged || playerChanged) {
      if (recruitmentChanged) {
        unawaited(widget.cycleReconciler?.reconcile(widget.recruitmentId));
      }
      unawaited(_initializeRoomEvents());
    }
  }

  static final List<String> _roomEventTypes = PartyEventType.values
      .where((type) => type.isRoomAttentionEvent)
      .map((type) => type.wireName)
      .toList(growable: false);

  Future<void> _initializeRoomEvents() async {
    final database = widget.accountDatabase;
    final playerId = widget.playerId;
    if (database == null || playerId == null || playerId.isEmpty) return;
    if (mounted) setState(() => _roomEventsLoading = true);
    await widget.eventSyncService?.sync();
    await database.markPartyRoomNotificationsRead(
      playerId: playerId,
      recruitmentId: widget.recruitmentId,
      types: _roomEventTypes,
    );
    final rows = await database.loadRecentPartyNotifications(
      playerId,
      limit: null,
    );
    if (!mounted) return;
    setState(() {
      _roomEvents = [
        for (final row in rows)
          if (row.recruitmentId == widget.recruitmentId &&
              PartyEventType.tryParse(row.type)?.isRoomAttentionEvent == true)
            PartyNotificationItem(
              eventId: row.eventId,
              type: row.type,
              recruitmentId: row.recruitmentId,
              message: PartyNotificationMessage.format(
                type: row.type,
                characterNameSnapshot: row.characterNameSnapshot,
              ),
              occurredAt: row.occurredAt,
              isRead: true,
              route: '',
            ),
      ];
      _roomEventsLoading = false;
    });
  }

  Future<void> _showRoomEvents() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이벤트 히스토리'),
        content: SizedBox(
          width: 420,
          child: _roomEventsLoading
              ? const Center(child: CircularProgressIndicator())
              : _roomEvents.isEmpty
              ? const Text('이 방에서 확인할 이벤트가 없습니다.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _roomEvents.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _roomEvents[index];
                    return ListTile(
                      key: ValueKey('roomEvent_${item.eventId}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.message),
                      subtitle: Text(_roomEventOccurredAt(item.occurredAt)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _bindDetailSubscriptions({bool restartRecruitment = false}) {
    _myApplicationSubscription?.cancel();
    _myApplicationSubscription = null;
    _membersSubscription?.cancel();
    _membersSubscription = null;
    _applicationsSubscription?.cancel();
    _applicationsSubscription = null;
    _cycleSubscription?.cancel();
    _cycleSubscription = null;
    _subscribedCycleKey = null;
    _cycle = null;

    if (restartRecruitment) {
      _staleAssignmentHealAttempted = false;
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
    _lostGroupQualificationPlayerIds = const {};
    _qualificationLookupKey = null;
    _myApplication = null;
    _myApplicationLoading = false;
    _applications = const [];
    _applicationsLoading = false;
    _applicationsFailure = null;
    _applicationsFromCache = false;

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
          .listen(
            _onMyApplication,
            onError: (_) {
              if (!mounted) return;
              setState(() => _myApplicationLoading = false);
            },
          );
    }
    // 신청 목록·구 cycles는 리더/멤버 확인 후 summary 기준으로 연다.
    if (mounted) setState(() {});
  }

  Future<void> _purgeStaleOwnAssignmentIfNeeded(
    PublicRecruitmentSummary summary,
  ) async {
    if (_staleAssignmentHealAttempted) return;
    final repository = widget.cycleCommandRepository;
    final playerId = widget.playerId;
    if (repository == null || playerId == null || playerId.isEmpty) return;
    final cycleCompleted = _cycle?.isCompleted == true;
    if (summary.status != 'completed' &&
        summary.status != 'disbanded' &&
        summary.currentCycleStatus != 'completed' &&
        !cycleCompleted) {
      return;
    }
    PartyMemberDisplay? mine;
    for (final member in _members) {
      if (member.playerId == playerId) {
        mine = member;
        break;
      }
    }
    final characterId = mine?.characterId;
    if (characterId == null || characterId.isEmpty) return;
    _staleAssignmentHealAttempted = true;
    await repository.purgeStaleOwnAssignment(
      PartyPurgeStaleAssignmentCommand(
        recruitmentId: summary.id,
        characterId: characterId,
        raidId: summary.metadata.raidId,
      ),
    );
  }

  void _ensureApplicationsSubscription(PublicRecruitmentSummary summary) {
    if (!_canManageApplications(summary)) {
      if (_applicationsSubscription == null) return;
      _applicationsSubscription?.cancel();
      _applicationsSubscription = null;
      if (!mounted) return;
      setState(() {
        _applications = const [];
        _applicationsLoading = false;
        _applicationsFailure = null;
        _applicationsFromCache = false;
      });
      return;
    }
    if (_applicationsSubscription != null) return;
    setState(() => _applicationsLoading = true);
    _applicationsSubscription = widget.partyReadRepository
        .watchRecruitmentApplications(widget.recruitmentId)
        .listen(_onApplications, onError: _onApplicationsError);
  }

  void _ensureCycleSubscription(
    PublicRecruitmentSummary summary,
    String cycleKey,
  ) {
    // C*: cycles 쓰기는 닫혀 있고 읽기는 리더·멤버만. 비멤버 구독은 Listen deny만 남긴다.
    final canReadPrivate = _isLeader(summary) || _isConfirmedMember;
    if (!canReadPrivate || cycleKey.isEmpty) {
      if (_cycleSubscription == null && _subscribedCycleKey == null) return;
      _cycleSubscription?.cancel();
      _cycleSubscription = null;
      _subscribedCycleKey = null;
      if (_cycle != null && mounted) setState(() => _cycle = null);
      return;
    }
    if (_subscribedCycleKey == cycleKey) return;
    _cycleSubscription?.cancel();
    _subscribedCycleKey = cycleKey;
    _cycle = null;
    _cycleSubscription = widget.partyReadRepository
        .watchRecruitmentCycle(
          recruitmentId: widget.recruitmentId,
          cycleKey: cycleKey,
        )
        .listen(
          (snapshot) {
            if (!mounted) return;
            setState(() => _cycle = snapshot.item);
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _cycle = null);
          },
        );
  }

  @override
  void dispose() {
    _myApplicationSubscription?.cancel();
    _membersSubscription?.cancel();
    _applicationsSubscription?.cancel();
    _cycleSubscription?.cancel();
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
      _applicationsFromCache = snapshot.isFromCache;
    });
  }

  void _onApplicationsError(Object error) {
    if (!mounted) return;
    setState(() {
      _applicationsLoading = false;
      _applicationsFromCache = false;
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
    if (_membersLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파티원 정보를 불러오는 중입니다. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }
    final occupiedMembers = _occupiedMembersForComposition(summary);
    if (occupiedMembers == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('파티 구성 정보가 불완전합니다. 상세를 새로고침한 뒤 다시 시도해 주세요.'),
        ),
      );
      return;
    }

    final startAt = summary.metadata.raidStartAt ?? DateTime.now();
    final candidates = await candidateService.load(
      RecruitmentLeaderCandidateQuery(
        raidId: summary.metadata.raidId,
        difficultyId: summary.metadata.difficultyId,
        minItemLevel: summary.metadata.minItemLevel,
        minCombatPower: summary.metadata.minCombatPower,
        startAt: startAt,
        maxPlayHours: summary.metadata.maxPlayHours,
        partyRules: summary.partyRules,
        occupiedMembers: occupiedMembers,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
          gemValidation: selected.gemValidation,
          buildIntegrity: selected.buildIntegrity,
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
      if (result.failure == PartyJoinFailure.orphanedParticipation &&
          result.orphanedParticipation != null) {
        await _offerOrphanCleanup(result.orphanedParticipation!);
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
        gemValidation: selected.gemValidation,
        buildIntegrity: selected.buildIntegrity,
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
    if (result.failure == PartyApplicationFailure.orphanedParticipation &&
        result.orphanedParticipation != null) {
      await _offerOrphanCleanup(result.orphanedParticipation!);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_applicationFailureMessage(result.failure!))),
    );
  }

  Future<void> _offerOrphanCleanup(
    PartyOrphanedRaidParticipation orphan, {
    String automaticActionDescription = '신청이나 즉시 가입',
    String retryInstruction = '신청 또는 가입을 다시 시도해 주세요.',
  }) async {
    final repository = widget.weeklyRaidClaimCommandRepository;
    final playerId = widget.playerId;
    if (repository == null || playerId == null || playerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_orphanedParticipationMessage(orphan))),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('참가 기록 정리'),
        content: Text(
          '${_orphanedParticipationMessage(orphan)}\n\n'
          '참가 기록만 정리하며 $automaticActionDescription은 자동으로 진행하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('참가 기록 정리'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final result = await repository.cleanupOrphanParticipation(
      CleanupOrphanRaidParticipationCommand(
        playerId: playerId,
        characterId: orphan.characterId,
        raidId: orphan.raidId,
        cycleKey: orphan.cycleKey,
        recruitmentId: orphan.recruitmentId,
        expectedStateRevision: orphan.stateRevision,
        observation: orphan.observation,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? '남아 있던 참가 기록을 정리했습니다. $retryInstruction'
              : _orphanCleanupFailureMessage(result.failure!),
        ),
      ),
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
        SnackBar(content: Text(approve ? '가입 신청을 승인했습니다.' : '가입 신청을 거절했습니다.')),
      );
      return;
    }
    if (approve &&
        result.failure == PartyJoinFailure.minimumCombatPowerNotMet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '신청 캐릭터가 모집 최소 전투력을 충족하지 않아 '
            '승인할 수 없습니다. 신청을 거절해 주세요.',
          ),
        ),
      );
      return;
    }
    if (approve &&
        result.failure == PartyJoinFailure.permissionDenied &&
        _canOfferApprovalFailureRecovery(
          summary: summary,
          application: application,
        )) {
      await _showApprovalFailureRecovery(
        summary: summary,
        application: application,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_joinFailureMessage(result.failure!))),
    );
  }

  bool _canOfferApprovalFailureRecovery({
    required PublicRecruitmentSummary summary,
    required PartyApplicationSummary application,
  }) {
    final state = _viewModel.state;
    final currentSummary = state.item;
    if (currentSummary == null ||
        state.isFromCache ||
        currentSummary.id != widget.recruitmentId ||
        currentSummary.id != summary.id ||
        currentSummary.revision != summary.revision ||
        !_canManageApplications(currentSummary) ||
        _applicationsLoading ||
        _applicationsFailure != null ||
        _applicationsFromCache) {
      return false;
    }
    for (final currentApplication in _applications) {
      if (currentApplication.applicantPlayerId ==
              application.applicantPlayerId &&
          currentApplication.revision == application.revision &&
          currentApplication.status ==
              RecruitmentApplicationStatus.pending) {
        return true;
      }
    }
    return false;
  }

  Future<void> _showApprovalFailureRecovery({
    required PublicRecruitmentSummary summary,
    required PartyApplicationSummary application,
  }) async {
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가입 신청 승인 불가'),
        content: const Text(
          '신청자의 참가 데이터에 오류가 있어 승인할 수 없습니다. '
          '해당 신청을 거절해 주세요.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('closeApprovalFailureDialog'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('닫기'),
          ),
          FilledButton(
            key: const ValueKey('rejectAfterApprovalFailureButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('신청 거절'),
          ),
        ],
      ),
    );
    if (shouldReject != true || !mounted) return;
    await _decideApplication(
      summary: summary,
      application: application,
      approve: false,
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
          if (summary.status == 'disbanded') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _purgeStaleOwnAssignmentIfNeeded(summary);
              }
            });
            return const _MessageView(
              icon: Icons.meeting_room_outlined,
              title: '해산된 파티입니다.',
              description: '이 방은 더 이상 진행 중이 아닙니다.',
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _ensureApplicationsSubscription(summary);
              _ensureCycleSubscription(summary, summary.currentCycleKey);
              _purgeStaleOwnAssignmentIfNeeded(summary);
              _refreshLostGroupQualification(summary);
            }
          });
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
                _DetailLine(label: '파티장', value: _leaderDetailLabel(summary)),
                _DetailLine(label: '레이드', value: _raidLabel(summary.metadata)),
                _DetailLine(
                  label: '일정',
                  value: _scheduleLabel(summary.metadata),
                ),
                _DetailLine(
                  label: '인원',
                  value:
                      '${summary.memberCount}/${summary.maxMemberCount}명'
                      '${summary.isRecruiting ? ' · 모집 중' : ' · 모집 마감'} '
                      '(딜러 ${summary.dealerCount}/${summary.maxDealerCount}, '
                      '서포터 ${summary.supportCount}/${summary.maxSupportCount})',
                ),
                _DetailLine(
                  label: '조건',
                  value: _requirementLabel(summary.metadata),
                ),
                _DetailLine(
                  label: '가입',
                  value: _approvalModeLabel(summary.approvalMode),
                ),
                if (summary.isGroupLinked)
                  _DetailLine(
                    label: '공개',
                    value: summary.isGroupOnly ? '그룹만 공개' : '전체 공개 · 그룹 연결 유지',
                  ),
                if (_isLeader(summary) &&
                    summary.isGroupLinked &&
                    summary.isActiveRecruitment &&
                    widget.visibilityCommandRepository != null)
                  SwitchListTile(
                    key: const ValueKey('groupOnlyVisibilitySwitch'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('그룹만 공개'),
                    subtitle: Text(
                      summary.isGroupOnly
                          ? '그룹원만 모집 목록에서 보고 신청할 수 있습니다.'
                          : '전체 공개입니다. 연결 그룹은 유지됩니다.',
                    ),
                    value: summary.isGroupOnly,
                    onChanged: _submitting
                        ? null
                        : (value) => _setGroupOnly(summary, value),
                  ),
                _PartyCompositionSection(
                  members: _members,
                  membersPerParty: summary.membersPerParty,
                  supportsPerParty: summary.supportsPerParty,
                  maxMemberCount: summary.maxMemberCount,
                  lostGroupQualificationPlayerIds:
                      _lostGroupQualificationPlayerIds,
                  showThisWeekRaidComplete:
                      summary.showsThisWeekRaidCompleteMark,
                  loading: _membersLoading,
                  failure: _membersFailure,
                  isFromCache: _membersFromCache,
                  onOpenNotifications: widget.accountDatabase == null
                      ? null
                      : _showRoomEvents,
                  onReposition:
                      _isLeader(summary) &&
                          summary.maxMemberCount > summary.membersPerParty &&
                          summary.supportsPositionChanges &&
                          _canUseMembershipCommands
                      ? () => _openRepositionFlow(summary)
                      : null,
                ),
                if (_isLeader(summary))
                  _PendingApplicationsSection(
                    applications: _applications,
                    minCombatPower: summary.metadata.minCombatPower,
                    loading: _applicationsLoading,
                    failure: _applicationsFailure,
                    submitting: _submitting,
                    canDecide:
                        summary.approvalMode != ApprovalMode.directJoin &&
                        widget.joinCommandRepository != null,
                    synergyService: const ClassSynergyService(),
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
                if (_canApplicantAction &&
                    !_isLeader(summary) &&
                    !_isConfirmedMember)
                  _ApplicationActions(
                    summary: summary,
                    myApplication: _myApplication,
                    loadingApplication: _myApplicationLoading,
                    submitting: _submitting,
                    onApply: () => _openApplySheet(summary),
                    onWithdraw: _withdraw,
                  )
                else if (!_canApplicantAction &&
                    !_hasJoinCommands &&
                    !_canUseMembershipCommands)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Text('이 화면은 조회 전용입니다. 신청과 수정은 아직 연결되지 않았습니다.'),
                  ),
                if (_isConfirmedMember &&
                    _canUseMembershipCommands &&
                    _membershipActionsAllowed(summary))
                  _MembershipSelfActions(
                    canLeave: summary.memberCount > 1,
                    submitting: _submitting,
                    onChangeCharacter: () => _openChangeCharacterSheet(summary),
                    onLeave: () => _confirmLeave(summary),
                  ),
                if (_isLeader(summary) &&
                    _canUseMembershipCommands &&
                    _membershipActionsAllowed(summary) &&
                    summary.memberCount > 1)
                  _KickMembersSection(
                    members: _members
                        .where((member) => member.playerId != widget.playerId)
                        .toList(growable: false),
                    submitting: _submitting,
                    onKick: (member) => _confirmKick(summary, member),
                  ),
                if (_canCleanLostGroupQualification(summary))
                  _LostGroupQualificationSection(
                    members: _members
                        .where(
                          (member) => _lostGroupQualificationPlayerIds.contains(
                            member.playerId,
                          ),
                        )
                        .toList(growable: false),
                    submitting: _submitting,
                    onRemove: (member) =>
                        _confirmRemoveLostGroupQualification(summary, member),
                  ),
                if (_canUseCycleCommands && _isConfirmedMember)
                  _CycleLifecycleSection(
                    summary: summary,
                    cycle: _cycle,
                    isLeader: _isLeader(summary),
                    submitting: _submitting,
                    onComplete: () => _confirmComplete(summary),
                    onToggleRecurrence: (value) =>
                        _confirmSetRecurrence(summary, value),
                    onDisband: () => _confirmDisband(summary),
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

  bool get _canUseCycleCommands =>
      widget.cycleCommandRepository != null &&
      widget.playerId != null &&
      widget.playerId!.isNotEmpty;

  bool get _isConfirmedMember =>
      widget.playerId != null &&
      _members.any((member) => member.playerId == widget.playerId);

  bool _canDeleteRecruitment(PublicRecruitmentSummary summary) =>
      _isLeader(summary) &&
      _canUseMembershipCommands &&
      summary.isActiveRecruitment &&
      summary.isCycleActive &&
      summary.memberCount <= 1;

  bool _membershipActionsAllowed(PublicRecruitmentSummary summary) =>
      summary.isActiveRecruitment &&
      (summary.isCycleActive ||
          (summary.continueTogether && summary.isCycleCompleted));

  List<OccupiedPartyMember>? _occupiedMembersForComposition(
    PublicRecruitmentSummary summary,
  ) {
    final occupied = <OccupiedPartyMember>[];
    for (final member in _members) {
      final className = member.className?.trim();
      if (className == null || className.isEmpty) return null;
      occupied.add(
        OccupiedPartyMember(
          id: member.playerId,
          className: className,
          role: member.role,
          partyIndex: member.partyIndex,
          slotIndex: member.slotIndex,
          isLeader: member.playerId == summary.leaderUserId,
        ),
      );
    }
    return occupied;
  }

  Future<void> _openChangeCharacterSheet(
    PublicRecruitmentSummary summary,
  ) async {
    final candidateService = widget.candidateService;
    final repository = widget.membershipCommandRepository;
    if (repository == null || !_isConfirmedMember || _submitting) {
      return;
    }
    if (candidateService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('참가 캐릭터 변경을 준비하지 못했습니다. 앱을 다시 실행해 주세요.')),
      );
      return;
    }
    if (_membersLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파티원 정보를 불러오는 중입니다. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }
    final occupiedMembers = _occupiedMembersForComposition(summary);
    if (occupiedMembers == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('파티 구성 정보가 불완전합니다. 상세를 새로고침한 뒤 다시 시도해 주세요.'),
        ),
      );
      return;
    }
    final me = _members.firstWhere(
      (member) => member.playerId == widget.playerId,
    );
    setState(() => _submitting = true);
    final List<RecruitmentLeaderCandidate> candidates;
    try {
      candidates = await candidateService.load(
        RecruitmentLeaderCandidateQuery(
          raidId: summary.metadata.raidId,
          difficultyId: summary.metadata.difficultyId,
          minItemLevel: summary.metadata.minItemLevel,
          minCombatPower: summary.metadata.minCombatPower,
          startAt: summary.metadata.raidStartAt ?? DateTime.now(),
          maxPlayHours: summary.metadata.maxPlayHours,
          partyRules: summary.partyRules,
          occupiedMembers: occupiedMembers,
          replacingMemberId: widget.playerId,
          allowPositionChanges: summary.supportsPositionChanges,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변경 가능한 캐릭터를 불러오지 못했습니다. 다시 시도해 주세요.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    final isNextWeekPrep = summary.continueTogether && summary.isCycleCompleted;
    final eligible =
        <
          ({
            RecruitmentLeaderCandidate candidate,
            RecruitmentLeaderRoleOption option,
          })
        >[];
    for (final candidate in candidates) {
      final serverId = candidate.serverCharacterId;
      if (serverId == null || serverId.isEmpty) continue;
      final claimOnlyBlocked =
          candidate.rejectionReasons.length == 1 &&
          candidate.rejectionReasons.single == '이번 주 동일 레이드 완료';
      if (!candidate.canSelect && !(isNextWeekPrep && claimOnlyBlocked)) {
        continue;
      }
      for (final option in candidate.roles.where(
        (option) => option.canSelect,
      )) {
        if (me.characterId == serverId && option.role == me.role) continue;
        eligible.add((candidate: candidate, option: option));
      }
    }
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('변경 가능한 캐릭터가 없습니다. 역할 세팅과 파티 구성을 확인해 주세요.'),
            duration: Duration(seconds: 4),
          ),
        );
      return;
    }

    final selected = await showModalBottomSheet<_ApplySelection>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ChangeCharacterCandidateSheet(entries: eligible),
    );
    if (selected == null || !mounted) return;

    if (isNextWeekPrep) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('다음 주 참가 캐릭터를 변경할까요?'),
          content: const Text(
            '이번 회차 완료 기록은 유지됩니다. 구성을 바꾸면 이 회차의 전체 완료 취소는 더 이상 할 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('변경'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _submitting = true);
    final result = await repository.changeCharacter(
      PartyChangeCharacterCommand(
        recruitmentId: widget.recruitmentId,
        newCharacterId: selected.serverCharacterId,
        newRole: selected.role,
        expectedRecruitmentRevision: summary.revision,
        combatPower: selected.combatPower,
        gemValidation: selected.gemValidation,
        buildIntegrity: selected.buildIntegrity,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNextWeekPrep ? '다음 주 참가 캐릭터를 변경했습니다.' : '참가 캐릭터를 변경했습니다.',
          ),
        ),
      );
      return;
    }
    if (result.failure == PartyMembershipFailure.orphanedParticipation &&
        result.orphanedParticipation != null) {
      await _offerOrphanCleanup(
        result.orphanedParticipation!,
        automaticActionDescription: '캐릭터 변경',
        retryInstruction: '캐릭터 변경을 다시 시도해 주세요.',
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_membershipFailureMessage(result.failure!))),
    );
  }

  Future<void> _openRepositionFlow(PublicRecruitmentSummary summary) async {
    final repository = widget.membershipCommandRepository;
    if (repository == null || _submitting || _membersLoading) return;
    final source = await showModalBottomSheet<PartyMemberDisplay>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('이동할 파티원 선택')),
          for (final member in _members.where(
            (member) => member.playerId != summary.leaderUserId,
          ))
            ListTile(
              title: Text(member.characterName ?? '정보 없음'),
              subtitle: Text(
                '${member.partyIndex + 1}파티 ${((member.slotIndex ?? 0) + 1)}번 · ${member.className ?? '정보 없음'}',
              ),
              onTap: () => Navigator.of(context).pop(member),
            ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    final board = PartySlotBoard.fromMembers(
      members: _members,
      membersPerParty: summary.membersPerParty,
      maxMemberCount: summary.maxMemberCount,
    );
    final destination = await showModalBottomSheet<PartySlotCell>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('이동할 자리 선택')),
          for (final cell in board.cells.where(
            (cell) =>
                !cell.isLeaderSeat && cell.member?.playerId != source.playerId,
          ))
            ListTile(
              title: Text('${cell.partyIndex + 1}파티 ${cell.slotIndex + 1}번'),
              subtitle: Text(
                cell.member == null
                    ? '빈자리로 이동'
                    : '${cell.member!.characterName ?? '정보 없음'}님과 자리 교환',
              ),
              onTap: () => Navigator.of(context).pop(cell),
            ),
        ],
      ),
    );
    if (destination == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('자리를 조정할까요?'),
        content: Text(
          destination.member == null
              ? '${source.characterName ?? '파티원'}님을 ${destination.partyIndex + 1}파티 ${destination.slotIndex + 1}번 빈자리로 이동합니다.'
              : '${source.characterName ?? '파티원'}님과 ${destination.member!.characterName ?? '파티원'}님의 자리를 교환합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    final result = await repository.repositionMembers(
      PartyRepositionMembersCommand(
        recruitmentId: widget.recruitmentId,
        sourcePlayerId: source.playerId,
        destinationPartyIndex: destination.partyIndex,
        destinationSlotIndex: destination.slotIndex,
        expectedRecruitmentRevision: summary.revision,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? '파티원 자리를 조정했습니다.'
              : _membershipFailureMessage(result.failure!),
        ),
      ),
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
        content: Text('$name 님을 추방합니다. 자리는 비워 두고 남은 멤버를 앞으로 당기지 않습니다.'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('모집을 삭제할까요?'),
        content: const Text('방이 모집 목록에서 사라지고 해산 처리됩니다. 이 동작은 되돌릴 수 없습니다.'),
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
    final cycleRepository = widget.cycleCommandRepository;
    if (cycleRepository == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모집 삭제를 처리할 수 없습니다.')));
      return;
    }
    final result = await cycleRepository.disband(
      PartyDisbandCommand(
        recruitmentId: widget.recruitmentId,
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
      SnackBar(content: Text(_cycleFailureMessage(result.failure!))),
    );
  }

  Future<void> _confirmComplete(PublicRecruitmentSummary summary) async {
    final repository = widget.cycleCommandRepository;
    if (repository == null ||
        !_isLeader(summary) ||
        !summary.isActiveRecruitment ||
        !summary.isCycleActive ||
        _submitting) {
      return;
    }
    final endsAt = summary.cycleEndsAt;
    if (endsAt != null && !DateTime.now().toUtc().isBefore(endsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 회차 기간이 종료되었습니다. 잠시 후 화면을 새로고침해 주세요.')),
      );
      return;
    }
    final repeating = summary.continueTogether;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('파티 전체 완료할까요?'),
        content: Text(
          repeating
              ? '완료 당시 파티원 전원의 주간 레이드 완료 상태가 기록되고, 이번 회차가 완료 처리됩니다. 방과 다음 회차 준비 구성은 유지되며 이번 주차의 파티 전체 완료는 되돌릴 수 없습니다.'
              : '완료 당시 파티원 전원의 주간 레이드 완료 상태가 기록되고, 활성 모집에서 제외됩니다. 이후 수정할 수 없으며 해산 절차로 이동합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmCompleteCycleButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('파티 전체 완료'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final result = await repository.complete(
      PartyCompleteCycleCommand(
        recruitmentId: widget.recruitmentId,
        cycleKey: summary.currentCycleKey,
        expectedRecruitmentRevision: summary.revision,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      await _syncPartyEventsAfterCycleChange();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            repeating
                ? '회차를 완료했습니다. 완료 기록 탭에서 확인할 수 있습니다.'
                : '회차를 완료했습니다. 해산하면 방이 닫히고, 완료 기록 탭에서 확인할 수 있습니다.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_cycleFailureMessage(result.failure!))),
    );
  }

  Future<void> _confirmSetRecurrence(
    PublicRecruitmentSummary summary,
    bool continueTogether,
  ) async {
    final repository = widget.cycleCommandRepository;
    if (repository == null ||
        !_isLeader(summary) ||
        !summary.isActiveRecruitment ||
        _submitting) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(continueTogether ? '다음 주도 함께할까요?' : '다음 주 함께하기를 끌까요?'),
        content: Text(
          continueTogether
              ? '완료 후에도 방과 참가자가 유지되고 다음 회차 준비를 이어갑니다.'
              : '1회성 파티처럼 동작합니다. 완료 후에는 해산 절차로 이동합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmSetRecurrenceButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final result = await repository.setRecurrence(
      PartySetRecurrenceCommand(
        recruitmentId: widget.recruitmentId,
        continueTogether: continueTogether,
        expectedRecruitmentRevision: summary.revision,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            continueTogether ? '다음 주도 함께하기로 설정했습니다.' : '다음 주 함께하기를 껐습니다.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_cycleFailureMessage(result.failure!))),
    );
  }

  Future<void> _confirmDisband(PublicRecruitmentSummary summary) async {
    final repository = widget.cycleCommandRepository;
    if (repository == null ||
        !_isLeader(summary) ||
        _submitting ||
        (summary.status != 'active' && summary.status != 'completed')) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('파티를 해산할까요?'),
        content: const Text('모든 참가가 해제되고 방은 목록에서 사라집니다. 이 동작은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmDisbandPartyButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('해산'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final result = await repository.disband(
      PartyDisbandCommand(
        recruitmentId: widget.recruitmentId,
        expectedRecruitmentRevision: summary.revision,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('파티를 해산했습니다.')));
      Navigator.of(context).maybePop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_cycleFailureMessage(result.failure!))),
    );
  }

  Future<void> _setGroupOnly(
    PublicRecruitmentSummary summary,
    bool groupOnly,
  ) async {
    final repository = widget.visibilityCommandRepository;
    if (repository == null) return;
    final visibility = groupOnly
        ? RecruitmentVisibility.group
        : RecruitmentVisibility.public;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(groupOnly ? '그룹만 공개로 바꿀까요?' : '전체 공개로 바꿀까요?'),
        content: Text(
          groupOnly
              ? '그룹원만 모집 목록에서 보고 신청할 수 있습니다. 그룹에 없는 참가자나 신청이 있으면 바꿀 수 없습니다.'
              : '그룹 밖 사용자도 모집 목록에서 보고 신청할 수 있습니다. 연결 그룹은 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmVisibilityChangeButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(groupOnly ? '그룹만 공개' : '전체 공개'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    final result = await repository.setVisibility(
      PartyVisibilityCommand(
        recruitmentId: widget.recruitmentId,
        visibility: visibility,
        expectedRecruitmentRevision: summary.revision,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failure == null
              ? (groupOnly ? '그룹만 공개로 바꿨습니다.' : '전체 공개로 바꿨습니다.')
              : partyVisibilityFailureMessage(result.failure!),
        ),
      ),
    );
  }

  bool _isLeader(PublicRecruitmentSummary summary) =>
      widget.playerId != null && widget.playerId == summary.leaderUserId;

  bool _canCleanLostGroupQualification(PublicRecruitmentSummary summary) {
    if (!_canUseMembershipCommands || !_membershipActionsAllowed(summary)) {
      return false;
    }
    if (!summary.isGroupOnly || !_isConfirmedMember) return false;
    if (_lostGroupQualificationPlayerIds.contains(widget.playerId)) {
      return false;
    }
    return _members.any(
      (member) =>
          member.playerId != widget.playerId &&
          _lostGroupQualificationPlayerIds.contains(member.playerId),
    );
  }

  Future<void> _refreshLostGroupQualification(
    PublicRecruitmentSummary summary,
  ) async {
    final memberKey = _members.map((member) => member.playerId).join(',');
    final key =
        '${summary.visibility}|${summary.groupId ?? ''}|$memberKey|${widget.playerId ?? ''}';
    if (key == _qualificationLookupKey) return;
    _qualificationLookupKey = key;
    final generation = ++_qualificationLookupGeneration;
    final isGroupOnly = GroupRaidQualification.isGroupOnlyRaid(
      visibility: summary.visibility,
      groupId: summary.groupId,
    );
    if (!isGroupOnly ||
        widget.groupReadRepository == null ||
        summary.groupId == null) {
      if (!mounted || generation != _qualificationLookupGeneration) return;
      setState(() => _lostGroupQualificationPlayerIds = const {});
      return;
    }
    Set<String> lostIds;
    try {
      final groupMembers = await widget.groupReadRepository!.loadGroupMembers(
        summary.groupId!,
      );
      lostIds = GroupRaidQualification.lostPlayerIds(
        isGroupOnlyRaid: true,
        raidMemberPlayerIds: _members.map((member) => member.playerId),
        currentGroupMemberPlayerIds: {
          for (final member in groupMembers) member.playerId,
        },
      );
    } on GroupReadException catch (error) {
      lostIds = error.type == GroupReadFailureType.permissionDenied
          ? GroupRaidQualification.lostPlayerIdsWhenGroupUnreadable(
              isGroupOnlyRaid: true,
              currentPlayerId: widget.playerId,
            )
          : const {};
    } catch (_) {
      lostIds = const {};
    }
    if (!mounted || generation != _qualificationLookupGeneration) return;
    setState(() => _lostGroupQualificationPlayerIds = lostIds);
  }

  Future<void> _confirmRemoveLostGroupQualification(
    PublicRecruitmentSummary summary,
    PartyMemberDisplay member,
  ) async {
    if (!_canCleanLostGroupQualification(summary) || _submitting) return;
    final name = member.characterName?.trim().isNotEmpty == true
        ? member.characterName!.trim()
        : '선택한 파티원';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('그룹 자격을 잃은 파티원을 정리할까요?'),
        content: Text(
          '$name 님은 그룹을 떠나 그룹 전용 레이드 참가 자격을 잃었습니다. 방에서 제외합니다. 이 동작은 일반 추방이 아닙니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmRemoveLostGroupQualificationButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('정리'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    final result = await widget.membershipCommandRepository!
        .removeLostGroupQualification(
          PartyRemoveMemberCommand(
            recruitmentId: widget.recruitmentId,
            targetPlayerId: member.playerId,
            expectedRecruitmentRevision: summary.revision,
          ),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      _qualificationLookupKey = null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('그룹 자격을 잃은 파티원을 정리했습니다.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_membershipFailureMessage(result.failure!))),
    );
  }

  Future<void> _syncPartyEventsAfterCycleChange() async {
    final sync = widget.eventSyncService;
    if (sync == null) return;
    try {
      await sync.sync();
    } catch (_) {
      // 완료 자체는 성공했을 수 있다. 기록 탭 진입 시 다시 동기화한다.
    }
  }
}

class _PartyCompositionSection extends StatelessWidget {
  const _PartyCompositionSection({
    required this.members,
    required this.membersPerParty,
    required this.supportsPerParty,
    required this.maxMemberCount,
    required this.loading,
    required this.failure,
    required this.isFromCache,
    this.lostGroupQualificationPlayerIds = const {},
    this.showThisWeekRaidComplete = false,
    this.onOpenNotifications,
    this.onReposition,
  });

  /// 파티 그룹 2열 후보 breakpoint. 기기 종류가 아니라 가용 폭만 본다.
  /// 펼친 폴드의 구성판 가용 폭(패딩 제외)이 보통 650~690dp라 720은 미달한다.
  static const double partyGroupBreakpoint = 600;

  final List<PartyMemberDisplay> members;
  final int membersPerParty;
  final int supportsPerParty;
  final int maxMemberCount;
  final bool showThisWeekRaidComplete;
  final Set<String> lostGroupQualificationPlayerIds;
  final bool loading;
  final PartyReadFailureType? failure;
  final bool isFromCache;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onReposition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final board = PartySlotBoard.fromMembers(
      members: members,
      membersPerParty: membersPerParty,
      maxMemberCount: maxMemberCount,
    );
    final compositionWarningPlayerIds = _compositionWarningPlayerIds(board);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('파티 구성', style: theme.textTheme.titleMedium),
              if (showThisWeekRaidComplete) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '이번주 레이드완료',
                    key: const ValueKey('thisWeekRaidCompleteLabel'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (onReposition != null)
                TextButton.icon(
                  key: const ValueKey('repositionMembersButton'),
                  onPressed: onReposition,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('자리 조정'),
                ),
              if (onOpenNotifications != null)
                IconButton(
                  key: const ValueKey('roomEventHistoryButton'),
                  tooltip: '이벤트 히스토리',
                  visualDensity: VisualDensity.compact,
                  onPressed: onOpenNotifications,
                  icon: const Icon(Icons.notifications_outlined),
                ),
            ],
          ),
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
                final raidLeaderLabel = board.partyCount > 1 ? '공대장' : '파티장';
                return Column(
                  key: const ValueKey('partyCompositionBoard'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (useWidePartyGroups)
                      _WidePartyGroups(
                        board: board,
                        raidLeaderLabel: raidLeaderLabel,
                        supportsPerParty: supportsPerParty,
                        lostGroupQualificationPlayerIds:
                            lostGroupQualificationPlayerIds,
                        compositionWarningPlayerIds:
                            compositionWarningPlayerIds,
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
                          supportsPerParty: supportsPerParty,
                          lostGroupQualificationPlayerIds:
                              lostGroupQualificationPlayerIds,
                          compositionWarningPlayerIds:
                              compositionWarningPlayerIds,
                        ),
                    if (board.unassignedMembers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          bottom: AppSpacing.xxs,
                        ),
                        child: Text('자리 미정', style: theme.textTheme.titleSmall),
                      ),
                      for (final member in board.unassignedMembers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _UnassignedMemberCard(
                            member: member,
                            lostGroupQualification:
                                lostGroupQualificationPlayerIds.contains(
                                  member.playerId,
                                ),
                          ),
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

String _roomEventOccurredAt(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

bool _slotLostGroupQualification(
  PartySlotCell cell,
  Set<String> lostGroupQualificationPlayerIds,
) {
  final playerId = cell.member?.playerId;
  return playerId != null && lostGroupQualificationPlayerIds.contains(playerId);
}

Set<String> _compositionWarningPlayerIds(PartySlotBoard board) {
  final idsByKey = <String, List<String>>{};
  for (final cell in board.cells) {
    final member = cell.member;
    final className = member?.className?.trim();
    if (member == null ||
        member.role != PartyRole.dealer ||
        className == null ||
        className.isEmpty) {
      continue;
    }
    idsByKey
        .putIfAbsent('${cell.partyIndex}::$className', () => <String>[])
        .add(member.playerId);
  }
  return {
    for (final ids in idsByKey.values)
      if (ids.length > 1) ...ids,
  };
}

String _partyGroupLabel(
  int partyIndex,
  List<PartySlotCell> cells,
  int supportsPerParty,
) {
  final dealerCount = cells
      .where((cell) => cell.member?.role == PartyRole.dealer)
      .length;
  final supportCount = cells
      .where((cell) => cell.member?.role == PartyRole.support)
      .length;
  final maxSupports = supportsPerParty.clamp(0, cells.length);
  final maxDealers = cells.length - maxSupports;
  return '${partyIndex + 1}파티 · 딜러 $dealerCount/$maxDealers · '
      '서포터 $supportCount/$maxSupports';
}

/// 넓은 화면: 파티 제목을 좌우로 두고, 같은 자리(1~4번) Slot Card 높이를 맞춘다.
class _WidePartyGroups extends StatelessWidget {
  const _WidePartyGroups({
    required this.board,
    required this.raidLeaderLabel,
    required this.supportsPerParty,
    required this.compositionWarningPlayerIds,
    this.lostGroupQualificationPlayerIds = const {},
  });

  final PartySlotBoard board;
  final String raidLeaderLabel;
  final int supportsPerParty;
  final Set<String> lostGroupQualificationPlayerIds;
  final Set<String> compositionWarningPlayerIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leftCells = board.cellsForParty(0);
    final rightCells = board.partyCount > 1
        ? board.cellsForParty(1)
        : const <PartySlotCell>[];
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
                child: Text(
                  _partyGroupLabel(0, leftCells, supportsPerParty),
                  style: theme.textTheme.titleSmall,
                ),
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
                      child: Text(
                        _partyGroupLabel(1, rightCells, supportsPerParty),
                        style: theme.textTheme.titleSmall,
                      ),
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
                      lostGroupQualification: _slotLostGroupQualification(
                        leftCells[slotIndex],
                        lostGroupQualificationPlayerIds,
                      ),
                      compositionWarning: compositionWarningPlayerIds.contains(
                        leftCells[slotIndex].member?.playerId,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: slotIndex < rightCells.length
                        ? _SlotCard(
                            cell: rightCells[slotIndex],
                            raidLeaderLabel: raidLeaderLabel,
                            lostGroupQualification: _slotLostGroupQualification(
                              rightCells[slotIndex],
                              lostGroupQualificationPlayerIds,
                            ),
                            compositionWarning: compositionWarningPlayerIds
                                .contains(
                                  rightCells[slotIndex].member?.playerId,
                                ),
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
    required this.supportsPerParty,
    required this.compositionWarningPlayerIds,
    this.lostGroupQualificationPlayerIds = const {},
  });

  final int partyIndex;
  final List<PartySlotCell> cells;
  final String raidLeaderLabel;
  final int supportsPerParty;
  final Set<String> lostGroupQualificationPlayerIds;
  final Set<String> compositionWarningPlayerIds;

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
            _partyGroupLabel(partyIndex, cells, supportsPerParty),
            style: theme.textTheme.titleSmall,
          ),
        ),
        _SlotCardGrid(
          cells: cells,
          raidLeaderLabel: raidLeaderLabel,
          lostGroupQualificationPlayerIds: lostGroupQualificationPlayerIds,
          compositionWarningPlayerIds: compositionWarningPlayerIds,
        ),
      ],
    );
  }
}

class _SlotCardGrid extends StatelessWidget {
  const _SlotCardGrid({
    required this.cells,
    required this.raidLeaderLabel,
    required this.compositionWarningPlayerIds,
    this.lostGroupQualificationPlayerIds = const {},
  });

  final List<PartySlotCell> cells;
  final String raidLeaderLabel;
  final Set<String> lostGroupQualificationPlayerIds;
  final Set<String> compositionWarningPlayerIds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final cell in cells)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _SlotCard(
              cell: cell,
              raidLeaderLabel: raidLeaderLabel,
              lostGroupQualification: _slotLostGroupQualification(
                cell,
                lostGroupQualificationPlayerIds,
              ),
              compositionWarning: compositionWarningPlayerIds.contains(
                cell.member?.playerId,
              ),
            ),
          ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.cell,
    required this.raidLeaderLabel,
    this.lostGroupQualification = false,
    this.compositionWarning = false,
  });

  final PartySlotCell cell;
  final String raidLeaderLabel;
  final bool lostGroupQualification;
  final bool compositionWarning;

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
                    Text('현재 별도 참가 조건 없음', style: theme.textTheme.bodySmall),
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
                        if (lostGroupQualification)
                          const _RoleBadge(label: '그룹 탈퇴'),
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
                    if (member.buildIntegrity case final integrity?) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      BuildIntegrityStatusLine(
                        snapshot: integrity,
                        keyName: 'memberBuildIntegrity-${member.playerId}',
                      ),
                    ] else if (member.gemValidation case final validation?) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      GemValidationLine(
                        validation: validation,
                        keyName: 'memberGemValidation',
                      ),
                    ],
                    if (compositionWarning) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '동일 직업 · 자리 조정 필요',
                        key: ValueKey(
                          'memberCompositionWarning-${member.playerId}',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _UnassignedMemberCard extends StatelessWidget {
  const _UnassignedMemberCard({
    required this.member,
    this.lostGroupQualification = false,
  });

  final PartyMemberDisplay member;
  final bool lostGroupQualification;

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
            if (lostGroupQualification) ...[
              const SizedBox(height: AppSpacing.xxs),
              const Align(
                alignment: Alignment.centerLeft,
                child: _RoleBadge(label: '그룹 탈퇴'),
              ),
            ],
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
            if (member.buildIntegrity case final integrity?) ...[
              const SizedBox(height: AppSpacing.xxs),
              BuildIntegrityStatusLine(
                snapshot: integrity,
                keyName: 'unassignedMemberBuildIntegrity-${member.playerId}',
              ),
            ] else if (member.gemValidation case final validation?) ...[
              const SizedBox(height: AppSpacing.xxs),
              GemValidationLine(
                validation: validation,
                keyName: 'unassignedMemberGemValidation',
              ),
            ],
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
    required this.minCombatPower,
    required this.loading,
    required this.failure,
    required this.submitting,
    required this.canDecide,
    required this.onApprove,
    required this.onReject,
    this.synergyService,
  });

  final List<PartyApplicationSummary> applications;
  final int? minCombatPower;
  final bool loading;
  final PartyReadFailureType? failure;
  final bool submitting;
  final bool canDecide;
  final ClassSynergyService? synergyService;
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
              _ApplicationCard(
                key: ValueKey(
                  'pendingApplication-${application.applicantPlayerId}',
                ),
                application: application,
                minCombatPower: minCombatPower,
                canDecide: canDecide,
                submitting: submitting,
                synergyService: synergyService,
                onApprove: onApprove,
                onReject: onReject,
              ),
          ],
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    super.key,
    required this.application,
    required this.minCombatPower,
    required this.canDecide,
    required this.submitting,
    required this.onApprove,
    required this.onReject,
    this.synergyService,
  });

  final PartyApplicationSummary application;
  final int? minCombatPower;
  final bool canDecide;
  final bool submitting;
  final ClassSynergyService? synergyService;
  final ValueChanged<PartyApplicationSummary> onApprove;
  final ValueChanged<PartyApplicationSummary> onReject;

  List<String> _synergyLabels() {
    final service = synergyService;
    if (service == null) return const [];
    final role = application.requestedRole == PartyRole.support
        ? GameCatalogRole.support
        : GameCatalogRole.dealer;
    return service.alwaysPrimaryLabels(
      className: application.className,
      role: role,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemLevel = application.itemLevel;
    final combatPower = application.combatPower;
    final synergies = _synergyLabels();
    final combatPowerDecision = const MinimumCombatPowerPolicy().evaluate(
      minimum: minCombatPower,
      actual: combatPower,
    );
    final canApprove = canDecide && combatPowerDecision.isAllowed;
    final combatPowerFailureText = switch (combatPowerDecision) {
      MinimumCombatPowerDecision.missing =>
        '전투력 정보가 없어 승인할 수 없습니다. 신청을 거절해 주세요.',
      MinimumCombatPowerDecision.belowMinimum =>
        '최소 전투력을 충족하지 않아 승인할 수 없습니다. '
        '신청을 거절해 주세요.',
      MinimumCombatPowerDecision.unrestricted ||
      MinimumCombatPowerDecision.satisfied => null,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
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
            Text(
              [
                if (itemLevel != null)
                  '아이템 Lv. ${DisplayNumberFormatter.integer(itemLevel)}'
                else
                  '아이템 레벨 미확인',
                if (combatPower != null)
                  '전투력 ${DisplayNumberFormatter.integer(combatPower)}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (synergies.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '시너지 ${synergies.join(' · ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            if (application.buildIntegrity case final integrity?) ...[
              const SizedBox(height: 2),
              BuildIntegrityStatusLine(
                snapshot: integrity,
                keyName:
                    'applicationBuildIntegrity-${application.applicantPlayerId}',
              ),
            ] else if (application.gemValidation case final validation?) ...[
              const SizedBox(height: 2),
              GemValidationLine(
                validation: validation,
                keyName: 'applicationGemValidation',
              ),
            ],
            const SizedBox(height: 4),
            const Text('파티장 승인 대기'),
            if (combatPowerFailureText != null) ...[
              const SizedBox(height: 4),
              Text(
                combatPowerFailureText,
                key: ValueKey(
                  'applicationCombatPowerFailure-${application.applicantPlayerId}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
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
                      onPressed: submitting || !canApprove
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
    this.gemValidation,
    this.buildIntegrity,
  });

  final String serverCharacterId;
  final PartyRole role;
  final double? combatPower;
  final PartyGemValidationSnapshot? gemValidation;
  final BuildIntegritySnapshot? buildIntegrity;
}

class _CycleLifecycleSection extends StatelessWidget {
  const _CycleLifecycleSection({
    required this.summary,
    required this.cycle,
    required this.isLeader,
    required this.submitting,
    required this.onComplete,
    required this.onToggleRecurrence,
    required this.onDisband,
  });

  final PublicRecruitmentSummary summary;
  final PartyCycleSnapshot? cycle;
  final bool isLeader;
  final bool submitting;
  final VoidCallback onComplete;
  final ValueChanged<bool> onToggleRecurrence;
  final VoidCallback onDisband;

  @override
  Widget build(BuildContext context) {
    final canComplete =
        isLeader && summary.isActiveRecruitment && summary.isCycleActive;
    final showDisband =
        isLeader &&
        (summary.isOneShotCompleted ||
            summary.memberCount > 1 ||
            (summary.isActiveRecruitment && summary.isCycleCompleted));
    final canToggleRecurrence =
        isLeader &&
        summary.isActiveRecruitment &&
        (summary.isCycleActive || summary.isCycleCompleted);

    if (!canComplete && !showDisband && !canToggleRecurrence) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('회차·방 관리', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          if (canToggleRecurrence) ...[
            SwitchListTile(
              key: const ValueKey('continueTogetherSwitch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('다음 주도 함께하기'),
              subtitle: Text(
                summary.continueTogether
                    ? '완료 후에도 방과 구성을 유지합니다.'
                    : '1회성으로 완료·해산합니다.',
              ),
              value: summary.continueTogether,
              onChanged: submitting
                  ? null
                  : (value) => onToggleRecurrence(value),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (canComplete)
            FilledButton.icon(
              key: const ValueKey('completeCycleButton'),
              onPressed: submitting ? null : onComplete,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('파티 전체 완료'),
            ),
          if (showDisband) ...[
            if (canComplete) const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: const ValueKey('disbandPartyButton'),
              onPressed: submitting ? null : onDisband,
              icon: const Icon(Icons.meeting_room_outlined),
              label: Text(summary.isOneShotCompleted ? '해산' : '파티 해산'),
            ),
          ],
        ],
      ),
    );
  }
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

class _LostGroupQualificationSection extends StatelessWidget {
  const _LostGroupQualificationSection({
    required this.members,
    required this.submitting,
    required this.onRemove,
  });

  final List<PartyMemberDisplay> members;
  final bool submitting;
  final ValueChanged<PartyMemberDisplay> onRemove;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('그룹 자격 상실', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '그룹을 떠난 파티원은 그룹 전용 레이드 참가 자격을 잃었습니다. 정상 참가 그룹원만 정리할 수 있습니다.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final member in members)
            Card(
              key: ValueKey('lostGroupQualificationCard-${member.playerId}'),
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                title: Text(
                  member.characterName?.trim().isNotEmpty == true
                      ? member.characterName!.trim()
                      : '정보 없음',
                ),
                subtitle: const Text('그룹 탈퇴'),
                trailing: TextButton(
                  key: ValueKey(
                    'removeLostGroupQualificationButton-${member.playerId}',
                  ),
                  onPressed: submitting ? null : () => onRemove(member),
                  child: const Text('정리'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChangeCharacterCandidateSheet extends StatelessWidget {
  const _ChangeCharacterCandidateSheet({required this.entries});

  final List<
    ({RecruitmentLeaderCandidate candidate, RecruitmentLeaderRoleOption option})
  >
  entries;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('변경할 캐릭터와 역할')),
          for (final entry in entries)
            ListTile(
              key: ValueKey(
                'change-candidate-${entry.candidate.localCharacterId}-${entry.option.role.name}',
              ),
              title: Text(entry.candidate.characterId),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.candidate.accountLabel} · ${entry.candidate.className} · '
                    '${_roleLabel(entry.option.role)}',
                  ),
                  if (entry.option.buildIntegrity case final integrity?) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    BuildIntegrityStatusLine(
                      snapshot: integrity,
                      keyName:
                          'changeCandidateBuildIntegrity-${entry.candidate.localCharacterId}-${entry.option.role.name}',
                    ),
                  ],
                ],
              ),
              onTap: () => Navigator.pop(
                context,
                _ApplySelection(
                  serverCharacterId: entry.candidate.serverCharacterId!,
                  role: entry.option.role,
                  combatPower: entry.option.combatPower,
                  gemValidation: entry.option.gemValidation,
                  buildIntegrity: entry.option.buildIntegrity,
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
            for (final option in candidate.roles.where(
              (role) => role.canSelect,
            ))
              ListTile(
                key: ValueKey(
                  'apply-candidate-${candidate.localCharacterId}-${option.role.name}',
                ),
                title: Text(candidate.characterId),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${candidate.accountLabel} · ${candidate.className} · '
                      '${_roleLabel(option.role)} · 아이템 Lv. '
                      '${DisplayNumberFormatter.integer(option.itemLevel ?? 0)}',
                    ),
                    if (option.buildIntegrity case final integrity?) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      BuildIntegrityStatusLine(
                        snapshot: integrity,
                        keyName:
                            'applyCandidateBuildIntegrity-${candidate.localCharacterId}-${option.role.name}',
                      ),
                    ],
                  ],
                ),
                onTap: () => Navigator.pop(
                  context,
                  _ApplySelection(
                    serverCharacterId: candidate.serverCharacterId!,
                    role: option.role,
                    combatPower: option.combatPower,
                    gemValidation: option.gemValidation,
                    buildIntegrity: option.buildIntegrity,
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
      PartyApplicationFailure.minimumCombatPowerNotMet =>
        '선택한 캐릭터가 모집 최소 전투력을 충족하지 않습니다.',
      PartyApplicationFailure.weeklyRaidCompleted =>
        '이 캐릭터는 이번 주 동일 레이드를 이미 완료했습니다.',
      PartyApplicationFailure.participationConflict =>
        '이미 동일 레이드에 참가 중이어서 신청할 수 없습니다.',
      PartyApplicationFailure.orphanedParticipation =>
        '종료되거나 삭제된 파티의 참가 기록 정리가 필요합니다.',
      PartyApplicationFailure.stateInconsistent =>
        '이 캐릭터의 참가·완료 기록을 안전하게 확인할 수 없습니다.',
      PartyApplicationFailure.recruitmentClosed => '모집이 마감되어 신청할 수 없습니다.',
      PartyApplicationFailure.approvalModeMismatch => '이 방은 신청 방식이 다릅니다.',
      PartyApplicationFailure.capacityFull => '모집 정원이 가득 찼습니다.',
      PartyApplicationFailure.alreadyMember => '이미 이 방의 멤버입니다.',
      PartyApplicationFailure.applicationAlreadyExists => '이미 이 방에 신청했습니다.',
      PartyApplicationFailure.applicationNotPending => '철회할 수 있는 신청이 아닙니다.',
      PartyApplicationFailure.revisionConflict => '신청 상태가 바뀌었습니다. 다시 확인해 주세요.',
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
  PartyJoinFailure.minimumCombatPowerNotMet =>
    '모집 최소 전투력을 충족하지 않아 참가할 수 없습니다.',
  PartyJoinFailure.weeklyRaidCompleted => '이 캐릭터는 이번 주 동일 레이드를 이미 완료했습니다.',
  PartyJoinFailure.recruitmentClosed => '모집이 마감되어 참가할 수 없습니다.',
  PartyJoinFailure.approvalModeMismatch => '이 방은 가입 방식이 다릅니다.',
  PartyJoinFailure.capacityFull ||
  PartyJoinFailure.roleCapacityFull => '모집 정원이 가득 찼습니다.',
  PartyJoinFailure.duplicateDealerClass => '같은 파티에 동일 직업 딜러가 이미 있습니다.',
  PartyJoinFailure.alreadyMember => '이미 이 방의 멤버입니다.',
  PartyJoinFailure.applicationNotPending => '처리할 수 있는 신청이 아닙니다.',
  PartyJoinFailure.participationConflict =>
    '이미 확정된 참가 또는 겹치는 일정이 있어 가입할 수 없습니다.',
  PartyJoinFailure.orphanedParticipation =>
    '종료되거나 삭제된 파티의 참가 기록 정리가 필요합니다.',
  PartyJoinFailure.stateInconsistent =>
    '이 캐릭터의 참가·완료 기록을 안전하게 확인할 수 없습니다.',
  PartyJoinFailure.revisionConflict => '상태가 바뀌었습니다. 다시 확인해 주세요.',
  PartyJoinFailure.permissionDenied => '가입 권한을 확인하지 못했습니다.',
  PartyJoinFailure.temporarilyUnavailable => '네트워크 연결이 불안정합니다.',
  PartyJoinFailure.invalidRequest => '가입 정보를 확인하지 못했습니다.',
  PartyJoinFailure.unknown => '가입을 처리하지 못했습니다.',
};

String _orphanedParticipationMessage(
  PartyOrphanedRaidParticipation orphan,
) => orphan.isHistorical
    ? '지난 주차의 종료되거나 삭제된 파티 참가 기록이 남아 있습니다.'
    : '종료되거나 삭제된 파티의 참가 기록이 남아 있습니다.';

String _orphanCleanupFailureMessage(WeeklyRaidClaimCommandFailure failure) =>
    switch (failure) {
      WeeklyRaidClaimCommandFailure.activeAssignment =>
        '아직 활성 파티에 참가 중이어서 기록을 정리할 수 없습니다.',
      WeeklyRaidClaimCommandFailure.stateInconsistent =>
        '이 캐릭터의 참가 기록을 안전하게 정리할 수 없습니다.',
      WeeklyRaidClaimCommandFailure.permissionDenied =>
        '참가 기록을 정리할 권한을 확인하지 못했습니다.',
      WeeklyRaidClaimCommandFailure.temporarilyUnavailable =>
        '네트워크 연결이 불안정합니다.',
      WeeklyRaidClaimCommandFailure.unauthenticated ||
      WeeklyRaidClaimCommandFailure.invalidRequest ||
      WeeklyRaidClaimCommandFailure.pendingApplication ||
      WeeklyRaidClaimCommandFailure.orphanedParticipation ||
      WeeklyRaidClaimCommandFailure.unknown =>
        '참가 기록을 정리하지 못했습니다.',
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
      PartyMembershipFailure.minimumCombatPowerNotMet =>
        '변경할 캐릭터가 모집 최소 전투력을 충족하지 않습니다.',
      PartyMembershipFailure.weeklyRaidCompleted =>
        '이 캐릭터는 이번 주 동일 레이드를 이미 완료했습니다.',
      PartyMembershipFailure.recruitmentClosed => '이미 종료된 모집입니다.',
      PartyMembershipFailure.alreadyCurrentCharacter => '이미 참가 중인 캐릭터입니다.',
      PartyMembershipFailure.participationConflict =>
        '다른 확정 참가와 충돌합니다. 캐릭터를 다시 선택해 주세요.',
      PartyMembershipFailure.orphanedParticipation =>
        '종료되거나 삭제된 파티의 참가 기록 정리가 필요합니다.',
      PartyMembershipFailure.stateInconsistent =>
        '이 캐릭터의 참가·완료 기록을 안전하게 확인할 수 없습니다.',
      PartyMembershipFailure.roleMismatch ||
      PartyMembershipFailure.invalidComposition => '현재 파티 구성과 맞지 않는 캐릭터입니다.',
      PartyMembershipFailure.revisionConflict => '모집 상태가 바뀌었습니다. 다시 확인해 주세요.',
      PartyMembershipFailure.unsupportedOnSpark => '현재 환경에서 지원하지 않는 동작입니다.',
      PartyMembershipFailure.permissionDenied => '권한을 확인하지 못했습니다.',
      PartyMembershipFailure.temporarilyUnavailable => '네트워크 연결이 불안정합니다.',
      PartyMembershipFailure.invalidRequest => '요청을 확인하지 못했습니다.',
      PartyMembershipFailure.unknown => '멤버 명령을 처리하지 못했습니다.',
    };

String _cycleFailureMessage(PartyCycleFailure failure) => switch (failure) {
  PartyCycleFailure.unauthenticated ||
  PartyCycleFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
  PartyCycleFailure.notFound => '모집 정보를 찾지 못했습니다.',
  PartyCycleFailure.unauthorized => '이 동작을 할 권한이 없습니다.',
  PartyCycleFailure.recruitmentClosed => '이미 종료된 모집입니다.',
  PartyCycleFailure.cycleMismatch => '회차 정보가 바뀌었습니다. 다시 확인해 주세요.',
  PartyCycleFailure.alreadyCompleted => '이미 완료된 회차입니다.',
  PartyCycleFailure.notReadyForAdvance => '아직 다음 회차로 전환할 수 없습니다.',
  PartyCycleFailure.revisionConflict => '모집 상태가 바뀌었습니다. 다시 확인해 주세요.',
  PartyCycleFailure.permissionDenied =>
    '권한을 확인하지 못했습니다. 잠시 후 다시 시도하거나 Rules 배포 상태를 확인해 주세요.',
  PartyCycleFailure.temporarilyUnavailable => '네트워크 연결이 불안정합니다.',
  PartyCycleFailure.invalidRequest => '요청을 확인하지 못했습니다.',
  PartyCycleFailure.unknown => '회차 명령을 처리하지 못했습니다.',
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
