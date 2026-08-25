import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
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
            key: const ValueKey('settingsApiToken'),
            leading: const Icon(Icons.key_outlined),
            title: const Text('Lost Ark API 토큰'),
            subtitle: const Text('계정과 캐릭터 조회에 사용할 토큰을 관리합니다.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/api-token'),
          ),
        ],
      ),
    );
  }
}
