import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/formatters/local_date_time_formatter.dart';
import '../viewmodels/member_lostark_key.dart';
import '../widgets/server_accounts_panel.dart';

class MemberKeyPage extends StatefulWidget {
  const MemberKeyPage({required this.model, required this.onLogin, super.key});
  final MemberLostArkKey model;
  final VoidCallback onLogin;
  @override
  State<MemberKeyPage> createState() => _MemberKeyPageState();
}

class _MemberKeyPageState extends State<MemberKeyPage> {
  final input = TextEditingController();
  bool hidden = true;
  Object? scope;
  @override
  void initState() {
    super.initState();
    widget.model.addListener(_changed);
    _changed();
    widget.model.reload();
  }

  void _changed() {
    final key = (widget.model.session.userId, widget.model.session.generation);
    if (scope != key || widget.model.notice != null) input.clear();
    scope = key;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.model.removeListener(_changed);
    widget.model.leaveEditor();
    input.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final captured = scope;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('키를 삭제할까요?'),
        content: const Text('새 조회·갱신에는 키를 다시 등록해야 합니다. 기존 원정대와 캐릭터 정보는 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (mounted && accepted == true && captured == scope) {
      await widget.model.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return Scaffold(
      appBar: AppBar(title: const Text('로스트아크 API 키')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!model.signedIn) ...[
            const Text('로그인하면 계정에 키를 저장하고 다른 기기에서도 가져올 수 있습니다.'),
            FilledButton(onPressed: widget.onLogin, child: const Text('로그인')),
            TextButton(
              onPressed: () => context.push('/settings/device-api-token'),
              child: const Text('비로그인 기기용 키 관리'),
            ),
          ] else ...[
            Text(
              model.value == null
                  ? '등록 상태 확인 필요'
                  : model.value!.configured
                  ? '계정에 키가 저장되어 있습니다'
                  : '등록된 키가 없습니다',
            ),
            if (model.value?.updatedAt case final time?)
              Text('마지막 변경: ${localDateTimeToSeconds(time)}'),
            Text(
              model.localReady
                  ? '이 기기에 키가 저장되어 있습니다'
                  : model.value?.configured == true
                  ? '이 기기에서 키를 불러와 주세요'
                  : '키 등록 후 이 기기에 함께 저장됩니다',
            ),
            const SizedBox(height: 12),
            const Text('등록한 키는 계정에 보관되며 다른 기기에서도 불러올 수 있습니다.'),
            if (model.busy) const LinearProgressIndicator(),
            if (model.notice != null) Text(model.notice!),
            if (model.failure case final failure?)
              AccountReadFailure(failure: failure),
            TextButton(
              onPressed: model.busy ? null : model.reload,
              child: const Text('키 다시 불러오기'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: input,
              obscureText: hidden,
              autocorrect: false,
              enableSuggestions: false,
              enabled: model.canChange,
              decoration: InputDecoration(
                labelText: model.value?.configured == true
                    ? '새 API 키'
                    : 'API 키',
                helperText: '로스트아크 개발자 페이지에서 발급받은 키를 붙여 넣어 주세요.',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => hidden = !hidden),
                  icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            FilledButton(
              onPressed: model.canChange
                  ? () async {
                      final raw = input.text;
                      if (MemberLostArkKey.validToken(raw)) input.clear();
                      await model.save(raw);
                    }
                  : null,
              child: Text(model.value?.configured == true ? '새 키로 교체' : '키 등록'),
            ),
            if (model.value?.configured == true)
              TextButton(
                onPressed: model.canChange ? _delete : null,
                child: const Text('키 삭제'),
              ),
            if (model.hasPending) ...[
              const Text('키 저장 결과를 확인하지 못했습니다. 다시 확인해 주세요.'),
              TextButton(
                onPressed: model.canRetry ? model.retry : null,
                child: const Text('저장 결과 다시 확인'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
