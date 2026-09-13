import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/presentation/server_account_mismatch_alert.dart';

import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/policies/raid_eligibility_policy.dart';
import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../../group/domain/entities/group_relation.dart';
import '../../../group/domain/repositories/group_read_repository.dart';
import '../../domain/entities/party_create_command.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/entities/recruitment_aggregate.dart';
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
    this.groupReadRepository,
    this.playerId,
    this.newRecruitmentId,
    this.cycleKey,
    super.key,
  });
  final RaidCatalogRepository catalogRepository;
  final RecruitmentCommandService commandService;
  final RecruitmentLeaderCandidateService candidateService;
  final PartyCreateRepository? partyCreateRepository;
  final GroupReadRepository? groupReadRepository;
  final String? playerId;
  final String Function()? newRecruitmentId;
  final String? cycleKey;
  @override
  State<RecruitmentCreatePage> createState() => _RecruitmentCreatePageState();
}

enum _RaidAudience { general, group }

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
  _RaidAudience _audience = _RaidAudience.general;
  bool _groupOnly = true;
  String? _selectedGroupId;
  List<GroupRelation> _groups = const [];
  bool _groupsLoading = false;
  String? _groupsError;
  StreamSubscription<GroupReadSnapshot<GroupRelation>>? _groupsSubscription;

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
    _listenGroups();
    _load();
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
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
      final role = leader?.resolveSelectedRole() ?? PartyRole.dealer;
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
              beforeFields: [
                _audienceSelector(),
                const SizedBox(height: recruitmentFormFieldGap),
                if (_audience == _RaidAudience.group) ...[
                  _groupSelector(),
                  const SizedBox(height: recruitmentFormFieldGap),
                  CheckboxListTile(
                    key: const ValueKey('groupOnlyVisibilityCheckbox'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('그룹만 공개'),
                    value: _groupOnly,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _groupOnly = value);
                    },
                  ),
                  const SizedBox(height: recruitmentFormFieldGap),
                ],
                _leaderSelector(),
                const SizedBox(height: recruitmentFormFieldGap),
              ],
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

  void _listenGroups() {
    final repository = widget.groupReadRepository;
    final playerId = widget.playerId;
    if (repository == null || playerId == null || playerId.isEmpty) return;
    _groupsLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _groupsSubscription = repository
          .watchMyGroups(playerId)
          .listen(
            (snapshot) {
              if (!mounted) return;
              final groups = snapshot.items
                  .where((item) => item.isMember)
                  .toList(growable: false);
              setState(() {
                _groups = groups;
                _groupsLoading = false;
                _groupsError = null;
                if (_selectedGroupId != null &&
                    !groups.any((group) => group.groupId == _selectedGroupId)) {
                  _selectedGroupId = null;
                }
                if (_audience == _RaidAudience.group &&
                    _selectedGroupId == null &&
                    groups.length == 1) {
                  _selectedGroupId = groups.first.groupId;
                }
              });
            },
            onError: (_) {
              if (!mounted) return;
              setState(() {
                _groups = const [];
                _groupsLoading = false;
                _groupsError = '가입 그룹을 불러오지 못했습니다.';
                _selectedGroupId = null;
              });
            },
          );
    });
  }

  Widget _audienceSelector() => SegmentedButton<_RaidAudience>(
    key: const ValueKey('raidAudienceSelector'),
    segments: const [
      ButtonSegment(value: _RaidAudience.general, label: Text('일반 레이드')),
      ButtonSegment(value: _RaidAudience.group, label: Text('그룹 레이드')),
    ],
    selected: {_audience},
    onSelectionChanged: (selected) {
      final audience = selected.first;
      setState(() {
        _audience = audience;
        if (audience == _RaidAudience.group &&
            _selectedGroupId == null &&
            _groups.length == 1) {
          _selectedGroupId = _groups.first.groupId;
        }
      });
    },
  );

  Widget _groupSelector() {
    if (_groupsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (_groupsError != null) {
      return Text(_groupsError!, key: const ValueKey('groupLoadErrorText'));
    }
    if (_groups.isEmpty) {
      return const Text(
        '가입한 그룹이 없습니다. 그룹에 가입한 뒤에 그룹 레이드를 만들 수 있습니다.',
        key: ValueKey('noJoinedGroupsText'),
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('groupSelect-${_selectedGroupId ?? 'none'}'),
      isExpanded: true,
      initialValue: _groups.any((group) => group.groupId == _selectedGroupId)
          ? _selectedGroupId
          : null,
      decoration: const InputDecoration(
        labelText: '그룹',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final group in _groups)
          DropdownMenuItem(
            value: group.groupId,
            child: Text(
              group.groupNameSnapshot,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) => setState(() => _selectedGroupId = value),
    );
  }

  String? _groupCreateBlockReason() {
    if (_audience != _RaidAudience.group) return null;
    if (widget.partyCreateRepository == null) {
      return '그룹 레이드는 서버에 연결된 뒤에서 만들 수 있습니다.';
    }
    if (_groupsLoading) return '가입 그룹을 불러오는 중입니다.';
    if (_groupsError != null) return _groupsError;
    if (_groups.isEmpty) {
      return '가입한 그룹이 없어 그룹 레이드를 만들 수 없습니다.';
    }
    if (_selectedGroupId == null ||
        !_groups.any((group) => group.groupId == _selectedGroupId)) {
      return '그룹을 선택해주세요.';
    }
    return null;
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
      _role = selected?.resolveSelectedRole(current: _role) ?? _role;
    });
  }

  Widget _leaderSelector() {
    final leader = _leader;
    final selectableRoles = leader?.selectableRoles ?? const <PartyRole>[];
    final characterField = InkWell(
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
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    if (selectableRoles.length < 2) return characterField;
    return RecruitmentFormPairRow(
      startFlex: 7,
      endFlex: 3,
      wrapBelow: 300,
      start: characterField,
      end: Semantics(
        label: '파티장 역할',
        child: DropdownButtonFormField<PartyRole>(
          key: ValueKey('leaderRole-${_role.name}'),
          isExpanded: true,
          initialValue: selectableRoles.contains(_role) ? _role : null,
          decoration: const InputDecoration(
            // 캐릭터 칸과 같은 플로팅 라벨 높이를 맞춘다. 화면에는 보이지 않는다.
            labelText: '\u200B',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final role in selectableRoles)
              DropdownMenuItem(
                value: role,
                child: Text(_roleLabel(role), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) _changeRole(value);
          },
        ),
      ),
    );
  }

  static String _roleLabel(PartyRole role) =>
      role == PartyRole.support ? '서포터' : '딜러';

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
    setState(() {
      _leader = selected;
      _role = selected.resolveSelectedRole(
        usable: (option) => _hasEligibleRaid(option.itemLevel),
      );
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
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final groupBlock = _groupCreateBlockReason();
    if (groupBlock != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(groupBlock)));
      return;
    }
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
    final selectedOption = leader.optionFor(_role)!;
    if ((selectedOption.itemLevel ?? 0) < difficulty.minItemLevel ||
        (_normalizedMinCombatPower != null &&
            (selectedOption.combatPower ?? 0) < _normalizedMinCombatPower!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 캐릭터가 모집 최소 조건을 충족하지 않습니다.')),
      );
      return;
    }
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
        selectedOption: selectedOption,
      );
      return;
    }
    final result = await widget.commandService.createRecruitment(
      title: title,
      metadata: metadata,
      leaderCharacterId: leader.characterId,
      leaderClassName: leader.className,
      leaderRole: _role,
      leaderItemLevel: selectedOption.itemLevel,
      leaderCombatPower: selectedOption.combatPower,
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
    required RecruitmentLeaderRoleOption selectedOption,
  }) async {
    final serverCharacterId = leader.serverCharacterId;
    final itemLevel = selectedOption.itemLevel;
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
        leaderCombatPower: selectedOption.combatPower,
        leaderGemValidation: selectedOption.gemValidation,
        leaderBuildIntegrity: selectedOption.buildIntegrity,
        approvalPolicy: approval,
        compositionRules: RecruitmentPartyRules.fromRaid(raid),
        cycleKey: cycleKey,
        groupId: _audience == _RaidAudience.group ? _selectedGroupId : null,
        visibility: _audience == _RaidAudience.group && _groupOnly
            ? RecruitmentVisibility.group
            : RecruitmentVisibility.public,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      context.go('/raid-status/${result.recruitmentId}');
      return;
    }
    final failure = result.failure!;
    if (_isServerAccountMismatch(failure)) {
      await showServerAccountMismatchAlert(context);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_createFailureMessage(failure))));
  }
}

String _createFailureMessage(PartyCreateFailure failure) => switch (failure) {
  PartyCreateFailure.unauthenticated ||
  PartyCreateFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
  PartyCreateFailure.serverDataMissing => '서버에서 캐릭터 정보를 찾지 못했습니다.',
  PartyCreateFailure.ownershipLost => '캐릭터 소유권을 확인하지 못했습니다.',
  PartyCreateFailure.invalidCharacter =>
    '참가할 수 없는 캐릭터입니다. 내 계정에서 정보를 새로고침한 뒤 다시 시도해 주세요.',
  PartyCreateFailure.weeklyRaidCompleted => '이 캐릭터는 이번 주 동일 레이드를 이미 완료했습니다.',
  PartyCreateFailure.participationConflict =>
    '이미 확정된 참가 또는 겹치는 일정이 있어 모집을 만들 수 없습니다.',
  PartyCreateFailure.idConflict => '같은 모집이 이미 있습니다. 다시 시도해 주세요.',
  PartyCreateFailure.notGroupMember => '선택한 그룹에 가입되어 있지 않아 그룹 레이드를 만들 수 없습니다.',
  PartyCreateFailure.permissionDenied => '모집 생성 권한을 확인하지 못했습니다.',
  PartyCreateFailure.temporarilyUnavailable => '네트워크 연결이 불안정합니다.',
  PartyCreateFailure.invalidRequest => '입력한 모집 정보를 확인하지 못했습니다.',
  PartyCreateFailure.unknown => '모집을 생성하지 못했습니다.',
};

bool _isServerAccountMismatch(PartyCreateFailure failure) => switch (failure) {
  PartyCreateFailure.unauthenticated ||
  PartyCreateFailure.playerBindingMissing ||
  PartyCreateFailure.serverDataMissing ||
  PartyCreateFailure.ownershipLost => true,
  _ => false,
};
