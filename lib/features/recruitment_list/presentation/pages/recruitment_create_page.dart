import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/policies/approval_policy.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/services/recruitment_command_service.dart';
import '../../domain/services/recruitment_application_candidate_service.dart';
import '../../domain/services/recruitment_leader_candidate_service.dart';
import '../../domain/state/recruitment_state_machine.dart';

class RecruitmentCreatePage extends StatefulWidget {
  const RecruitmentCreatePage({
    required this.catalogRepository,
    required this.commandService,
    required this.candidateService,
    super.key,
  });
  final RaidCatalogRepository catalogRepository;
  final RecruitmentCommandService commandService;
  final RecruitmentLeaderCandidateService candidateService;
  @override
  State<RecruitmentCreatePage> createState() => _RecruitmentCreatePageState();
}

class _RecruitmentCreatePageState extends State<RecruitmentCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _combatPower = TextEditingController();
  RaidCatalog? _catalog;
  List<RecruitmentLeaderCandidate> _candidates = const [];
  RecruitmentLeaderCandidate? _leader;
  RaidDefinition? _raid;
  RaidDifficultyDefinition? _difficulty;
  PartyRole _role = PartyRole.dealer;
  ExperienceLevel? _experience;
  ApprovalMode _approval = ApprovalMode.leaderOnly;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
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
      setState(() {
        _catalog = catalog;
        _candidates = candidates;
        _leader = leader;
        _role =
            leader?.roles.where((role) => role.canSelect).firstOrNull?.role ??
            PartyRole.dealer;
        _raid = raid;
        _difficulty = difficulty;
        _loading = false;
      });
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _leaderSelector(),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('recruitmentTitleField'),
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: '모집 제목',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '모집 제목을 입력해주세요.'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<RaidDefinition>(
                  initialValue: _raid,
                  decoration: const InputDecoration(
                    labelText: '레이드',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final raid in _catalog!.raids.where(
                      (item) => item.isActive,
                    ))
                      DropdownMenuItem(
                        value: raid,
                        child: Text(raid.displayName),
                      ),
                  ],
                  onChanged: (raid) => _changeRaid(raid!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<RaidDifficultyDefinition>(
                  key: ValueKey(_raid!.raidId),
                  initialValue: _difficulty,
                  decoration: const InputDecoration(
                    labelText: '난이도',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in _raid!.difficulties.where(
                      (item) => item.isActive,
                    ))
                      DropdownMenuItem(
                        value: item,
                        child: Text('${item.name} (${item.displayAlias})'),
                      ),
                  ],
                  onChanged: (value) => _changeDifficulty(value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PartyRole>(
                  initialValue: _leader?.optionFor(_role)?.canSelect == true
                      ? _role
                      : null,
                  decoration: const InputDecoration(
                    labelText: '파티장 역할',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final option
                        in _leader?.roles.where((option) => option.canSelect) ??
                            const <RecruitmentLeaderRoleOption>[])
                      DropdownMenuItem(
                        value: option.role,
                        child: Text(_roleLabel(option.role)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _role = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('minCombatPowerField'),
                  controller: _combatPower,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '최소 전투력',
                    border: OutlineInputBorder(),
                  ),
                  validator: _positiveInteger,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExperienceLevel?>(
                  initialValue: _experience,
                  decoration: const InputDecoration(
                    labelText: '숙련도',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('제한 없음')),
                    DropdownMenuItem(
                      value: ExperienceLevel.tryLevel,
                      child: Text('트라이'),
                    ),
                    DropdownMenuItem(
                      value: ExperienceLevel.clearExp,
                      child: Text('클경'),
                    ),
                    DropdownMenuItem(
                      value: ExperienceLevel.multiClearExp,
                      child: Text('다클경'),
                    ),
                    DropdownMenuItem(
                      value: ExperienceLevel.semiExperienced,
                      child: Text('반숙'),
                    ),
                    DropdownMenuItem(
                      value: ExperienceLevel.experienced,
                      child: Text('숙련'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _experience = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ApprovalMode>(
                  initialValue: _approval,
                  decoration: const InputDecoration(
                    labelText: '가입 승인',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ApprovalMode.leaderOnly,
                      child: Text('파티장 승인'),
                    ),
                    DropdownMenuItem(
                      value: ApprovalMode.directJoin,
                      child: Text('승인 없이 바로 가입'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _approval = value!),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('saveRecruitmentButton'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '생성 중...' : '모집 생성'),
                ),
              ],
            ),
          ),
  );
  String? _positiveInteger(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return (int.tryParse(value) ?? 0) > 0 ? null : '1 이상의 전투력을 입력해주세요.';
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
    final difficulty = raid.difficulties.where((item) => item.isActive).first;
    setState(() {
      _raid = raid;
      _difficulty = difficulty;
    });
    await _refreshCandidates();
  }

  Future<void> _changeDifficulty(RaidDifficultyDefinition difficulty) async {
    setState(() => _difficulty = difficulty);
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
    setState(() {
      _leader = selected;
      _role = selected.roles.where((option) => option.canSelect).first.role;
    });
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
      final borderColor = candidate.canSelect
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
            enabled: candidate.canSelect,
            leading: Icon(
              candidate.canSelect ? Icons.person : Icons.block,
              color: candidate.canSelect
                  ? null
                  : Theme.of(context).colorScheme.error,
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
            onTap: candidate.canSelect
                ? () => Navigator.pop(context, candidate)
                : null,
          ),
        ),
      );
    }
    return widgets;
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
          final level = option.itemLevel == null
              ? '-'
              : DisplayNumberFormatter.fixed(option.itemLevel!);
          return '${_roleLabel(option.role)} $level';
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

  String _roleLabel(PartyRole role) => role == PartyRole.support ? '서포터' : '딜러';

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
    }
    setState(() => _saving = true);
    final approval = switch (_approval) {
      ApprovalMode.leaderOnly => const ApprovalPolicy.leaderOnly(),
      ApprovalMode.directJoin => const ApprovalPolicy.directJoin(),
      ApprovalMode.anyMember ||
      ApprovalMode.quorum => throw StateError('현재 생성 화면에서 지원하지 않는 승인 방식입니다.'),
    };
    final result = await widget.commandService.createRecruitment(
      title: _title.text.trim(),
      metadata: RecruitmentMetadata(
        catalogVersion: _catalog!.catalogVersion,
        raidId: raid.raidId,
        difficultyId: difficulty.difficultyId,
        raidName: raid.displayName,
        difficultyName: difficulty.name,
        difficultyAlias: difficulty.displayAlias,
        gateCount: raid.gateCount,
        minItemLevel: difficulty.minItemLevel,
        minCombatPower: _combatPower.text.isEmpty
            ? null
            : int.parse(_combatPower.text),
        experienceLevel: _experience,
        maxPlayHours: null,
      ),
      leaderCharacterId: leader.characterId,
      leaderClassName: leader.className,
      leaderRole: _role,
      approvalPolicy: approval,
      compositionPolicy: PartyCompositionPolicy(
        RecruitmentPartyRules.fromRaid(raid),
      ),
      cancelPendingApplications: pendingCount > 0,
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
}
