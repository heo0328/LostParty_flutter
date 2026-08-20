import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/entities/recruitment_application.dart';
import '../../domain/policies/approval_policy.dart';
import '../../domain/repositories/recruitment_state_repository.dart';
import '../../domain/services/recruitment_application_candidate_service.dart';
import '../../domain/services/recruitment_command_service.dart';

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
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    member.role == PartyRole.support
                        ? Icons.health_and_safety
                        : Icons.sports_martial_arts,
                  ),
                  title: Text(member.characterId),
                  subtitle: Text('${member.className} · ${_role(member.role)}'),
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
    if (aggregate.state.members.any((member) => member.userId == userId)) {
      return const Text('현재 파티원입니다.');
    }
    final application = aggregate.state.applications[userId];
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
    if (!aggregate.state.isRecruiting) return const Text('모집이 마감되었습니다.');
    return FilledButton(
      key: const ValueKey('openApplicationButton'),
      onPressed: _submitting ? null : () => _showCandidates(aggregate),
      child: const Text('지원하기'),
    );
  }

  Future<void> _showCandidates(RecruitmentAggregate aggregate) async {
    final candidates = await widget.candidateService.load(aggregate);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.75,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('신청 캐릭터와 역할 선택'),
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
                            subtitle: Text(
                              '${candidate.className} · ${_role(candidate.role)}\n'
                              '${candidate.canApply ? '신청 가능' : candidate.rejectionReasons.join(' · ')}',
                            ),
                            isThreeLine: true,
                            onTap: candidate.canApply
                                ? () {
                                    Navigator.pop(sheetContext);
                                    _apply(candidate);
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

  Future<void> _apply(RecruitmentApplicationCandidate candidate) async {
    setState(() => _submitting = true);
    final result = await widget.commandService.apply(
      recruitmentId: widget.recruitmentId,
      characterId: candidate.characterId,
      className: candidate.className,
      role: candidate.role,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    _message(result.isSuccess ? '가입을 신청했습니다.' : '신청 조건을 다시 확인해주세요.');
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
    ApprovalMode.anyMember => '파티원 승인',
    ApprovalMode.quorum => '${policy.requiredApprovals}명 이상 동의',
  };
}
