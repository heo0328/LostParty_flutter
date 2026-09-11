import 'package:flutter/material.dart';
import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

/// 그룹 활동 Character 목록용 Build 무결성 상태 Chip.
class BuildIntegrityStatusLine extends StatelessWidget {
  const BuildIntegrityStatusLine({
    super.key,
    required this.snapshot,
    required this.keyName,
  });

  final BuildIntegritySnapshot snapshot;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final items = snapshot.displayItems;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Wrap(
      key: ValueKey(keyName),
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: (item.isError
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant)
                    .withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: item.isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
