import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A persistent, actionable error within the affected screen, not a popup.
class RecoveryNoticeCard extends StatelessWidget {
  const RecoveryNoticeCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    this.onAction,
    this.diagnostic,
    this.loading = false,
    super.key,
  });
  final String title, message, actionLabel;
  final String? diagnostic;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        border: Border.all(color: colors.error),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: colors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: colors.onErrorContainer)),
          if (diagnostic case final text? when text.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('오류 정보'),
              children: [
                SelectableText(text),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('오류 정보 복사'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('오류 정보를 복사했습니다.')),
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: loading ? null : onAction,
            child: Text(actionLabel),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
