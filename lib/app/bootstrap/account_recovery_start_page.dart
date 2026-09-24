import 'package:flutter/material.dart';

import '../../features/account_recovery/domain/entities/account_recovery_status.dart';
import '../../features/player/domain/entities/player_session.dart';

class AccountRecoveryStartPage extends StatefulWidget {
  const AccountRecoveryStartPage({
    required this.recover,
    required this.startNew,
    required this.onReady,
    super.key,
  });

  final Future<PlayerSession?> Function() recover;
  final Future<PlayerSession> Function() startNew;
  final ValueChanged<PlayerSession> onReady;

  @override
  State<AccountRecoveryStartPage> createState() =>
      _AccountRecoveryStartPageState();
}

class _AccountRecoveryStartPageState extends State<AccountRecoveryStartPage> {
  bool _busy = false;
  String? _errorMessage;

  Future<void> _recover() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final session = await widget.recover();
      if (session != null && mounted) widget.onReady(session);
    } on AccountRecoveryException catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(error.reason));
    } on Object {
      if (mounted) {
        setState(() => _errorMessage = '기존 계정을 복구하지 못했습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmStartNew(BuildContext dialogHostContext) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: dialogHostContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('새 사용자로 시작할까요?'),
        content: const Text(
          '새 익명 사용자가 만들어집니다. 이전에 Google 계정을 연결했다면 취소하고 기존 계정 복구를 선택해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmStartNewAccountButton'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('새로 시작'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final session = await widget.startNew();
      if (mounted) widget.onReady(session);
    } on Object {
      if (mounted) {
        setState(() => _errorMessage = '새 사용자 준비를 완료하지 못했습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(AccountRecoveryFailureReason reason) => switch (reason) {
    AccountRecoveryFailureReason.providerNotEnabled =>
      'Google 계정 복구가 아직 준비되지 않았습니다.',
    AccountRecoveryFailureReason.invalidCredential =>
      'Google 계정 정보를 확인하지 못했습니다. 다시 시도해 주세요.',
    AccountRecoveryFailureReason.network => '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
    AccountRecoveryFailureReason.tooManyRequests =>
      '요청이 너무 많습니다. 잠시 뒤 다시 시도해 주세요.',
    AccountRecoveryFailureReason.recoveryAccountNotFound =>
      '이 Google 계정에 연결된 기존 LOSTPARTY 사용자가 없습니다. 다른 Google 계정을 선택하거나 새로 시작해 주세요.',
    _ => '기존 계정을 복구하지 못했습니다. 다시 시도해 주세요.',
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LOSTPARTY',
      home: Builder(
        builder: (pageContext) => Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.phonelink_lock_outlined, size: 56),
                      const SizedBox(height: 20),
                      Text(
                        'LOSTPARTY 시작',
                        style: Theme.of(pageContext).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '이 기기에서 사용할 사용자를 선택해 주세요. 이전 기기에서 Google 계정을 연결했다면 기존 원정대·그룹·파티 데이터를 복구할 수 있습니다.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        key: const ValueKey('recoverExistingAccountButton'),
                        onPressed: _busy ? null : _recover,
                        icon: const Icon(Icons.restore),
                        label: const Text('Google로 기존 계정 복구'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        key: const ValueKey('startNewAccountButton'),
                        onPressed: _busy
                            ? null
                            : () => _confirmStartNew(pageContext),
                        child: const Text('새로 시작'),
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 20),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      if (_errorMessage case final message?) ...[
                        const SizedBox(height: 20),
                        Text(
                          message,
                          key: const ValueKey('accountRecoveryStartError'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(pageContext).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
