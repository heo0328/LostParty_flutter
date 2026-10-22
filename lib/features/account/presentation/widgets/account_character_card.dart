import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';

import '../../domain/entities/local_game_account.dart';
import '../../domain/entities/character_build_analysis.dart';
import '../../domain/entities/weekly_raid_status_projection.dart';
import '../models/weekly_raid_status_item.dart';
import 'character_name_label.dart';

class AccountCharacterCard extends StatelessWidget {
  const AccountCharacterCard({
    required this.character,
    required this.isRepresentative,
    this.basicOnly = false,
    this.weeklyRaids = const [],
    this.representativeCombatPower,
    this.overrideRepresentativeCombatPower = false,
    this.combatPowerNote,
    this.gemValidationSummary,
    this.showWeeklyRaidEditor = false,
    this.weeklyRaidHiddenByPreference = false,
    this.onTap,
    this.onWeeklyRaidChanged,
    this.onEditWeeklyRaids,
    this.busyRaidIds = const {},
    this.representativeControl,
    this.status,
    this.reservedWeeklyRaidRows = 0,
    this.weeklyColumns = 1,
    this.onWeeklyRaidInfo,
    super.key,
  });

  final LocalAccountCharacter character;
  final bool isRepresentative;
  final bool basicOnly;
  final List<WeeklyRaidStatusItem> weeklyRaids;
  final double? representativeCombatPower;
  final bool overrideRepresentativeCombatPower;
  final String? combatPowerNote;
  final GemValidationSummary? gemValidationSummary;
  final bool showWeeklyRaidEditor;
  final bool weeklyRaidHiddenByPreference;
  final VoidCallback? onTap;
  final void Function(WeeklyRaidStatusItem raid, bool value)?
  onWeeklyRaidChanged;
  final VoidCallback? onEditWeeklyRaids;
  final Set<String> busyRaidIds;
  final Widget? representativeControl, status;
  final int reservedWeeklyRaidRows;
  final int weeklyColumns;
  final void Function(WeeklyRaidStatusItem)? onWeeklyRaidInfo;

  static const double raidRowHeight = 26;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showRaidChrome =
        weeklyRaids.isNotEmpty ||
        weeklyRaidHiddenByPreference ||
        showWeeklyRaidEditor ||
        reservedWeeklyRaidRows > 0;
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
                  Expanded(child: CharacterNameLabel(character.characterName)),
                  if (representativeControl != null)
                    representativeControl!
                  else if (isRepresentative)
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
              if (!basicOnly)
                Text(
                  '전투력 ${_formatNumber(overrideRepresentativeCombatPower ? representativeCombatPower : character.combatPower)}'
                  '${combatPowerNote == null ? '' : ' · $combatPowerNote'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              if (!basicOnly)
                if (_gemValidationItems case final items
                    when items.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Column(
                    key: ValueKey('gemValidation-${character.id}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in items)
                        Row(
                          children: [
                            Icon(
                              item.isError
                                  ? Icons.error_outline
                                  : Icons.info_outline,
                              size: 14,
                              color: item.isError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: item.isError
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              if (status != null) ...[const SizedBox(height: 4), status!],
              if (showRaidChrome) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text('주간 레이드', style: theme.textTheme.labelSmall),
                    ),
                    if (showWeeklyRaidEditor)
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
                if (weeklyColumns == 3)
                  _weeklyGrid(context)
                else ...[
                  for (final raid in weeklyRaids)
                    SizedBox(
                      height: raidRowHeight,
                      child: InkWell(
                        onTap:
                            onWeeklyRaidChanged == null ||
                                !raid.canToggle ||
                                busyRaidIds.contains(raid.raidId)
                            ? null
                            : () =>
                                  onWeeklyRaidChanged!(raid, !raid.isCompleted),
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
                                        !raid.canToggle ||
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
                            if (raid.statusMessage case final message?)
                              Tooltip(
                                message: message,
                                child: Icon(
                                  raid.statusKind ==
                                          WeeklyRaidStatusKind.inconsistent
                                      ? Icons.error_outline
                                      : Icons.info_outline,
                                  size: 16,
                                  color:
                                      raid.statusKind ==
                                          WeeklyRaidStatusKind.inconsistent
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (reservedWeeklyRaidRows > weeklyRaids.length)
                    SizedBox(
                      key: const ValueKey('weeklyRaidReservedArea'),
                      height:
                          raidRowHeight *
                          (reservedWeeklyRaidRows - weeklyRaids.length),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _weeklyGrid(BuildContext context) {
    final count = weeklyRaids.length > reservedWeeklyRaidRows
        ? weeklyRaids.length
        : reservedWeeklyRaidRows;
    return Column(
      children: [
        for (var offset = 0; offset < count; offset += 3)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < 3; col++)
                Expanded(
                  child: offset + col >= weeklyRaids.length
                      ? const SizedBox(height: 54)
                      : _weeklyCell(context, weeklyRaids[offset + col]),
                ),
            ],
          ),
      ],
    );
  }

  Widget _weeklyCell(BuildContext context, WeeklyRaidStatusItem raid) {
    final allowed =
        onWeeklyRaidChanged != null &&
        raid.canToggle &&
        !busyRaidIds.contains(raid.raidId);
    return SizedBox(
      height: 54,
      child: Column(
        children: [
          SizedBox(
            height: 20,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                raid.label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, box) => SizedBox(
              height: 30,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 26,
                      height: 28,
                      child: Checkbox(
                        key: ValueKey(
                          'weeklyRaidClaim-${character.serverCharacterId}-${raid.raidId}',
                        ),
                        value: raid.isCompleted,
                        onChanged: allowed
                            ? (v) => onWeeklyRaidChanged!(raid, v ?? false)
                            : null,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  if (raid.statusMessage != null)
                    Positioned(
                      left: box.maxWidth / 2 + 14,
                      right: 0,
                      top: 5,
                      bottom: 5,
                      child: Tooltip(
                        message: raid.statusMessage!,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onWeeklyRaidInfo == null
                              ? null
                              : () => onWeeklyRaidInfo!(raid),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Icon(
                              raid.statusKind ==
                                      WeeklyRaidStatusKind.inconsistent
                                  ? Icons.error_outline
                                  : Icons.info_outline,
                              size: 16,
                              color:
                                  raid.statusKind ==
                                      WeeklyRaidStatusKind.inconsistent
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double? value) {
    if (value == null) {
      return '-';
    }
    return DisplayNumberFormatter.integer(value);
  }

  List<_GemValidationDisplayItem> get _gemValidationItems {
    final summary = gemValidationSummary;
    if (summary == null) {
      return const [];
    }
    return [
      if (summary.hasGemSlotCountError)
        _GemValidationDisplayItem(
          '보석 부족 ${summary.equippedGemCount}/11',
          isError: true,
        ),
      if (summary.foreignClassCount > 0)
        _GemValidationDisplayItem(
          '타 직업 보석 ${summary.foreignClassCount}개',
          isError: true,
        ),
      if (summary.hasUnmatchedSkillError)
        _GemValidationDisplayItem(
          '스킬 불일치 보석 ${summary.unverifiedSameClassCount}개',
          isError: true,
        ),
    ];
  }
}

class _GemValidationDisplayItem {
  const _GemValidationDisplayItem(this.label, {required this.isError});

  final String label;
  final bool isError;
}
