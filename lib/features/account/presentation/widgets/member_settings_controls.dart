import 'package:flutter/material.dart';
import '../viewmodels/member_settings_view_model.dart';

class MemberSettingsControls extends StatelessWidget {
  const MemberSettingsControls({
    required this.model,
    required this.classes,
    this.onLogin,
    super.key,
  });
  final MemberSettingsViewModel model;
  final String classes;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const ValueKey('niceGroupAutoRefreshSwitch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('나이스단 자동 갱신'),
          subtitle: Text(
            !model.signedIn
                ? '로그인하면 계정에 저장된 설정을 사용할 수 있습니다.'
                : model.busy
                ? '서버 설정 확인·저장 중입니다.'
                : model.value == null
                ? '설정을 불러오지 못했습니다. 다시 확인해 주세요.'
                : '$classes 직업군 전체에 적용됩니다. 변경 즉시 저장됩니다.\n현재는 허용 설정을 저장하며 자동 빌드 갱신은 준비 중입니다.',
          ),
          value: model.value?.enabled ?? false,
          onChanged: model.canChange ? model.change : null,
        ),
        if (model.busy) const LinearProgressIndicator(),
        if (!model.signedIn)
          TextButton(onPressed: onLogin, child: const Text('로그인')),
        if (model.notice case final notice?) Text(notice),
        if (model.failure != null)
          Text(
            model.hasPending
                ? '저장 결과를 확인하지 못했습니다. 같은 요청을 재시도하거나 서버 상태를 확인해 주세요.'
                : '설정을 확인하거나 저장하지 못했습니다. 다시 시도해 주세요.',
          ),
        if (model.signedIn &&
            !model.busy &&
            (model.hasPending || model.failure != null))
          Wrap(
            children: [
              if (model.hasPending)
                TextButton(
                  onPressed: model.canRetry ? model.retry : null,
                  child: const Text('저장 재시도'),
                ),
              TextButton(
                onPressed: model.reload,
                child: const Text('서버 설정 확인'),
              ),
              if (model.hasPending && model.reviewed)
                TextButton(
                  onPressed: () async {
                    final scopeUser = model.session.userId;
                    final generation = model.session.generation;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('요청 확인을 마칠까요?'),
                        content: const Text(
                          '조회한 서버 설정을 유지합니다. 처리 중이던 요청은 나중에 반영될 수 있습니다.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true &&
                        model.session.userId == scopeUser &&
                        model.session.generation == generation) {
                      model.finishReview();
                    }
                  },
                  child: const Text('요청 확인 종료'),
                ),
            ],
          ),
      ],
    ),
  );
}
