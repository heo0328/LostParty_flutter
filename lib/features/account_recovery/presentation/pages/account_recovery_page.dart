import 'package:flutter/material.dart';

import '../../domain/entities/account_recovery_status.dart';
import '../../domain/repositories/account_recovery_repository.dart';

class AccountRecoveryPage extends StatefulWidget {
  const AccountRecoveryPage({required this.repository, super.key});

  final AccountRecoveryRepository repository;

  @override
  State<AccountRecoveryPage> createState() => _AccountRecoveryPageState();
}

class _AccountRecoveryPageState extends State<AccountRecoveryPage> {
  AccountRecoveryStatus? _status;
  AccountRecoveryException? _loadError;
  bool _linking = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await widget.repository.loadStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loadError = null;
      });
    } on AccountRecoveryException catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _linkGoogle() async {
    if (_linking) return;
    setState(() => _linking = true);
    try {
      final result = await widget.repository.linkGoogle();
      if (!mounted) return;
      if (result == AccountRecoveryLinkResult.cancelled) return;
      await _loadStatus();
      if (!mounted) return;
      final message = result == AccountRecoveryLinkResult.alreadyLinked
          ? '이미 Google 계정이 연결되어 있습니다.'
          : 'Google 계정을 복구 수단으로 연결했습니다.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on AccountRecoveryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_failureMessage(error.reason))));
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  String _failureMessage(AccountRecoveryFailureReason reason) =>
      switch (reason) {
        AccountRecoveryFailureReason.credentialAlreadyInUse =>
          '이 Google 계정은 다른 LOSTPARTY 사용자에게 이미 연결되어 있습니다. 현재 데이터는 변경되지 않았습니다.',
        AccountRecoveryFailureReason.providerNotEnabled =>
          'Google 계정 연결이 아직 준비되지 않았습니다.',
        AccountRecoveryFailureReason.invalidCredential =>
          'Google 계정 정보를 확인하지 못했습니다. 다시 시도해 주세요.',
        AccountRecoveryFailureReason.network => '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
        AccountRecoveryFailureReason.tooManyRequests =>
          '요청이 너무 많습니다. 잠시 뒤 다시 시도해 주세요.',
        AccountRecoveryFailureReason.recoveryAccountNotFound =>
          '연결된 기존 LOSTPARTY 사용자를 찾을 수 없습니다.',
        AccountRecoveryFailureReason.noAuthenticatedUser =>
          '현재 LOSTPARTY 사용자 정보를 찾을 수 없습니다.',
        AccountRecoveryFailureReason.uidChanged ||
        AccountRecoveryFailureReason.unknown =>
          '계정 연결을 완료하지 못했습니다. 현재 데이터는 변경되지 않았습니다.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 복구 설정')),
      body: Padding(padding: const EdgeInsets.all(16), child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_failureMessage(_loadError!.reason)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadStatus, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    final status = _status;
    if (status == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  status.isGoogleLinked
                      ? Icons.verified_user_outlined
                      : Icons.phonelink_lock_outlined,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  status.isGoogleLinked
                      ? 'Google 계정 연결 완료'
                      : '재설치 전에 복구 수단을 연결해 주세요',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  status.isGoogleLinked
                      ? '앱 재설치나 기기 변경 뒤에도 같은 LOSTPARTY 사용자와 기존 데이터를 복구할 수 있습니다.'
                      : '현재 사용자는 임시 익명 계정입니다. Google 계정을 연결하면 기존 원정대·그룹·파티 데이터의 사용자 ID가 그대로 유지됩니다.',
                  textAlign: TextAlign.center,
                ),
                if (!status.isGoogleLinked) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('linkGoogleRecoveryButton'),
                    onPressed: _linking ? null : _linkGoogle,
                    icon: _linking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: const Text('Google 계정 연결'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '다른 LOSTPARTY 사용자에게 이미 연결된 Google 계정은 합쳐지지 않습니다. 연결 실패나 취소 시 현재 사용자와 데이터는 바뀌지 않습니다.',
        ),
      ],
    );
  }
}
