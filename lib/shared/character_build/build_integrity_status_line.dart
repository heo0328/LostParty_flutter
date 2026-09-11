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
    final labels = snapshot.displayLabels;
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isError = snapshot.status == BuildIntegrityStatus.error;
    final color = isError
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Wrap(
      key: ValueKey(keyName),
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
      ],
    );
  }
}
