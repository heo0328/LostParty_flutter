import 'package:flutter/material.dart';
import '../viewmodels/server_combat_power_view_model.dart';
import 'server_accounts_panel.dart';

class ServerPowerControls extends StatelessWidget {
  const ServerPowerControls({
    required this.model,
    required this.onRefresh,
    super.key,
  });
  final ServerCombatPowerViewModel model;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final writes = model.writes;
      if (!model.session.isAuthenticated) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: model.canRefresh ? onRefresh : null,
            icon: const Icon(Icons.speed),
            label: const Text('전투력 확인 (1700 이상 · 최대 20명)'),
          ),
          if (writes.busy || model.loading) const LinearProgressIndicator(),
          if (writes.powerContext && writes.notice != null)
            Text(writes.notice!),
          if (writes.powerContext && writes.failure != null)
            AccountReadFailure(failure: writes.failure!),
          if (model.failure != null)
            Text(
              model.failure!.code == 'NO_REGISTERED_POWER_TARGET'
                  ? '같은 서버·캐릭터로 등록한 1700 이상 캐릭터가 없습니다.'
                  : accountReadErrorMessage(model.failure!),
            ),
          if (writes.hasPending) ...[
            const Text('확인할 요청이 남아 있습니다. 같은 요청을 재시도하거나 서버 상태를 확인해 주세요.'),
            TextButton(
              onPressed: writes.canRetry ? model.retry : null,
              child: const Text('같은 요청 다시 시도'),
            ),
            TextButton(
              onPressed: !writes.busy && !model.loading
                  ? () async {
                      final result = await writes.review();
                      await model.reload();
                      if (!context.mounted ||
                          result == null ||
                          model.failure != null ||
                          !writes.canFinishReview) {
                        return;
                      }
                      final accepted = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('서버 상태 확인'),
                          content: const Text(
                            '카드의 현재 서버 전투력을 확인한 뒤 요청 확인을 종료할까요? 처리 중인 요청은 나중에 반영될 수 있습니다.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('유지'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('확인 종료'),
                            ),
                          ],
                        ),
                      );
                      if (accepted == true && context.mounted) {
                        writes.finishReviewedRequest();
                      }
                    }
                  : null,
              child: const Text('현재 서버 상태 확인'),
            ),
          ],
        ],
      );
    },
  );
}
