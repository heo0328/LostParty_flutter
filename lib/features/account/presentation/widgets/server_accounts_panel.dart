import 'package:flutter/material.dart';

import '../../domain/account_read_session.dart';
import '../viewmodels/server_account_read_view_model.dart';

String serverOwnershipLabel(String state) => switch (state) {
  'owned' => '현재 소유 계정',
  'ownership_lost' => '소유권 상실 · 재인증 필요',
  _ => '미인증',
};
String serverConfigurationLabel(String state) => switch (state) {
  'configured' => '활동 설정 완료',
  'needs_reconfiguration' => '활동 캐릭터 재설정 필요',
  _ => '활동 설정 전',
};

String accountReadErrorMessage(AccountReadException failure) =>
    switch (failure.code) {
      'CURSOR_STALE' ||
      'REVISION_CONFLICT' => '조회 중 계정 정보가 변경되었습니다. 다시 조회해 주세요.',
      'OWNERSHIP_REQUIRED' => '이 계정의 현재 소유 권한이 필요합니다.',
      'REGISTRATION_NOT_FOUND' => '등록된 계정을 찾을 수 없습니다. 계정 목록을 다시 조회해 주세요.',
      'RATE_LIMITED' => '조회 한도를 초과했습니다. 잠시 후 다시 조회해 주세요.',
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
      if (failure.requestId != null) Text('문의 식별자: ${failure.requestId}'),
    ],
  );
}

class ServerAccountsPanel extends StatelessWidget {
  const ServerAccountsPanel({
    required this.viewModel,
    required this.onLogin,
    required this.onOpen,
    super.key,
  });
  final ServerAccountReadViewModel viewModel;
  final VoidCallback onLogin;
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
                    '서버에 등록한 계정',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (viewModel.canRead)
                  IconButton(
                    tooltip: '서버 계정 다시 조회',
                    onPressed: viewModel.loading ? null : viewModel.load,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            if (!viewModel.canRead) ...[
              const Text('로그인하면 서버에 등록한 계정을 확인할 수 있습니다.'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: onLogin, child: const Text('로그인')),
              ),
            ] else if (viewModel.loading)
              const LinearProgressIndicator()
            else if (viewModel.failure != null)
              AccountReadFailure(failure: viewModel.failure!)
            else if (viewModel.loaded && viewModel.registrations.isEmpty)
              const Text('서버에 등록한 계정이 없습니다.')
            else
              for (final account in viewModel.registrations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${account.label}${account.isMain ? ' · 본계정' : ' · 부계정'}',
                  ),
                  subtitle: Text(
                    '${serverOwnershipLabel(account.ownershipStatus)} · '
                    '${serverConfigurationLabel(account.settings.configurationState)}\n'
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
