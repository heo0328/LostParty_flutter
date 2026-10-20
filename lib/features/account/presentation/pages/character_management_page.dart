import 'package:flutter/material.dart';
import '../widgets/ownership_notice_title.dart';
import '../widgets/character_name_label.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/formatters/display_number_formatter.dart';

import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/character_management_gateway.dart';
import '../../domain/repositories/activity_characters_repository.dart';
import '../../domain/repositories/nice_group_auto_refresh_settings_repository.dart';
import '../../domain/repositories/representative_character_sync_gateway.dart';
import '../viewmodels/character_management_view_model.dart';
import '../viewmodels/member_settings_view_model.dart';
import '../widgets/representative_crown.dart';

class CharacterManagementPage extends StatefulWidget {
  const CharacterManagementPage({
    required this.accountRepository,
    this.representativeSyncGateway,
    this.activityCharactersRepository,
    this.niceGroupSettingsRepository,
    this.playerId,
    this.accountId,
    this.memberSettings,
    this.automaticRefreshAvailable = false,
    this.onLogin,
    this.managementGateway,
    this.onSaved,
    super.key,
  });

  final AccountRepository accountRepository;
  final CharacterManagementGateway? managementGateway;
  final Future<void> Function()? onSaved;
  final RepresentativeCharacterSyncGateway? representativeSyncGateway;
  final ActivityCharactersRepository? activityCharactersRepository;
  final NiceGroupAutoRefreshSettingsRepository? niceGroupSettingsRepository;
  final String? playerId;
  final int? accountId;
  final MemberSettingsViewModel? memberSettings;
  final bool automaticRefreshAvailable;
  final VoidCallback? onLogin;

  @override
  State<CharacterManagementPage> createState() =>
      _CharacterManagementPageState();
}

class _CharacterManagementPageState extends State<CharacterManagementPage> {
  late final CharacterManagementViewModel _viewModel;
  bool _completingSave = false;

  @override
  void initState() {
    super.initState();
    _viewModel = CharacterManagementViewModel(
      accountRepository: widget.accountRepository,
      representativeSyncGateway: widget.representativeSyncGateway,
      activityCharactersRepository: widget.activityCharactersRepository,
      niceGroupSettingsRepository: widget.niceGroupSettingsRepository,
      playerId: widget.playerId,
      accountId: widget.accountId,
      managementGateway: widget.managementGateway,
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

  void _close() {
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _saveAndClose() async {
    if (_completingSave || !_viewModel.canSave) return;
    setState(() => _completingSave = true);
    final gateway = widget.managementGateway;
    bool current() => mounted && (gateway == null || gateway.current);
    try {
      await _viewModel.save();
      if (!current() || _viewModel.message != null) return;
      if (gateway != null) await widget.onSaved?.call();
      if (current()) _close();
    } finally {
      if (mounted) setState(() => _completingSave = false);
    }
  }

  Future<void> _chooseRepresentative(LocalAccountCharacter character) async {
    if (!_viewModel.canSetRepresentative(character)) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대표 캐릭터 변경'),
        content: Text('${character.characterName} 캐릭터로 대표 캐릭터를 변경하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('변경'),
          ),
        ],
      ),
    );
    if (mounted &&
        accepted == true &&
        _viewModel.canSetRepresentative(character)) {
      _viewModel.setRepresentative(character);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _viewModel.account;
    return Scaffold(
      appBar: AppBar(
        title: const OwnershipNoticeTitle(child: Text('캐릭터 관리')),
        actions: [
          if (widget.managementGateway != null)
            IconButton(
              tooltip: '캐릭터 설정 다시 조회',
              onPressed: _viewModel.isSaving || _viewModel.isLoading
                  ? null
                  : _viewModel.initialize,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: switch ((_viewModel.isLoading, account)) {
          (true, _) => const Center(child: CircularProgressIndicator()),
          (false, null) => Center(
            child: Text(_viewModel.message ?? '저장된 계정이 없습니다.'),
          ),
          (false, final _) => _buildContent(),
        },
      ),
    );
  }

  Widget _buildContent() {
    final selected = _viewModel.selectedCharacters;
    return Column(
      children: [
        if (_viewModel.isSaving) const LinearProgressIndicator(),
        if (_viewModel.message case final message?)
          _Notice(icon: Icons.error_outline, message: message)
        else if (_viewModel.representativeCooldownLabel case final label?)
          _Notice(icon: Icons.schedule, message: label),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: '앱에서 사용할 캐릭터',
                    trailing:
                        '${_viewModel.selectedCount} / ${_viewModel.rosterCount}',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    _viewModel.isMemberManagement
                        ? '앱에서 사용할 캐릭터를 선택해 주세요.'
                        : '선택한 캐릭터만 레이드, 그룹 및 전투력 동기화에 사용됩니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final character in _viewModel.rosterCharacters)
                        _ActivitySelectCard(
                          character: character,
                          isSelected: _viewModel.isActivitySelected(character),
                          isRepresentative:
                              _viewModel.draftRepresentativeId == character.id,
                          enabled: _viewModel.canToggleActivity(character),
                          onTap: () => _viewModel.toggleActivity(character),
                        ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                sliver: const SliverToBoxAdapter(
                  child: _SectionHeader(title: '대표 캐릭터와 표시 순서'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '현재 참가 중인 레이드에서는 유지되며 새로운 레이드 선택에서 제외됩니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (selected.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Text('앱에서 사용할 캐릭터를 최소 1명 선택해 주세요.'),
                  ),
                )
              else
                SliverReorderableList(
                  itemCount: selected.length,
                  onReorder: _viewModel.isSaving
                      ? (_, _) {}
                      : _viewModel.reorder,
                  itemBuilder: (context, index) {
                    final character = selected[index];
                    return _SelectedCharacterTile(
                      key: ValueKey(character.id),
                      character: character,
                      shaded: index.isOdd,
                      isRepresentative:
                          _viewModel.draftRepresentativeId == character.id,
                      isEnabled: !_viewModel.isSaving,
                      isRepresentativeEnabled: _viewModel.canSetRepresentative(
                        character,
                      ),
                      onSetRepresentative: () =>
                          _chooseRepresentative(character),
                      dragHandle: ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.sm),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Expanded(child: Text('메인 화면 표시 개수')),
                      Text('${_viewModel.draftDisplayLimit}명'),
                      if (_viewModel.maxDisplayLimit > 1)
                        Expanded(
                          child: Slider(
                            value: _viewModel.draftDisplayLimit.toDouble(),
                            min: 1,
                            max: _viewModel.maxDisplayLimit.toDouble(),
                            divisions: _viewModel.maxDisplayLimit - 1,
                            label: '${_viewModel.draftDisplayLimit}명',
                            onChanged: _viewModel.canEditDraft
                                ? (v) => _viewModel.changeDisplayLimit(
                                    v.round() - _viewModel.draftDisplayLimit,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: !_viewModel.canEditDraft || _completingSave
                      ? null
                      : () {
                          _viewModel.discardChanges();
                          _close();
                        },
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('characterManagementSaveButton'),
                  onPressed: _viewModel.canSave && !_completingSave
                      ? _saveAndClose
                      : null,
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        if (trailing case final value?)
          Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _ActivitySelectCard extends StatelessWidget {
  const _ActivitySelectCard({
    required this.character,
    required this.isSelected,
    required this.isRepresentative,
    required this.enabled,
    required this.onTap,
  });

  final LocalAccountCharacter character;
  final bool isSelected;
  final bool isRepresentative;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isSelected ? AppColors.primary : AppColors.outline;
    final background = isSelected ? AppColors.primarySubtle : AppColors.surface;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
      ),
      child: InkWell(
        key: ValueKey('activityCard-${character.id}'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: SizedBox(
          width: 108,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CharacterNameLabel(
                        character.characterName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isSelected
                              ? AppColors.primaryStrong
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isRepresentative)
                      const Icon(
                        Icons.star,
                        size: 14,
                        color: AppColors.primary,
                      ),
                  ],
                ),
                Text(
                  character.characterClassName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedCharacterTile extends StatelessWidget {
  const _SelectedCharacterTile({
    required this.character,
    required this.isRepresentative,
    required this.isEnabled,
    required this.isRepresentativeEnabled,
    required this.onSetRepresentative,
    required this.dragHandle,
    this.shaded = false,
    super.key,
  });

  final LocalAccountCharacter character;
  final bool isRepresentative;
  final bool isEnabled;
  final bool isRepresentativeEnabled;
  final VoidCallback onSetRepresentative;
  final Widget dragHandle;
  final bool shaded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: shaded
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : AppColors.surface,
      child: ListTile(
        title: Text(character.characterName),
        subtitle: Text(
          '${character.characterClassName} · ${_formatItemLevel(character.itemLevel)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepresentativeCrown(
              selected: isRepresentative,
              busy: false,
              label: isRepresentative ? '현재 대표 캐릭터' : '대표 캐릭터로 설정',
              onPressed: isEnabled && isRepresentativeEnabled
                  ? onSetRepresentative
                  : null,
            ),
            dragHandle,
          ],
        ),
      ),
    );
  }

  String _formatItemLevel(double? value) {
    return value == null
        ? '아이템 Lv. -'
        : '아이템 Lv. ${DisplayNumberFormatter.integer(value)}';
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
