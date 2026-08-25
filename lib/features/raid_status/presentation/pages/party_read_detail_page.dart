import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../../shared/formatters/korea_time_formatter.dart';
import '../../../recruitment_list/domain/entities/party_application_command.dart';
import '../../../recruitment_list/domain/entities/party_read_models.dart';
import '../../../recruitment_list/domain/entities/party_recruitment.dart';
import '../../../recruitment_list/domain/entities/recruitment_aggregate.dart';
import '../../../recruitment_list/domain/entities/recruitment_application.dart';
import '../../../recruitment_list/domain/repositories/party_application_command_repository.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';
import '../../../recruitment_list/domain/services/recruitment_leader_candidate_service.dart';
import '../viewmodels/party_read_detail_view_model.dart';

class PartyReadDetailPage extends StatefulWidget {
  const PartyReadDetailPage({
    required this.recruitmentId,
    required this.partyReadRepository,
    this.applicationCommandRepository,
    this.candidateService,
    this.playerId,
    super.key,
  });

  final String recruitmentId;
  final PartyReadRepository partyReadRepository;
  final PartyApplicationCommandRepository? applicationCommandRepository;
  final RecruitmentLeaderCandidateService? candidateService;
  final String? playerId;

  @override
  State<PartyReadDetailPage> createState() => _PartyReadDetailPageState();
}

class _PartyReadDetailPageState extends State<PartyReadDetailPage> {
  late final PartyReadDetailViewModel<PublicRecruitmentSummary> _viewModel;
  StreamSubscription<PartyReadDetailSnapshot<PartyApplicationSummary?>>?
  _myApplicationSubscription;
  PartyApplicationSummary? _myApplication;
  bool _myApplicationLoading = false;
  bool _submitting = false;

  bool get _canCommand =>
      widget.applicationCommandRepository != null &&
      widget.candidateService != null &&
      widget.playerId != null &&
      widget.playerId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _viewModel = PartyReadDetailViewModel<PublicRecruitmentSummary>(
      streamFactory: () =>
          widget.partyReadRepository.watchRecruitment(widget.recruitmentId),
    )..start();
    if (_canCommand) {
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
  }

  @override
  void dispose() {
    _myApplicationSubscription?.cancel();
    _viewModel.dispose();
    super.dispose();
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
    final repository = widget.applicationCommandRepository;
    if (candidateService == null || repository == null || _submitting) return;

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
      builder: (context) => _ApplyCandidateSheet(candidates: eligible),
    );
    if (selected == null || !mounted) return;

    setState(() => _submitting = true);
    final result = await repository.apply(
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
      ).showSnackBar(const SnackBar(content: Text('신청을 보냈습니다.')));
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
              if (_canCommand)
                _ApplicationActions(
                  summary: summary,
                  myApplication: _myApplication,
                  loadingApplication: _myApplicationLoading,
                  submitting: _submitting,
                  onApply: () => _openApplySheet(summary),
                  onWithdraw: _withdraw,
                )
              else
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('신청', style: Theme.of(context).textTheme.titleMedium),
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
              child: Text(submitting ? '처리 중...' : '지원하기'),
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
  const _ApplyCandidateSheet({required this.candidates});

  final List<RecruitmentLeaderCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('신청할 캐릭터')),
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

String _applicationStatusLabel(PartyApplicationSummary application) =>
    switch (application.status) {
      RecruitmentApplicationStatus.pending => '승인 대기',
      RecruitmentApplicationStatus.approved => '승인됨',
      RecruitmentApplicationStatus.rejected => '거절됨',
      RecruitmentApplicationStatus.withdrawn => '철회함',
      RecruitmentApplicationStatus.superseded => '다른 신청으로 대체됨',
    };
