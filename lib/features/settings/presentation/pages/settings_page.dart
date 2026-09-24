import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../operator_access/domain/repositories/operator_access_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({this.operatorAccessRepository, super.key});

  final OperatorAccessRepository? operatorAccessRepository;

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
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('LOSTPARTY 계정'),
          ),
          ListTile(
            key: const ValueKey('settingsAccountRecovery'),
            leading: const Icon(Icons.phonelink_lock_outlined),
            title: const Text('계정 복구 설정'),
            subtitle: const Text('재설치와 기기 변경에 대비해 복구 수단을 연결합니다.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/account-recovery'),
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
