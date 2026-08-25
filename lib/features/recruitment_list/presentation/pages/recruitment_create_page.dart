import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/policies/raid_eligibility_policy.dart';
import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/entities/party_create_command.dart';
import '../../domain/policies/approval_policy.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/policies/party_cycle_policy.dart';
import '../../domain/policies/recruitment_auto_title_policy.dart';
import '../../domain/repositories/party_create_repository.dart';
import '../../domain/services/recruitment_command_service.dart';
import '../../domain/services/recruitment_application_candidate_service.dart';
import '../../domain/services/recruitment_leader_candidate_service.dart';
import '../../domain/state/recruitment_state_machine.dart';
import '../models/candidate_build_display_model.dart';
import '../models/recruitment_form_draft.dart';
import '../widgets/recruitment_form.dart';

class RecruitmentCreatePage extends StatefulWidget {
  const RecruitmentCreatePage({
    required this.catalogRepository,
    required this.commandService,
    required this.candidateService,
    this.partyCreateRepository,
    this.newRecruitmentId,
    this.cycleKey,
    super.key,
  });
  final RaidCatalogRepository catalogRepository;
  final RecruitmentCommandService commandService;
  final RecruitmentLeaderCandidateService candidateService;
  final PartyCreateRepository? partyCreateRepository;
  final String Function()? newRecruitmentId;
  final String? cycleKey;
  @override
  State<RecruitmentCreatePage> createState() => _RecruitmentCreatePageState();
}

class _RecruitmentCreatePageState extends State<RecruitmentCreatePage> {
  static const _eligibilityPolicy = RaidEligibilityPolicy();
  static const _autoTitlePolicy = RecruitmentAutoTitlePolicy();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _combatPower = TextEditingController();
  RaidCatalog? _catalog;
  List<RecruitmentLeaderCandidate> _candidates = const [];
  RecruitmentLeaderCandidate? _leader;
  RaidDefinition? _raid;
  RaidDifficultyDefinition? _difficulty;
  PartyRole _role = PartyRole.dealer;
  RecruitmentFormDraft _draft = const RecruitmentFormDraft.empty();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  double? get _selectedItemLevel => _leader?.optionFor(_role)?.itemLevel;

  List<EligibleRaidOption> get _eligibleRaidOptions {
    final catalog = _catalog;
    if (catalog == null) return const [];
    return _eligibilityPolicy.eligibleRaids(
      catalog: catalog,
      itemLevel: _selectedItemLevel,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _combatPower.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final catalog = await widget.catalogRepository.loadCatalog();
      final raid = catalog.raids.where((raid) => raid.isActive).first;
      final difficulty = raid.difficulties.where((item) => item.isActive).first;
      final candidates = await _loadCandidates(raid, difficulty);
      final leader = candidates
          .where(
            (candidate) => candidate.isRepresentative && candidate.canSelect,
          )
          .firstOrNull;
      final role =
          leader?.roles.where((role) => role.canSelect).firstOrNull?.role ??
          PartyRole.dealer;
      final eligible = _eligibilityPolicy.eligibleRaids(
        catalog: catalog,
        itemLevel: leader?.optionFor(role)?.itemLevel,
      );
      final selectedRaid = eligible
          .where((option) => option.raid.raidId == raid.raidId)
          .firstOrNull;
      final selectedOption = selectedRaid ?? eligible.firstOrNull;
      final selectedDifficulty =
          selectedOption?.highestDifficulty ?? difficulty;
      final refreshedCandidates = selectedOption == null
          ? candidates
          : await _loadCandidates(selectedOption.raid, selectedDifficulty);
      final refreshedLeader = refreshedCandidates
          .where((candidate) => candidate.characterId == leader?.characterId)
          .firstOrNull;
      setState(() {
        _catalog = catalog;
        _candidates = refreshedCandidates;
        _leader = refreshedLeader ?? leader;
        _role = role;
        _raid = selectedOption?.raid ?? raid;
        _difficulty = selectedDifficulty;
        _draft = _draft.copyWith(
          raidId: (selectedOption?.raid ?? raid).raidId,
          difficultyId: selectedDifficulty.difficultyId,
        );
        _loading = false;
      });
      _syncAutoTitle(force: true);
    } catch (_) {
      setState(() {
        _loadError = '모집 생성 정보를 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('모집 만들기')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Center(child: Text(_loadError!))
        : Form(
            key: _formKey,
            child: RecruitmentForm(
              titleController: _title,
              combatPowerController: _combatPower,
              draft: _draft,
              raidOptions: _eligibleRaidOptions,
              selectedRaid: _raid!,
              selectedDifficulty: _difficulty!,
              beforeFields: [_leaderSelector(), const SizedBox(height: 16)],
              selectedRole: _role,
              roleOptions:
                  _leader?.roles
                      .where((option) => option.canSelect)
                      .map((option) => option.role)
                      .toList(growable: false) ??
                  const [],
              raidErrorText: _leader != null && _eligibleRaidOptions.isEmpty
                  ? '선택 캐릭터가 입장 가능한 레이드가 없습니다.'
                  : null,
              onTitleChanged: (value) {
                final usesAutoTitle = value.trim().isEmpty;
                _draft = _draft.copyWith(
                  title: value,
                  usesAutoTitle: usesAutoTitle,
                );
              },
              onRaidChanged: _changeRaid,
              onDifficultyChanged: _changeDifficulty,
              onRoleChanged: _changeRole,
              onCombatPowerChanged: (value) {
                _draft = _draft.copyWith(
                  minCombatPower: RecruitmentFormDraft.normalizeMinCombatPower(
                    value,
                  ),
                );
                _syncAutoTitle();
              },
              onExperienceChanged: (value) {
                setState(() {
                  _draft = _draft.copyWith(experienceLevel: value);
                });
                _syncAutoTitle();
              },
              onApprovalChanged: (value) {
                setState(() => _draft = _draft.copyWith(approvalMode: value));
              },
              onSubmit: _save,
              submitLabel: '모집 생성',
              submitting: _saving,
            ),
          ),
  );

  int? get _normalizedMinCombatPower => _draft.minCombatPower;

  String get _generatedTitle => _autoTitlePolicy.build(
    difficultyAlias: _difficulty?.displayAlias ?? '',
    experienceLevel: _draft.experienceLevel,
    minCombatPower: _normalizedMinCombatPower,
  );

  void _syncAutoTitle({bool force = false}) {
    if (!_draft.usesAutoTitle) return;
    if (!force && _title.text.isEmpty) return;
    final title = _generatedTitle;
    if (_title.text == title) return;
    _title.value = TextEditingValue(
      text: title,
      selection: TextSelection.collapsed(offset: title.length),
    );
    _draft = _draft.copyWith(title: title);
  }

  Future<List<RecruitmentLeaderCandidate>> _loadCandidates(
    RaidDefinition raid,
    RaidDifficultyDefinition difficulty,
  ) => widget.candidateService.load(
    RecruitmentLeaderCandidateQuery(
      raidId: raid.raidId,
      difficultyId: difficulty.difficultyId,
      minItemLevel: difficulty.minItemLevel,
      startAt: widget.candidateService.clock.now(),
      maxPlayHours: null,
    ),
  );

  Future<void> _changeRaid(RaidDefinition raid) async {
    final option = _eligibleRaidOptions.firstWhere(
      (option) => option.raid.raidId == raid.raidId,
    );
    final difficulty = option.highestDifficulty;
    setState(() {
      _raid = raid;
      _difficulty = difficulty;
      _draft = _draft.copyWith(
        raidId: raid.raidId,
        difficultyId: difficulty.difficultyId,
      );
    });
    _syncAutoTitle();
    await _refreshCandidates();
  }

  Future<void> _changeDifficulty(RaidDifficultyDefinition difficulty) async {
    setState(() {
      _difficulty = difficulty;
      _draft = _draft.copyWith(difficultyId: difficulty.difficultyId);
    });
    _syncAutoTitle();
    await _refreshCandidates();
  }

  Future<void> _changeRole(PartyRole role) async {
    setState(() => _role = role);
    await _refreshRaidSelectionForLeader();
  }

  Future<void> _refreshRaidSelectionForLeader() async {
    final options = _eligibleRaidOptions;
    if (options.isEmpty) {
      setState(() {});
      return;
    }
    final option =
        options
            .where((option) => option.raid.raidId == _raid?.raidId)
            .firstOrNull ??
        options.first;
    final eligibleDifficulty = option.difficulties
        .where((item) => item.difficultyId == _difficulty?.difficultyId)
        .firstOrNull;
    setState(() {
      _raid = option.raid;
      _difficulty = eligibleDifficulty ?? option.highestDifficulty;
      _draft = _draft.copyWith(
        raidId: option.raid.raidId,
        difficultyId:
            (eligibleDifficulty ?? option.highestDifficulty).difficultyId,
      );
    });
    _syncAutoTitle();
    await _refreshCandidates();
  }

  Future<void> _refreshCandidates() async {
    final selectedCharacterId = _leader?.characterId;
    final candidates = await _loadCandidates(_raid!, _difficulty!);
    if (!mounted) return;
    final selected = candidates
        .where((candidate) => candidate.characterId == selectedCharacterId)
        .firstOrNull;
    setState(() {
      _candidates = candidates;
      _leader = selected;
      if (selected?.optionFor(_role)?.canSelect != true) {
        _role =
            selected?.roles
                .where((option) => option.canSelect)
                .firstOrNull
                ?.role ??
            _role;
      }
    });
  }

  Widget _leaderSelector() {
    final leader = _leader;
    return InkWell(
      key: const ValueKey('leaderCandidateSelector'),
      onTap: _showLeaderCandidates,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '파티장 캐릭터',
          border: const OutlineInputBorder(),
          errorText: leader == null
              ? '참가할 캐릭터를 선택해주세요.'
              : leader.canSelect
              ? null
              : '현재 레이드 조건을 만족하지 않습니다. 다시 선택해주세요.',
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Text(
          leader == null
              ? '캐릭터 선택'
              : '${leader.accountLabel} · ${leader.characterId} (${leader.className})',
        ),
      ),
    );
  }

  Future<void> _showLeaderCandidates() async {
    final selected = await showModalBottomSheet<RecruitmentLeaderCandidate>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('파티장 캐릭터 선택', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('표시 중인 캐릭터가 없습니다.')),
                ),
              ..._candidateTiles(context),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final role = selected.roles
        .where((option) => _hasEligibleRaid(option.itemLevel))
        .first
        .role;
    setState(() {
      _leader = selected;
      _role = role;
    });
    await _refreshRaidSelectionForLeader();
  }

  List<Widget> _candidateTiles(BuildContext context) {
    final widgets = <Widget>[];
    int? previousAccountId;
    for (final candidate in _candidates) {
      if (candidate.accountId != previousAccountId) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              '${candidate.accountLabel}${candidate.isMainAccount ? ' · 본계정' : ' · 부계정'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
        previousAccountId = candidate.accountId;
      }
      final hasPending = candidate.participationStatuses.any(
        (status) =>
            status.type == CandidateParticipationStatusType.pendingSameRaid,
      );
      final canChoose = _canChooseCandidate(candidate);
      final borderColor = canChoose
          ? hasPending
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.outlineVariant
          : Theme.of(context).colorScheme.error;
      widgets.add(
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
          child: ListTile(
            key: ValueKey('leader-candidate-${candidate.characterId}'),
            enabled: canChoose,
            leading: Icon(
              canChoose ? Icons.person : Icons.block,
              color: canChoose ? null : Theme.of(context).colorScheme.error,
            ),
            title: Text('${candidate.characterId} · ${candidate.className}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_candidateDescription(candidate)),
                if (candidate.participationStatuses.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final status in candidate.participationStatuses)
                        _participationChip(context, status),
                    ],
                  ),
                ],
              ],
            ),
            trailing: candidate.isRepresentative
                ? const Chip(label: Text('대표'))
                : null,
            onTap: canChoose ? () => Navigator.pop(context, candidate) : null,
          ),
        ),
      );
    }
    return widgets;
  }

  bool _canChooseCandidate(RecruitmentLeaderCandidate candidate) =>
      !candidate.participationStatuses.any(
        (status) =>
            status.type ==
                CandidateParticipationStatusType.overlappingSchedule ||
            status.type == CandidateParticipationStatusType.uncertainSchedule,
      ) &&
      candidate.roles.any((option) => _hasEligibleRaid(option.itemLevel));

  bool _hasEligibleRaid(double? itemLevel) {
    final catalog = _catalog;
    if (catalog == null) return false;
    return _eligibilityPolicy
        .eligibleRaids(catalog: catalog, itemLevel: itemLevel)
        .isNotEmpty;
  }

  Widget _participationChip(
    BuildContext context,
    CandidateParticipationStatus status,
  ) {
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

  String _candidateDescription(RecruitmentLeaderCandidate candidate) {
    final roles = candidate.roles
        .map((option) {
          return CandidateBuildDisplayModel(
            role: option.role,
            itemLevel: option.itemLevel,
            combatPower: option.combatPower,
            minCombatPower: _normalizedMinCombatPower,
          ).label;
        })
        .join(' · ');
    final reasons = [
      ...candidate.rejectionReasons,
      ...candidate.roles.expand((option) => option.rejectionReasons),
    ];
    return [
      candidate.accountLabel,
      candidate.serverName,
      roles,
      ...reasons,
    ].where((value) => value.isNotEmpty).join('\n');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final leader = _leader;
    if (leader == null ||
        !leader.canSelect ||
        leader.optionFor(_role)?.canSelect != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('참가 가능한 파티장 캐릭터와 역할을 선택해주세요.')),
      );
      return;
    }
    final raid = _raid!;
    final difficulty = _difficulty!;
    var cancelPendingApplications = false;
    if (widget.partyCreateRepository == null) {
      final pendingCount = await widget.commandService.countPendingApplications(
        characterId: leader.characterId,
        raidId: raid.raidId,
      );
      if (!mounted) return;
      if (pendingCount > 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('기존 신청을 취소할까요?'),
            content: Text(
              '${leader.characterId} 캐릭터의 동일 레이드 신청 $pendingCount건이 있습니다. '
              '모집을 만들면 기존 신청이 모두 종료됩니다.',
            ),
            actions: [
              TextButton(
                key: const ValueKey('keepPendingAndCancelCreationButton'),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('돌아가기'),
              ),
              FilledButton(
                key: const ValueKey('cancelPendingAndCreateButton'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('신청 취소하고 생성'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        cancelPendingApplications = true;
      }
    }
    setState(() => _saving = true);
    final approval = switch (_draft.approvalMode) {
      ApprovalMode.leaderOnly => const ApprovalPolicy.leaderOnly(),
      ApprovalMode.directJoin => const ApprovalPolicy.directJoin(),
      ApprovalMode.anyMember ||
      ApprovalMode.quorum => throw StateError('현재 생성 화면에서 지원하지 않는 승인 방식입니다.'),
    };
    final title = _title.text.trim().isEmpty
        ? _generatedTitle
        : _title.text.trim();
    final metadata = RecruitmentMetadata(
      catalogVersion: _catalog!.catalogVersion,
      raidId: raid.raidId,
      difficultyId: difficulty.difficultyId,
      raidName: raid.displayName,
      difficultyName: difficulty.name,
      difficultyAlias: difficulty.displayAlias,
      gateCount: raid.gateCount,
      minItemLevel: difficulty.minItemLevel,
      minCombatPower: _normalizedMinCombatPower,
      experienceLevel: _draft.experienceLevel,
      maxPlayHours: null,
    );
    final partyCreateRepository = widget.partyCreateRepository;
    if (partyCreateRepository != null) {
      await _saveToFirestore(
        repository: partyCreateRepository,
        title: title,
        metadata: metadata,
        leader: leader,
        approval: approval,
        raid: raid,
      );
      return;
    }
    final result = await widget.commandService.createRecruitment(
      title: title,
      metadata: metadata,
      leaderCharacterId: leader.characterId,
      leaderClassName: leader.className,
      leaderRole: _role,
      leaderItemLevel: leader.optionFor(_role)?.itemLevel,
      leaderCombatPower: leader.optionFor(_role)?.combatPower,
      approvalPolicy: approval,
      compositionPolicy: PartyCompositionPolicy(
        RecruitmentPartyRules.fromRaid(raid),
      ),
      cancelPendingApplications: cancelPendingApplications,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      context.pushReplacement('/recruitments/${result.aggregate!.id}');
    } else {
      final message = switch (result.domainFailure) {
        RecruitmentCommandFailure.participationConflict =>
          '이미 확정된 참가 또는 겹치는 일정이 있어 모집을 만들 수 없습니다.',
        RecruitmentCommandFailure.pendingApplicationsRequireConfirmation =>
          '새 신청 상태가 확인되었습니다. 다시 확인 후 생성해주세요.',
        _ => '모집을 생성하지 못했습니다.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _saveToFirestore({
    required PartyCreateRepository repository,
    required String title,
    required RecruitmentMetadata metadata,
    required RecruitmentLeaderCandidate leader,
    required ApprovalPolicy approval,
    required RaidDefinition raid,
  }) async {
    final serverCharacterId = leader.serverCharacterId;
    final itemLevel = leader.optionFor(_role)?.itemLevel;
    if (serverCharacterId == null ||
        serverCharacterId.isEmpty ||
        itemLevel == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게임 계정 인증이 완료된 캐릭터만 모집을 만들 수 있습니다.')),
      );
      return;
    }

    final recruitmentId =
        widget.newRecruitmentId?.call() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final cycleKey =
        widget.cycleKey ?? const PartyCyclePolicy().keyFor(DateTime.now());
    final result = await repository.create(
      PartyCreateCommand(
        recruitmentId: recruitmentId,
        title: title,
        metadata: metadata,
        leaderCharacterId: serverCharacterId,
        leaderCharacterName: leader.characterId,
        leaderClassName: leader.className,
        leaderRole: _role,
        leaderItemLevel: itemLevel,
        leaderCombatPower: leader.optionFor(_role)?.combatPower,
        approvalPolicy: approval,
        compositionRules: RecruitmentPartyRules.fromRaid(raid),
        cycleKey: cycleKey,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      context.go('/raid-status/${result.recruitmentId}');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_createFailureMessage(result.failure!))),
    );
  }
}

String _createFailureMessage(PartyCreateFailure failure) => switch (failure) {
  PartyCreateFailure.unauthenticated ||
  PartyCreateFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
  PartyCreateFailure.ownershipLost => '캐릭터 소유권을 확인하지 못했습니다.',
  PartyCreateFailure.invalidCharacter =>
    '참가할 수 없는 캐릭터입니다. 내 계정에서 정보를 새로고침한 뒤 다시 시도해 주세요.',
  PartyCreateFailure.participationConflict =>
    '이미 확정된 참가 또는 겹치는 일정이 있어 모집을 만들 수 없습니다.',
  PartyCreateFailure.idConflict => '같은 모집이 이미 있습니다. 다시 시도해 주세요.',
  PartyCreateFailure.permissionDenied => '모집 생성 권한을 확인하지 못했습니다.',
  PartyCreateFailure.temporarilyUnavailable => '네트워크 연결이 불안정합니다.',
  PartyCreateFailure.invalidRequest => '입력한 모집 정보를 확인하지 못했습니다.',
  PartyCreateFailure.unknown => '모집을 생성하지 못했습니다.',
};
