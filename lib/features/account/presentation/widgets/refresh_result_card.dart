import 'package:flutter/material.dart';
import '../../domain/scoped_startup_refresh.dart';

/// One presentation for automatic, verified and manually refreshed rosters.
class RefreshResultCard extends StatelessWidget {
  const RefreshResultCard({
    super.key,
    required this.title,
    required this.items,
    required this.busy,
    required this.message,
    required this.failureMessage,
    this.progress = const [],
    this.onClose,
    this.onRetry,
    this.onRecover,
    this.onPrepare,
  });
  final String title, message;
  final List<ScopedRefreshItem> items;
  final List<String> progress;
  final bool busy;
  final String Function(String?) failureMessage;
  final VoidCallback? onClose, onRetry, onRecover, onPrepare;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onClose != null)
                IconButton(
                  key: const ValueKey('dismiss-automatic-refresh-result'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: '결과 닫기',
                ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
          for (final text in progress) Text(text),
          if (busy)
            const Text('캐릭터 정보를 갱신하고 있습니다.')
          else
            Text(
              '처리 ${items.where((i) => i.status != ScopedRefreshStatus.queued && i.status != ScopedRefreshStatus.interrupted).length}/${items.length} · 저장 ${items.where((i) => i.status == ScopedRefreshStatus.saved).length} · 경고 ${items.where((i) => i.warning).length}\n미완료 ${items.where((i) => i.incomplete && !i.serverPending).length} · 정책 제외 ${items.where((i) => i.status == ScopedRefreshStatus.excluded).length} · 갱신 결과 확인 대기 ${items.where((i) => i.serverPending).length}',
            ),
          if (message.isNotEmpty) Text(message),
          if (!busy && items.isEmpty && message.isEmpty)
            const Text('갱신할 캐릭터가 없습니다.'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onPrepare != null)
                OutlinedButton(
                  onPressed: onPrepare,
                  child: const Text('준비 상태 다시 확인'),
                ),
              if (onRetry != null)
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('미완료 캐릭터 다시 시도'),
                ),
              if (onRecover != null)
                OutlinedButton(
                  onPressed: onRecover,
                  child: const Text('갱신 결과 확인'),
                ),
            ],
          ),
          for (final item in items.where(
            (i) =>
                i.status != ScopedRefreshStatus.saved ||
                i.warning ||
                i.serverPending ||
                i.code != null,
          ))
            Text(
              '${item.target.character.characterName} · ${item.target.character.serverName} · ${item.target.registration.label.isEmpty ? (item.target.registration.isMain ? '본계정' : '부계정') : item.target.registration.label} · ${item.serverPending
                  ? '갱신 결과 확인 대기'
                  : item.code != null
                  ? failureMessage(item.code)
                  : item.warning
                  ? '저장 완료 · 빌드 확인 필요'
                  : '처리 대기'}',
            ),
        ],
      ),
    ),
  );
}
