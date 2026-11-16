import 'package:flutter/material.dart';

import '../../domain/account_read_session.dart';
import '../viewmodels/server_account_read_view_model.dart';

String serverOwnershipLabel(String state) => switch (state) {
  'owned' => '',
  'ownership_lost' => '원정대 재인증 필요',
  _ => '원정대 인증 필요',
};
String serverConfigurationLabel(String state) => switch (state) {
  'configured' => '',
  'needs_reconfiguration' => '활동 캐릭터를 다시 선택해 주세요',
  _ => '활동 캐릭터 미선택',
};

String serverAccountActionLabel(String ownership, String configuration) => [
  serverOwnershipLabel(ownership),
  serverConfigurationLabel(configuration),
].where((label) => label.isNotEmpty).join(' · ');

String accountReadErrorMessage(
  AccountReadException failure,
) => switch (failure.code) {
  'ALREADY_VERIFIED' => '이미 인증된 원정대입니다.',
  'CURSOR_STALE' || 'REVISION_CONFLICT' => '조회 중 계정 정보가 변경되었습니다. 다시 조회해 주세요.',
  'OWNERSHIP_REQUIRED' => '이 계정의 현재 소유 권한이 필요합니다.',
  'REGISTRATION_NOT_FOUND' => '등록된 계정을 찾을 수 없습니다. 계정 목록을 다시 조회해 주세요.',
  'RATE_LIMITED' => '조회 한도를 초과했습니다. 잠시 후 다시 조회해 주세요.',
  'UPSTREAM_RATE_LIMITED' => '로스트아크 호출 한도에 도달했습니다. 안내된 시간 후 다시 시도해 주세요.',
  'UPSTREAM_NOT_CONFIGURED' ||
  'LOSTARK_KEY_NOT_CONFIGURED' ||
  'LOSTARK_KEY_REJECTED' ||
  'SERVER_KEY_CHANGED' ||
  'LOSTARK_KEY_CHANGED' ||
  'LOSTARK_KEY_UNAVAILABLE' => '현재 로스트아크 정보를 갱신할 수 없습니다. 저장된 정보는 계속 볼 수 있습니다.',
  'INVALID_RESPONSE' => '계정 정보를 확인하지 못했습니다. 다시 조회해 주세요.',
  'UPSTREAM_UNAVAILABLE' ||
  'NETWORK_UNAVAILABLE' => '서버에 연결하지 못했습니다. 잠시 후 다시 조회해 주세요.',
  _ => '계정 정보를 불러오지 못했습니다. 로그인 상태와 연결을 확인해 주세요.',
};

class AccountReadFailure extends StatelessWidget {
  const AccountReadFailure({required this.failure, super.key});
  final AccountReadException failure;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(accountReadErrorMessage(failure)),
      if (failure.retryAfter != null)
        Text('${failure.retryAfter!.inSeconds}초 후 다시 시도해 주세요.'),
    ],
  );
}

class ServerAccountsPanel extends StatelessWidget {
  const ServerAccountsPanel({
    required this.viewModel,
    required this.onLogin,
    required this.onOpen,
    this.onManage,
    super.key,
  });
  final ServerAccountReadViewModel viewModel;
  final VoidCallback onLogin;
  final VoidCallback? onManage;
  final void Function(String) onOpen;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '등록한 원정대',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (viewModel.canRead)
                  IconButton(
                    tooltip: '원정대 목록 새로고침',
                    onPressed: viewModel.loading ? null : viewModel.load,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            if (viewModel.canRead && onManage != null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('원정대 등록·관리'),
                ),
              ),
            if (!viewModel.canRead) ...[
              const Text('로그인하면 등록한 원정대를 확인할 수 있습니다.'),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: onLogin,
                  child: const Text('로그인'),
                ),
              ),
            ] else if (viewModel.loading)
              const LinearProgressIndicator()
            else if (viewModel.failure != null)
              AccountReadFailure(failure: viewModel.failure!)
            else if (viewModel.loaded && viewModel.registrations.isEmpty)
              const Text('등록한 원정대가 없습니다.')
            else
              for (final account in viewModel.registrations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${viewModel.displayLabelFor(account)}${account.isMain ? ' · 본계정' : ' · 부계정'}',
                  ),
                  subtitle: Text(
                    '${serverAccountActionLabel(account.ownershipStatus, account.settings.configurationState)}'
                    '${serverAccountActionLabel(account.ownershipStatus, account.settings.configurationState).isEmpty ? '' : '\n'}'
                    '캐릭터 ${account.characterCount}명'
                    '${account.representativeSummary == null ? '' : ' · 대표 ${account.representativeSummary!.characterName}'}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpen(account.registrationId),
                ),
          ],
        ),
      ),
    ),
  );
}
