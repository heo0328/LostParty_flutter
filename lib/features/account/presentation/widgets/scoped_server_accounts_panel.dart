import 'dart:async';

import 'package:flutter/material.dart';

import '../viewmodels/scoped_account_view_model.dart';
import 'scoped_account_status.dart';
import 'server_accounts_panel.dart';

class ScopedServerAccountsPanel extends StatefulWidget {
  const ScopedServerAccountsPanel({
    required this.model,
    required this.onLogin,
    required this.onManage,
    required this.onOpen,
    required this.onHistory,
    super.key,
  });
  final ScopedAccountViewModel model;
  final VoidCallback onLogin;
  final Future<void> Function() onManage, onHistory;
  final Future<void> Function(String) onOpen;
  @override
  State<ScopedServerAccountsPanel> createState() =>
      _ScopedServerAccountsPanelState();
}

class _ScopedServerAccountsPanelState extends State<ScopedServerAccountsPanel> {
  bool _navigating = false;
  void _initialize() {
    final model = widget.model;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(model, widget.model)) {
        unawaited(model.initialize());
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant ScopedServerAccountsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.model, widget.model)) _initialize();
  }

  Future<void> _navigate(Future<void> Function() action) async {
    if (_navigating) return;
    setState(() => _navigating = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final m = widget.model, labels = scopedAccountLabels(widget.model);
      final busy = m.loading || _navigating;
      return Card(
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
                  if (m.canRead)
                    IconButton(
                      tooltip: '원정대 목록 새로고침',
                      onPressed: busy || m.retrySeconds > 0
                          ? null
                          : m.refreshRegistrations,
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
              if (!m.canRead) ...[
                const Text('로그인하면 등록한 원정대를 확인할 수 있습니다.'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.onLogin,
                    child: const Text('로그인'),
                  ),
                ),
              ] else ...[
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : () => _navigate(widget.onManage),
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('원정대 등록·관리'),
                    ),
                    TextButton.icon(
                      onPressed: _navigating
                          ? null
                          : () => _navigate(widget.onHistory),
                      icon: const Icon(Icons.history),
                      label: const Text('사라진 캐릭터명 기록'),
                    ),
                  ],
                ),
                if (m.loading) const LinearProgressIndicator(),
                if (!m.registrationsCurrent && m.registrations.isNotEmpty)
                  Text(
                    m.failure == null
                        ? '이전 확인 정보 · 다시 확인 중'
                        : '이전 확인 정보 · 최신 상태 확인 실패',
                  ),
                if (m.failure case final failure?)
                  ScopedAccountFailureMessage(
                    failure: failure,
                    seconds: m.retrySeconds,
                  ),
                if (m.registrationsCurrent && m.registrations.isEmpty)
                  const Text('등록한 원정대가 없습니다.'),
                for (final r in m.registrations)
                  Builder(
                    builder: (_) {
                      final meta = m.registrationsCurrent
                          ? m.metadata
                                .where(
                                  (v) => v.registrationId == r.registrationId,
                                )
                                .firstOrNull
                          : null;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${labels[r.registrationId]}${r.isMain ? ' · 본계정' : ' · 부계정'}',
                        ),
                        subtitle: Text(
                          '${serverAccountActionLabel(r.ownershipStatus, r.settings.state)}'
                          '${serverAccountActionLabel(r.ownershipStatus, r.settings.state).isEmpty ? '' : '\n'}'
                          '${meta == null ? '캐릭터 상태 확인 필요' : '캐릭터 ${meta.characterCount}명'}'
                          '${meta?.representativeSummary == null ? '' : ' · 대표 ${meta!.representativeSummary!.characterName}'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: busy
                            ? null
                            : () => _navigate(
                                () => widget.onOpen(r.registrationId),
                              ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
