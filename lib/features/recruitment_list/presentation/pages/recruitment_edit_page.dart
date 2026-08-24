import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/policies/raid_eligibility_policy.dart';
import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/entities/recruitment_application.dart';
import '../../domain/policies/approval_policy.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/policies/recruitment_auto_title_policy.dart';
import '../../domain/repositories/recruitment_state_repository.dart';
import '../../domain/services/recruitment_command_service.dart';
import '../../domain/state/recruitment_state_machine.dart';
import '../models/recruitment_form_draft.dart';
import '../widgets/recruitment_form.dart';

class RecruitmentEditPage extends StatefulWidget {
  const RecruitmentEditPage({
    required this.recruitmentId,
    required this.repository,
    required this.commandService,
    required this.catalogRepository,
    super.key,
  });

  final String recruitmentId;
  final RecruitmentStateRepository repository;
  final RecruitmentCommandService commandService;
  final RaidCatalogRepository catalogRepository;

  @override
  State<RecruitmentEditPage> createState() => _RecruitmentEditPageState();
}

class _RecruitmentEditPageState extends State<RecruitmentEditPage> {
  static const _autoTitlePolicy = RecruitmentAutoTitlePolicy();
  static const _eligibilityPolicy = RaidEligibilityPolicy();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _combatPower = TextEditingController();
  RecruitmentAggregate? _aggregate;
  RaidCatalog? _catalog;
  RecruitmentFormDraft? _draft;
  RaidDefinition? _raid;
  RaidDifficultyDefinition? _difficulty;
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  String? _error;

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
    final aggregate = await widget.repository.getById(widget.recruitmentId);
    final catalog = await widget.catalogRepository.loadCatalog();
    if (!mounted) return;
    if (aggregate == null ||
        aggregate.state.leaderUserId != widget.commandService.currentUserId) {
      setState(() {
        _error = '수정할 수 있는 모집 정보를 찾지 못했습니다.';
        _loading = false;
      });
      return;
    }
    final raid = catalog.raids
        .where((item) => item.raidId == aggregate.metadata.raidId)
        .firstOrNull;
    final difficulty = raid?.difficulties
        .where(
          (item) => item.difficultyId == aggregate.metadata.difficultyId,
        )
        .firstOrNull;
    if (raid == null || difficulty == null) {
      setState(() {
        _error = '현재 모집의 레이드 정보를 확인하지 못했습니다.';
        _loading = false;
      });
      return;
    }
    final draft = RecruitmentFormDraft.fromAggregate(aggregate);
    _title.text = draft.title;
    _combatPower.text = draft.minCombatPower == null
        ? ''
        : DisplayNumberFormatter.integer(draft.minCombatPower!);
    setState(() {
      _aggregate = aggregate;
      _catalog = catalog;
      _draft = draft;
      _raid = raid;
      _difficulty = difficulty;
      _loading = false;
    });
  }

  List<EligibleRaidOption> get _raidOptions {
    final aggregate = _aggregate;
    final catalog = _catalog;
    if (aggregate == null || catalog == null) return const [];
    final leader = aggregate.state.members
        .where((member) => member.userId == aggregate.state.leaderUserId)
        .firstOrNull;
    return _eligibilityPolicy.eligibleRaids(
      catalog: catalog,
      itemLevel: leader?.itemLevel,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || !_isDirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmDiscard();
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('모집 수정')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Form(
              key: _formKey,
              child: RecruitmentForm(
              titleController: _title,
              combatPowerController: _combatPower,
              draft: _draft!,
              raidOptions: _raidOptions,
              selectedRaid: _raid!,
              selectedDifficulty: _difficulty!,
              raidErrorText: _raidOptions.isEmpty
                  ? '파티장 캐릭터가 입장 가능한 레이드가 없습니다.'
                  : !_raidOptions.any(
                      (option) => option.raid.raidId == _raid!.raidId,
                    )
                  ? '현재 레이드는 파티장 캐릭터의 입장 조건에 맞지 않습니다. 다시 선택해주세요.'
                  : null,
              onTitleChanged: _changeTitle,
              onRaidChanged: _changeRaid,
              onDifficultyChanged: _changeDifficulty,
              onCombatPowerChanged: _changeCombatPower,
              onExperienceChanged: (value) {
                setState(() {
                  _draft = _draft!.copyWith(experienceLevel: value);
                });
                _syncAutoTitle();
              },
              onApprovalChanged: (value) {
                setState(() {
                  _draft = _draft!.copyWith(approvalMode: value);
                });
              },
              onSubmit: _reviewAndSave,
              submitLabel: '변경 검토',
              submitting: _saving,
              ),
            ),
    ),
  );

  bool get _isDirty {
    final aggregate = _aggregate;
    final draft = _draft;
    if (aggregate == null || draft == null) return false;
    return _title.text.trim() != aggregate.title ||
        draft.raidId != aggregate.metadata.raidId ||
        draft.difficultyId != aggregate.metadata.difficultyId ||
        draft.experienceLevel != aggregate.metadata.experienceLevel ||
        draft.minCombatPower != aggregate.metadata.minCombatPower ||
        draft.approvalMode != aggregate.state.approvalPolicy.mode;
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('수정 내용을 버릴까요?'),
        content: const Text('저장하지 않은 모집 수정 내용이 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 수정'),
          ),
          FilledButton(
            key: const ValueKey('discardRecruitmentEditButton'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('버리기'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  void _changeTitle(String value) {
    final usesAutoTitle = value.trim().isEmpty;
    _draft = _draft!.copyWith(title: value, usesAutoTitle: usesAutoTitle);
  }

  void _changeRaid(RaidDefinition raid) {
    final difficulty = _raidOptions
        .firstWhere((option) => option.raid.raidId == raid.raidId)
        .highestDifficulty;
    setState(() {
      _raid = raid;
      _difficulty = difficulty;
      _draft = _draft!.copyWith(
        raidId: raid.raidId,
        difficultyId: difficulty.difficultyId,
      );
    });
    _syncAutoTitle();
  }

  void _changeDifficulty(RaidDifficultyDefinition difficulty) {
    setState(() {
      _difficulty = difficulty;
      _draft = _draft!.copyWith(difficultyId: difficulty.difficultyId);
    });
    _syncAutoTitle();
  }

  void _changeCombatPower(String value) {
    _draft = _draft!.copyWith(
      minCombatPower: RecruitmentFormDraft.normalizeMinCombatPower(value),
    );
    _syncAutoTitle();
  }

  void _syncAutoTitle() {
    if (_draft?.usesAutoTitle != true) return;
    if (_title.text.isEmpty) return;
    final value = _autoTitlePolicy.build(
      difficultyAlias: _difficulty?.displayAlias ?? '',
      experienceLevel: _draft!.experienceLevel,
      minCombatPower: _draft!.minCombatPower,
    );
    _title.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _draft = _draft!.copyWith(title: value);
  }

  Future<void> _reviewAndSave() async {
    if (!_formKey.currentState!.validate()) return;
    final aggregate = _aggregate!;
    final difficulty = _difficulty!;
    final affectedMembers = aggregate.state.members
        .where(
          (member) =>
              member.itemLevel == null ||
              member.itemLevel! < difficulty.minItemLevel,
        )
        .toList(growable: false);
    final affectedApplications = aggregate.state.applications.values
        .where(
          (application) =>
              application.status == RecruitmentApplicationStatus.pending &&
              (application.itemLevel == null ||
                  application.itemLevel! < difficulty.minItemLevel),
        )
        .toList(growable: false);
    final minimumCombatPower = _draft!.minCombatPower;
    final combatPowerAffectedMembers = minimumCombatPower == null
        ? const <RecruitmentPartyMember>[]
        : aggregate.state.members
              .where(
                (member) =>
                    member.combatPower == null ||
                    member.combatPower! < minimumCombatPower,
              )
              .toList(growable: false);
    final combatPowerAffectedApplications = minimumCombatPower == null
        ? const <RecruitmentApplication>[]
        : aggregate.state.applications.values
              .where(
                (application) =>
                    application.status == RecruitmentApplicationStatus.pending &&
                    (application.combatPower == null ||
                        application.combatPower! < minimumCombatPower),
              )
              .toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('모집 수정 내용을 확인해주세요'),
        content: Text(
          [
            '${_raid!.displayName} - ${difficulty.name}',
            '입장 레벨 ${DisplayNumberFormatter.integer(difficulty.minItemLevel)}',
            minimumCombatPower == null
                ? '전투력 제한 없음'
                : '최소 전투력 ${DisplayNumberFormatter.integer(minimumCombatPower)}',
            if (affectedMembers.isNotEmpty)
              '입장 레벨 확인 필요 파티원 ${affectedMembers.length}명: ${affectedMembers.map((item) => item.characterId).join(', ')}',
            if (affectedApplications.isNotEmpty)
              '입장 레벨 확인 필요 신청자 ${affectedApplications.length}명: ${affectedApplications.map((item) => item.characterId).join(', ')}',
            if (combatPowerAffectedMembers.isNotEmpty)
              '최소 전투력 확인 필요 파티원 ${combatPowerAffectedMembers.length}명: ${combatPowerAffectedMembers.map((item) => item.characterId).join(', ')}',
            if (combatPowerAffectedApplications.isNotEmpty)
              '최소 전투력 확인 필요 신청자 ${combatPowerAffectedApplications.length}명: ${combatPowerAffectedApplications.map((item) => item.characterId).join(', ')}',
            '조건에 맞지 않는 참가자나 신청자는 자동으로 제외되지 않습니다.',
            '가입 승인 방식 변경은 이후 신청부터 적용됩니다.',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('돌아가기'),
          ),
          FilledButton(
            key: const ValueKey('confirmRecruitmentEditButton'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('변경'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final approvalPolicy = switch (_draft!.approvalMode) {
      ApprovalMode.leaderOnly => const ApprovalPolicy.leaderOnly(),
      ApprovalMode.directJoin => const ApprovalPolicy.directJoin(),
      ApprovalMode.anyMember => const ApprovalPolicy.anyMember(),
      ApprovalMode.quorum => ApprovalPolicy.quorum(requiredApprovals: 2),
    };
    final result = await widget.commandService.updateRecruitment(
      recruitmentId: aggregate.id,
      title: _title.text.trim().isEmpty
          ? _autoTitlePolicy.build(
              difficultyAlias: difficulty.displayAlias,
              experienceLevel: _draft!.experienceLevel,
              minCombatPower: minimumCombatPower,
            )
          : _title.text.trim(),
      metadata: RecruitmentMetadata(
        catalogVersion: _catalog!.catalogVersion,
        raidId: _raid!.raidId,
        difficultyId: difficulty.difficultyId,
        raidName: _raid!.displayName,
        difficultyName: difficulty.name,
        difficultyAlias: difficulty.displayAlias,
        gateCount: _raid!.gateCount,
        minItemLevel: difficulty.minItemLevel,
        minCombatPower: minimumCombatPower,
        experienceLevel: _draft!.experienceLevel,
        maxPlayHours: aggregate.metadata.maxPlayHours,
        raidStartAt: aggregate.metadata.raidStartAt,
      ),
      approvalPolicy: approvalPolicy,
      compositionPolicy: PartyCompositionPolicy(
        RecruitmentPartyRules.fromRaid(_raid!),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      _allowPop = true;
      Navigator.pop(context, true);
      return;
    }
    final message = switch (result.domainFailure) {
      RecruitmentCommandFailure.compositionRejected =>
        '현재 파티 구성을 새 모집 조건에 배치할 수 없습니다.',
      RecruitmentCommandFailure.unauthorized => '모집 수정 권한이 없습니다.',
      _ => result.failure == LocalRecruitmentFailure.revisionConflict
          ? '다른 변경이 먼저 저장되었습니다. 모집 정보를 다시 확인해주세요.'
          : '모집 정보를 수정하지 못했습니다.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
