import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';

import '../../domain/entities/local_game_account.dart';
import '../models/weekly_raid_status_item.dart';

class AccountCharacterCard extends StatelessWidget {
  const AccountCharacterCard({
    required this.character,
    required this.isRepresentative,
    this.weeklyRaids = const [],
    this.showWeeklyRaidEditor = false,
    this.weeklyRaidHiddenByPreference = false,
    this.onTap,
    this.onWeeklyRaidChanged,
    this.onEditWeeklyRaids,
    this.busyRaidIds = const {},
    super.key,
  });

  final LocalAccountCharacter character;
  final bool isRepresentative;
  final List<WeeklyRaidStatusItem> weeklyRaids;
  final bool showWeeklyRaidEditor;
  final bool weeklyRaidHiddenByPreference;
  final VoidCallback? onTap;
  final void Function(WeeklyRaidStatusItem raid, bool value)?
  onWeeklyRaidChanged;
  final VoidCallback? onEditWeeklyRaids;
  final Set<String> busyRaidIds;

  static const double raidRowHeight = 26;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showRaidChrome =
        weeklyRaids.isNotEmpty ||
        weeklyRaidHiddenByPreference ||
        showWeeklyRaidEditor;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      character.characterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (isRepresentative)
                    const Tooltip(
                      message: '대표 캐릭터',
                      child: Icon(Icons.star, size: 18),
                    ),
                ],
              ),
              Text(
                character.characterClassName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                '아이템 Lv. ${_formatNumber(character.itemLevel)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '전투력 ${_formatNumber(character.combatPower)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              if (showRaidChrome) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '주간 레이드',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    if (showWeeklyRaidEditor && onEditWeeklyRaids != null)
                      IconButton(
                        key: ValueKey('editWeeklyRaids-${character.id}'),
                        tooltip: '표기 레이드 수정',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: onEditWeeklyRaids,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                      ),
                  ],
                ),
                if (weeklyRaidHiddenByPreference && weeklyRaids.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '표시 안 함',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final raid in weeklyRaids)
                  SizedBox(
                    height: raidRowHeight,
                    child: InkWell(
                      onTap:
                          onWeeklyRaidChanged == null ||
                              busyRaidIds.contains(raid.raidId)
                          ? null
                          : () => onWeeklyRaidChanged!(
                              raid,
                              !raid.isCompleted,
                            ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            height: raidRowHeight,
                            child: Checkbox(
                              key: ValueKey(
                                'weeklyRaidClaim-${character.serverCharacterId}-${raid.raidId}',
                              ),
                              value: raid.isCompleted,
                              onChanged:
                                  onWeeklyRaidChanged == null ||
                                      busyRaidIds.contains(raid.raidId)
                                  ? null
                                  : (value) => onWeeklyRaidChanged!(
                                      raid,
                                      value ?? false,
                                    ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              raid.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(double? value) {
    if (value == null) {
      return '-';
    }
    return DisplayNumberFormatter.fixed(value);
  }
}
