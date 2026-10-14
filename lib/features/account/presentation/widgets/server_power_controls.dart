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
            label: const Text('전투력 갱신'),
          ),
          const Text('아이템 레벨 1700 이상 캐릭터를 한 번에 최대 20명까지 확인합니다.'),
          if (writes.busy || model.loading) const LinearProgressIndicator(),
          if (writes.retrySeconds > 0)
            Text('호출 한도에 도달했습니다. 약 ${writes.retrySeconds}초 후 다시 시도해 주세요.'),
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
            const Text('갱신 결과를 확인하지 못했습니다. 다시 확인하거나 현재 캐릭터 정보를 확인해 주세요.'),
            TextButton(
              onPressed: writes.canRetry ? model.retry : null,
              child: const Text('갱신 결과 다시 확인'),
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
                          title: const Text('현재 전투력 확인'),
                          content: const Text(
                            '현재 표시된 전투력을 확인하셨나요? 확인을 마쳐도 진행 중인 갱신 결과는 나중에 반영될 수 있습니다.',
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
              child: const Text('현재 캐릭터 정보 확인'),
            ),
          ],
        ],
      );
    },
  );
}
