import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/services/raid_status_filter.dart';
import '../viewmodels/active_raid_filter_view_model.dart';

class RaidStatusFilterBar extends StatelessWidget {
  const RaidStatusFilterBar({
    required this.label,
    required this.onOpen,
    super.key,
  });

  final String label;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      child: InkWell(
        key: const ValueKey('raidStatusFilterBar'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.expand_more,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showRaidStatusFilterSheet({
  required BuildContext context,
  required ActiveRaidFilterViewModel viewModel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => RaidStatusFilterSheet(viewModel: viewModel),
  );
}

class RaidStatusFilterSheet extends StatelessWidget {
  const RaidStatusFilterSheet({required this.viewModel, super.key});

  final ActiveRaidFilterViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final state = viewModel.state;
        final selection = state.selection;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '레이드 필터',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          state.countLabel,
                          key: const ValueKey('raidStatusFilterCount'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '공개 조건',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    CheckboxListTile(
                      key: const ValueKey('raidStatusFilterPublicAll'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('전체'),
                      value: selection.includeAllPublicScopes,
                      onChanged: (_) {
                        if (!selection.includeAllPublicScopes) {
                          unawaited(
                            viewModel.setSelection(
                              selection.selectAllPublicScopes(),
                            ),
                          );
                        }
                      },
                    ),
                    CheckboxListTile(
                      key: const ValueKey('raidStatusFilterPublicOpen'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('일반 공개'),
                      value: selection.includePublic,
                      onChanged: (_) => unawaited(
                        viewModel.setSelection(selection.togglePublic()),
                      ),
                    ),
                    CheckboxListTile(
                      key: const ValueKey('raidStatusFilterPublicGroup'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('그룹 공개'),
                      value: selection.includeGroup,
                      onChanged: (_) => unawaited(
                        viewModel.setSelection(selection.toggleGroup()),
                      ),
                    ),
                    if (state.showGroupMemberFilters) ...[
                      const SizedBox(height: 8),
                      Text('그룹', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _OptionChips(
                        options: state.groups,
                        selectedIds: selection.groupIds,
                        keyPrefix: 'raidStatusFilterGroupChip',
                        onToggle: (id) => unawaited(
                          viewModel.setSelection(selection.toggleGroupId(id)),
                        ),
                      ),
                      if (state.visibleMembers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '그룹원',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        for (final member in state.visibleMembers) ...[
                          FilterChip(
                            key: ValueKey(
                              'raidStatusFilterMemberChip-${member.playerId}',
                            ),
                            label: Text(member.label),
                            selected: selection.memberPlayerIds.contains(
                              member.playerId,
                            ),
                            showCheckmark: false,
                            selectedColor: AppColors.primarySoft,
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color:
                                  selection.memberPlayerIds.contains(
                                    member.playerId,
                                  )
                                  ? AppColors.primary
                                  : AppColors.outline,
                            ),
                            shape: const StadiumBorder(),
                            onSelected: (_) => unawaited(
                              viewModel.setSelection(
                                selection.toggleMember(member.playerId),
                              ),
                            ),
                          ),
                          if (member.characters.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: _OptionChips(
                                options: member.characters,
                                selectedIds:
                                    selection.characterIdsByPlayer[member
                                        .playerId] ??
                                    const {},
                                keyPrefix:
                                    'raidStatusFilterCharacterChip-${member.playerId}',
                                onToggle: (id) => unawaited(
                                  viewModel.setSelection(
                                    selection.toggleCharacter(
                                      playerId: member.playerId,
                                      characterId: id,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    ],
                    if (state.catalog.raids.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '레이드',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _OptionChips(
                        options: state.catalog.raids,
                        selectedIds: selection.raidIds,
                        keyPrefix: 'raidStatusFilterRaidChip',
                        onToggle: (id) => unawaited(
                          viewModel.setSelection(selection.toggleRaid(id)),
                        ),
                      ),
                    ],
                    if (state.catalog.difficulties.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '난이도',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _OptionChips(
                        options: state.catalog.difficulties,
                        selectedIds: selection.difficultyIds,
                        keyPrefix: 'raidStatusFilterDifficultyChip',
                        onToggle: (id) => unawaited(
                          viewModel.setSelection(
                            selection.toggleDifficulty(id),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OptionChips extends StatelessWidget {
  const _OptionChips({
    required this.options,
    required this.selectedIds,
    required this.keyPrefix,
    required this.onToggle,
  });

  final List<RaidStatusFilterOption> options;
  final Set<String> selectedIds;
  final String keyPrefix;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          FilterChip(
            key: ValueKey('$keyPrefix-${option.id}'),
            label: Text(option.label),
            selected: selectedIds.contains(option.id),
            showCheckmark: false,
            selectedColor: AppColors.primarySoft,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selectedIds.contains(option.id)
                  ? AppColors.primary
                  : AppColors.outline,
            ),
            shape: const StadiumBorder(),
            onSelected: (_) => onToggle(option.id),
          ),
      ],
    );
  }
}
