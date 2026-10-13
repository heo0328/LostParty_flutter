import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/auth_session_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.auth,
    this.termsUrl = '',
    this.privacyUrl = '',
    super.key,
  });
  final AuthSessionController auth;
  final String termsUrl, privacyUrl;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _remember = false;

  Future<void> _login() async {
    final router = GoRouter.of(context);
    final success = await widget.auth.login(remember: _remember);
    if (!success || !mounted) return;
    // Auth notification refreshes GoRouter. Navigate after that refresh rather
    // than using the ListenableBuilder's transient context during its rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.auth.isAuthenticated) return;
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/account');
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '로스트파티',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Google 계정으로 로그인하세요. 처음 이용하는 계정은 로스트파티 회원으로 가입됩니다.'),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: widget.auth.isBusy ? null : _login,
                  child: const Text('Google로 계속하기'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _remember,
                  title: const Text('로그인 유지'),
                  subtitle: const Text('선택하면 다음 앱 실행 시 로그인을 복원합니다.'),
                  onChanged: widget.auth.isBusy
                      ? null
                      : (value) => setState(() => _remember = value ?? false),
                ),
                if (widget.auth.isBusy)
                  const Center(child: CircularProgressIndicator()),
                if (widget.auth.errorCode != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      authErrorMessage(widget.auth.errorCode!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (widget.termsUrl.isNotEmpty)
                  TextButton(
                    onPressed: () => _open(widget.termsUrl),
                    child: const Text('서비스 이용약관'),
                  ),
                if (widget.privacyUrl.isNotEmpty)
                  TextButton(
                    onPressed: () => _open(widget.privacyUrl),
                    child: const Text('개인정보 처리방침'),
                  ),
                if (widget.termsUrl.isEmpty || widget.privacyUrl.isEmpty)
                  const Text(
                    '개발 테스트 버전입니다. 서비스 이용약관과 개인정보 처리방침은 정식 서비스 전 제공됩니다.',
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'https') {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

String authErrorMessage(String code) => switch (code) {
  'NETWORK_UNAVAILABLE' ||
  'SERVICE_UNAVAILABLE' ||
  'AUTH_PROVIDER_UNAVAILABLE' => '서버에 연결하지 못했습니다. 인터넷과 개발 서버 상태를 확인해 주세요.',
  'ACCOUNT_DISABLED' => '이용이 제한된 계정입니다.',
  'STORAGE_UNAVAILABLE' => '로그인 정보를 안전하게 저장하지 못했습니다. 다시 시도해 주세요.',
  'LOGOUT_REVOKE_PENDING' => '이 기기에서는 로그아웃했지만 서버 세션 종료를 확인하지 못했습니다.',
  'GOOGLE_AUTH_UNAVAILABLE' =>
    'Google 로그인을 완료하지 못했습니다. 기기 계정과 앱 등록 설정을 확인해 주세요.',
  'RATE_LIMITED' => '요청이 많습니다. 잠시 후 다시 시도해 주세요.',
  _ => '로그인을 완료하지 못했습니다. 다시 로그인해 주세요.',
};

Future<void> showLoginRequired(
  BuildContext context,
  AuthSessionController auth,
) async {
  if (auth.isBusy) return;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('로그인이 필요합니다.'),
      content: const Text('이 기능을 이용하려면 Google 계정으로 로그인해 주세요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('로그인'),
        ),
      ],
    ),
  );
  if (proceed == true && context.mounted) await context.push('/login');
}
