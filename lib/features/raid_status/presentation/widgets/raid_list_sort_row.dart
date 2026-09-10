import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/raid_list_sort_selection.dart';
import '../../domain/entities/remaining_slots_filter_selection.dart';
import '../../domain/services/raid_list_sort.dart';

/// 참가 인원 화살표 토글 + 남은 자리 2차 필터 진입 행.
class RaidListSortRow extends StatelessWidget {
  const RaidListSortRow({
    required this.sortSelection,
    required this.remainingSlotsSelection,
    required this.onToggleMemberCountSort,
    required this.onRemainingSlotsChanged,
    super.key,
  });

  final RaidListSortSelection sortSelection;
  final RemainingSlotsFilterSelection remainingSlotsSelection;
  final VoidCallback onToggleMemberCountSort;
  final ValueChanged<RemainingSlotsFilterSelection> onRemainingSlotsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remainingActive = !remainingSlotsSelection.isUnrestricted;
    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: const ValueKey('raidListMemberCountSortToggle'),
                borderRadius: BorderRadius.circular(8),
                onTap: onToggleMemberCountSort,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        raidListMemberCountSortLabel(sortSelection),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        sortSelection.isDescending
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            InkWell(
              key: const ValueKey('raidListRemainingSlotsFilterButton'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openRemainingSlotsSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      remainingSlotsFilterBarLabel(remainingSlotsSelection),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: remainingActive
                            ? theme.colorScheme.primary
                            : null,
                        fontWeight: remainingActive ? FontWeight.w600 : null,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more,
                      size: 20,
                      color: remainingActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRemainingSlotsSheet(BuildContext context) async {
    var draft = remainingSlotsSelection;
    final result = await showModalBottomSheet<RemainingSlotsFilterSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '남은 자리',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          key: const ValueKey(
                            'remainingSlotsFilterResetButton',
                          ),
                          onPressed: draft.isUnrestricted
                              ? null
                              : () {
                                  setModalState(() {
                                    draft = RemainingSlotsFilterSelection
                                        .unrestricted;
                                  });
                                },
                          child: const Text('초기화'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '상단 필터 적용 후 남은 자리 수로 다시 좁힙니다. 여러 개 선택 가능합니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final count
                            in RemainingSlotsFilterSelection
                                .selectableSlotCounts)
                          FilterChip(
                            key: ValueKey('remainingSlotsChip-$count'),
                            label: Text('$count'),
                            selected: draft.slotCounts.contains(count),
                            onSelected: (_) {
                              setModalState(() {
                                draft = draft.toggle(count);
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('remainingSlotsFilterApplyButton'),
                      onPressed: () => Navigator.of(context).pop(draft),
                      child: const Text('적용'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null || result == remainingSlotsSelection) return;
    onRemainingSlotsChanged(result);
  }
}
