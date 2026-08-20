import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';

import '../../domain/entities/character_build_analysis.dart';
import '../../domain/entities/character_build_draft.dart';
import '../../domain/entities/character_build_snapshot.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../viewmodels/character_detail_view_model.dart';

class CharacterDetailPage extends StatefulWidget {
  const CharacterDetailPage({
    required this.character,
    required this.accountRepository,
    super.key,
  });

  final LocalAccountCharacter character;
  final AccountRepository accountRepository;

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage> {
  late final CharacterDetailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = CharacterDetailViewModel(
      character: widget.character,
      accountRepository: widget.accountRepository,
    )..addListener(_onChanged);
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.character.characterName)),
      body: SafeArea(
        child: _viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final snapshot = _viewModel.selectedSnapshot;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildProfileHeader(),
        const SizedBox(height: 20),
        _buildRoleControl(),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('saveCharacterBuildButton'),
          onPressed:
              _viewModel.selectedRole == null || _viewModel.isFetchingDraft
              ? null
              : _requestBuildDraft,
          icon: _viewModel.isFetchingDraft
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text(snapshot == null ? '세팅 저장' : '세팅 갱신'),
        ),
        if (_viewModel.errorMessage case final message?) ...[
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        _buildSnapshotStatus(),
        if (snapshot != null) ...[
          const SizedBox(height: 20),
          _buildNotices(snapshot.analysis),
          const SizedBox(height: 20),
          _buildGemEffects(snapshot.analysis),
          const SizedBox(height: 20),
          _buildArkGrid(snapshot.analysis),
        ],
      ],
    );
  }

  Future<void> _requestBuildDraft() async {
    await _viewModel.requestBuildDraft();
    if (!mounted || _viewModel.draft == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) => _buildDraftPreviewDialog(context),
      ),
    );
    if (_viewModel.draft != null) {
      _viewModel.cancelDraft();
    }
  }

  Widget _buildDraftPreviewDialog(BuildContext dialogContext) {
    final draft = _viewModel.draft;
    if (draft == null) {
      return const SizedBox.shrink();
    }
    final detection = draft.analysis.catalogDetection;
    final detectedRole = detection?.detectedRole;
    final selectedRole = _viewModel.draftRole;
    final isMismatch = detectedRole != null && selectedRole != detectedRole;
    return AlertDialog(
      key: const ValueKey('characterBuildDraftPreview'),
      title: const Text('세팅 저장 미리보기'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          key: const ValueKey('characterBuildDraftPreviewScroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDraftProfile(draft),
              const SizedBox(height: 16),
              Text('분석 결과', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('계열: ${detection?.branchDisplayName ?? '확인되지 않음'}'),
              Text('감지 역할: ${_roleLabel(detectedRole)}'),
              Text('룬: ${draft.analysis.runeCount}/8'),
              const SizedBox(height: 16),
              _buildDraftRoleControl(),
              if (isMismatch) ...[
                const SizedBox(height: 12),
                Text(
                  '분석 결과는 ${_roleLabel(detectedRole)} 세팅입니다. '
                  '${_roleLabel(selectedRole)} 위치에 저장하며, 특수 세팅이라면 그대로 저장할 수 있습니다.',
                  key: const ValueKey('characterBuildRoleMismatchNotice'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ] else if (detectedRole == null) ...[
                const SizedBox(height: 12),
                const Text(
                  '세팅 계열을 자동으로 확인하지 못했습니다. 저장 역할을 확인해 주세요.',
                  key: ValueKey('characterBuildUndetectedNotice'),
                ),
              ],
              const SizedBox(height: 16),
              Text('확인 사항', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (draft.analysis.notices.isEmpty)
                const Text('확인된 경고 없음')
              else
                for (final notice in draft.analysis.notices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${notice.message}'),
                  ),
              if (_viewModel.errorMessage case final message?) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  key: const ValueKey('characterBuildDraftError'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _viewModel.isCommittingDraft
              ? null
              : () {
                  _viewModel.cancelDraft();
                  Navigator.of(dialogContext).pop();
                },
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('commitCharacterBuildDraftButton'),
          onPressed: selectedRole == null || _viewModel.isCommittingDraft
              ? null
              : () async {
                  final committed = await _viewModel.commitDraft();
                  if (committed && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
          child: _viewModel.isCommittingDraft
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }

  Widget _buildDraftProfile(CharacterBuildDraft draft) {
    final profile = draft.profile;
    final fetchedAt = draft.fetchedAt.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.characterName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('${profile.serverName} · ${profile.characterClassName}'),
        Text('아이템 Lv. ${_formatNumber(profile.itemLevel)}'),
        Text('전투력 ${_formatNumber(profile.combatPower)}'),
        Text(
          '조회 ${fetchedAt.year}.${_two(fetchedAt.month)}.${_two(fetchedAt.day)} '
          '${_two(fetchedAt.hour)}:${_two(fetchedAt.minute)}',
        ),
      ],
    );
  }

  Widget _buildDraftRoleControl() {
    if (!_viewModel.supportsMultipleRoles) {
      return const Text('저장 역할: 딜러');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('저장 역할'),
        const SizedBox(height: 8),
        SegmentedButton<CharacterBuildRole>(
          key: const ValueKey('characterBuildDraftRoleControl'),
          segments: const [
            ButtonSegment(value: CharacterBuildRole.dealer, label: Text('딜러')),
            ButtonSegment(
              value: CharacterBuildRole.support,
              label: Text('서포터'),
            ),
          ],
          selected: {?_viewModel.draftRole},
          onSelectionChanged: _viewModel.isCommittingDraft
              ? null
              : (selection) {
                  if (selection.isNotEmpty) {
                    _viewModel.selectDraftRole(selection.first);
                  }
                },
        ),
      ],
    );
  }

  String _roleLabel(CharacterBuildRole? role) => switch (role) {
    CharacterBuildRole.dealer => '딜러',
    CharacterBuildRole.support => '서포터',
    null => '확인되지 않음',
  };

  Widget _buildProfileHeader() {
    final character = widget.character;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          character.characterName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text('${character.serverName} · ${character.characterClassName}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text('아이템 Lv. ${_formatNumber(character.itemLevel)}'),
            Text('전투력 ${_formatNumber(character.combatPower)}'),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleControl() {
    if (!_viewModel.supportsMultipleRoles) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Chip(label: Text('딜러 세팅')),
      );
    }
    return SegmentedButton<CharacterBuildRole>(
      key: const ValueKey('characterBuildRoleControl'),
      emptySelectionAllowed: true,
      segments: const [
        ButtonSegment(
          value: CharacterBuildRole.dealer,
          label: Text('딜러'),
          icon: Icon(Icons.sports_martial_arts),
        ),
        ButtonSegment(
          value: CharacterBuildRole.support,
          label: Text('서포터'),
          icon: Icon(Icons.health_and_safety_outlined),
        ),
      ],
      selected: {?_viewModel.selectedRole},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          _viewModel.selectRole(selection.first);
        }
      },
    );
  }

  Widget _buildSnapshotStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('저장된 세팅', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final role in CharacterBuildRole.values)
          if (_viewModel.supportsMultipleRoles ||
              role == CharacterBuildRole.dealer)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _snapshotFor(role) == null
                    ? Icons.radio_button_unchecked
                    : Icons.check_circle_outline,
              ),
              title: Text(role == CharacterBuildRole.dealer ? '딜러' : '서포터'),
              subtitle: Text(_snapshotLabel(_snapshotFor(role))),
            ),
      ],
    );
  }

  Widget _buildNotices(CharacterBuildAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('세팅 확인', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (analysis.notices.isEmpty)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_circle_outline),
            title: Text('확인된 경고 없음'),
          )
        else
          for (final notice in analysis.notices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                notice.level == BuildNoticeLevel.warning
                    ? Icons.warning_amber
                    : Icons.info_outline,
              ),
              title: Text(notice.message),
            ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_fix_high_outlined),
          title: Text('룬 ${analysis.runeCount}/8'),
        ),
      ],
    );
  }

  Widget _buildGemEffects(CharacterBuildAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('보석', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final effect in analysis.gemEffects)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${effect.gemLevel}')),
            title: Text(effect.skillName),
            subtitle: Text(effect.descriptions.join(' · ')),
            trailing: effect.category == GemSkillCategory.passiveOrIdentity
                ? const Tooltip(
                    message: '아크패시브 또는 아이덴티티 스킬',
                    child: Icon(Icons.bolt_outlined),
                  )
                : null,
          ),
      ],
    );
  }

  Widget _buildArkGrid(CharacterBuildAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('아크그리드', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final core in analysis.arkGridCorePoints)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              core.meetsRecommendation
                  ? Icons.check_circle_outline
                  : Icons.warning_amber,
            ),
            title: Text(core.coreName),
            subtitle: Text(
              '${core.grade} · ${core.point}P / 권장 ${core.recommendedPoint}P',
            ),
          ),
        for (final condition in analysis.arkGridConditions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              condition.isSatisfied
                  ? Icons.check_circle_outline
                  : Icons.warning_amber,
            ),
            title: Text(condition.coreName),
            subtitle: Text(condition.conditionText),
          ),
      ],
    );
  }

  CharacterBuildSnapshot? _snapshotFor(CharacterBuildRole role) {
    for (final snapshot in _viewModel.snapshots) {
      if (snapshot.role == role) {
        return snapshot;
      }
    }
    return null;
  }

  String _snapshotLabel(CharacterBuildSnapshot? snapshot) {
    if (snapshot == null) {
      return '저장되지 않음';
    }
    final local = snapshot.capturedAt.toLocal();
    return '${local.year}.${_two(local.month)}.${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatNumber(double? value) {
    return value == null ? '-' : DisplayNumberFormatter.fixed(value);
  }
}
