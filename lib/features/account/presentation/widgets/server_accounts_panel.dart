import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

String accountReadErrorMessage(AccountReadException failure) =>
    switch (failure.code) {
      'ALREADY_VERIFIED' => '이미 인증된 원정대입니다.',
      'CURSOR_STALE' ||
      'REVISION_CONFLICT' => '조회 중 계정 정보가 변경되었습니다. 다시 조회해 주세요.',
      'OWNERSHIP_REQUIRED' => '이 계정의 현재 소유 권한이 필요합니다.',
      'REGISTRATION_NOT_FOUND' => '등록된 계정을 찾을 수 없습니다. 계정 목록을 다시 조회해 주세요.',
      'RATE_LIMITED' => '조회 한도를 초과했습니다. 잠시 후 다시 조회해 주세요.',
      'UPSTREAM_RATE_LIMITED' => '로스트아크 호출 한도에 도달했습니다. 안내된 시간 후 다시 시도해 주세요.',
      'LOSTARK_KEY_NOT_CONFIGURED' => '캐릭터 정보를 불러오려면 로스트아크 API 키를 등록해 주세요.',
      'LOSTARK_KEY_REJECTED' => '등록된 키로 조회할 수 없습니다. 키를 확인하거나 교체해 주세요.',
      'LOSTARK_KEY_CHANGED' => '다른 작업에서 키가 변경되었습니다. 현재 키를 다시 확인해 주세요.',
      'LOSTARK_KEY_UNAVAILABLE' => '등록된 키를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      'KEY_DEVICE_STORAGE_FAILED' =>
        '계정에 키가 등록되어 있지만 이 기기에 저장하지 못했습니다. 키를 다시 불러와 주세요.',
      'INVALID_KEY_FORMAT' => '발급받은 키 전체를 붙여 넣어 주세요. 앞뒤에 공백이 없는지 확인해 주세요.',
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
      if ({
        'LOSTARK_KEY_NOT_CONFIGURED',
        'LOSTARK_KEY_REJECTED',
        'LOSTARK_KEY_CHANGED',
      }.contains(failure.code))
        TextButton(
          onPressed: () => context.push('/settings/api-token'),
          child: const Text('API 키 관리'),
        ),
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
                child: TextButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('원정대 등록·관리'),
                ),
              ),
            if (!viewModel.canRead) ...[
              const Text('로그인하면 등록한 원정대를 확인할 수 있습니다.'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: onLogin, child: const Text('로그인')),
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
