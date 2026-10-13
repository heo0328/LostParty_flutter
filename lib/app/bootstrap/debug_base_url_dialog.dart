import 'package:flutter/material.dart';

class DebugBaseUrlDialog extends StatefulWidget {
  const DebugBaseUrlDialog({
    required this.initialUrl,
    required this.defaultUrl,
    required this.validate,
    super.key,
  });
  final String initialUrl, defaultUrl;
  final bool Function(String) validate;
  @override
  State<DebugBaseUrlDialog> createState() => _DebugBaseUrlDialogState();
}

class _DebugBaseUrlDialogState extends State<DebugBaseUrlDialog> {
  late final _controller = TextEditingController(text: widget.initialUrl);
  String? _error;
  void _confirm() {
    final entered = _controller.text.trim();
    final url = entered.isEmpty ? widget.defaultUrl : entered;
    if (!widget.validate(url)) {
      setState(() => _error = 'http:// 또는 https://로 시작하는 서버 주소를 입력해 주세요.');
      return;
    }
    Navigator.of(context).pop(url);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: const Text('개발 서버 Base URL'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이번 앱 실행에서 사용할 서버 주소를 입력해 주세요.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Base URL',
              hintText: widget.defaultUrl,
              errorText: _error,
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 12),
          Text('빈 입력은 ${widget.defaultUrl}을 사용합니다.'),
          const Text('Android 에뮬레이터에서 10.0.2.2는 PC의 localhost에 연결됩니다.'),
        ],
      ),
      actions: [FilledButton(onPressed: _confirm, child: const Text('확인'))],
    ),
  );
}
