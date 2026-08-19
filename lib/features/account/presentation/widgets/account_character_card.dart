import 'package:flutter/material.dart';

import '../../domain/entities/local_game_account.dart';

class AccountCharacterCard extends StatelessWidget {
  const AccountCharacterCard({
    required this.character,
    required this.isRepresentative,
    this.onTap,
    super.key,
  });

  final LocalAccountCharacter character;
  final bool isRepresentative;
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
              Text('아이템 Lv. ${_formatNumber(character.itemLevel)}'),
              Text('전투력 ${_formatNumber(character.combatPower)}'),
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
    return value.toStringAsFixed(2);
  }
}
