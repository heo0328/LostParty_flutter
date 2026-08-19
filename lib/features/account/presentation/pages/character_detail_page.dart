import 'package:flutter/material.dart';

import '../../domain/entities/character_build_analysis.dart';
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
              _viewModel.selectedRole == null || _viewModel.isRefreshing
              ? null
              : _viewModel.refreshSelectedRole,
          icon: _viewModel.isRefreshing
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
    return value == null ? '-' : value.toStringAsFixed(2);
  }
}
