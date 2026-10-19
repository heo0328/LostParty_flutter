import 'package:flutter/material.dart';
import '../../../account/presentation/widgets/ownership_notice_title.dart';
import 'package:go_router/go_router.dart';

import '../../../operator_access/domain/repositories/operator_access_repository.dart';
import '../../../auth/domain/auth_session_controller.dart';
import '../../../auth/presentation/login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({this.operatorAccessRepository, this.auth, super.key});

  final OperatorAccessRepository? operatorAccessRepository;
  final AuthSessionController? auth;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Future<bool> _isOperator =
      widget.operatorAccessRepository?.isCurrentPlayerOperator() ??
      Future.value(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const OwnershipNoticeTitle(child: Text('설정'))),
      body: ListView(
        children: [
          if (widget.auth case final auth?)
            ListenableBuilder(
              listenable: auth,
              builder: (context, _) => Column(
                children: [
                  ListTile(
                    title: Text(
                      auth.isAuthenticated ? 'Google 로그인 연결됨' : 'Google 로그인',
                    ),
                    subtitle: Text(
                      auth.isBusy
                          ? '로그인 상태 확인 중'
                          : (auth.isAuthenticated
                                ? '로그인 유지: ${auth.remember ? "사용" : "사용 안 함"}'
                                : '로컬 기능은 로그인 없이 이용할 수 있습니다.'),
                    ),
                    onTap: auth.isBusy || auth.isAuthenticated
                        ? null
                        : () => context.push('/login'),
                  ),
                  if (auth.isAuthenticated)
                    ListTile(
                      title: const Text('로그아웃'),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('로그아웃할까요?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('취소'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('로그아웃'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) await auth.logout();
                      },
                    ),
                  if (auth.errorCode != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(authErrorMessage(auth.errorCode!)),
                    ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('로스트아크 연동'),
          ),
          ListTile(
            key: const ValueKey('settingsGameAccountVerification'),
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('내 게임계정 인증'),
            subtitle: const Text('게임 계정 소유권을 인증하거나 다시 확인합니다.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/game-account-verification'),
          ),
          ListTile(
            key: const ValueKey('settingsManualVerification'),
            leading: const Icon(Icons.chat_outlined),
            title: const Text('수동 인증'),
            subtitle: const Text('인게임 채팅 코드로 운영자 인증을 요청합니다.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/manual-verification'),
          ),
          ListTile(
            key: const ValueKey('settingsApiToken'),
            leading: const Icon(Icons.key_outlined),
            title: const Text('Lost Ark API 토큰'),
            subtitle: const Text('계정과 캐릭터 조회에 사용할 토큰을 관리합니다.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/api-token'),
          ),
          FutureBuilder<bool>(
            future: _isOperator,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('운영자'),
                  ),
                  ListTile(
                    key: const ValueKey('settingsOperatorUsers'),
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('사용자 확인'),
                    subtitle: const Text('마지막 접속과 서버 인증 계정을 확인합니다.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/operator/users'),
                  ),
                  ListTile(
                    key: const ValueKey('settingsOperatorManualVerification'),
                    leading: const Icon(Icons.fact_check_outlined),
                    title: const Text('수동 인증 확인'),
                    subtitle: const Text('인게임 채팅 증명을 확인하고 판정합니다.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/settings/operator/manual-verification'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
