import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';

import '../../domain/entities/local_game_account.dart';
import '../models/weekly_raid_status_item.dart';

class AccountCharacterCard extends StatelessWidget {
  const AccountCharacterCard({
    required this.character,
    required this.isRepresentative,
    this.weeklyRaids = const [],
    this.onTap,
    super.key,
  });

  final LocalAccountCharacter character;
  final bool isRepresentative;
  final List<WeeklyRaidStatusItem> weeklyRaids;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      character.characterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (isRepresentative)
                    const Tooltip(
                      message: '대표 캐릭터',
                      child: Icon(Icons.star, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                character.characterClassName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                '아이템 Lv. ${_formatNumber(character.itemLevel)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '전투력 ${_formatNumber(character.combatPower)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (weeklyRaids.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '주간 레이드 · 읽기 전용',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                for (final raid in weeklyRaids)
                  SizedBox(
                    height: 30,
                    child: Row(
                      children: [
                        IgnorePointer(
                          child: Checkbox(
                            key: ValueKey(
                              'weeklyRaidClaim-${character.serverCharacterId}-${raid.raidId}',
                            ),
                            value: raid.isCompleted,
                            onChanged: null,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            raid.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
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
