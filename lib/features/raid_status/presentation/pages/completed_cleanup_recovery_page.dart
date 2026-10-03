import 'package:flutter/material.dart';

import '../../../recruitment_list/domain/entities/completed_ownership_cleanup.dart';

class CompletedCleanupRecoveryPage extends StatefulWidget {
  const CompletedCleanupRecoveryPage({
    required this.repository,
    required this.playerId,
    super.key,
  });
  final CompletedOwnershipCleanupRepository repository;
  final String playerId;

  @override
  State<CompletedCleanupRecoveryPage> createState() => _RecoveryState();
}

class _RecoveryState extends State<CompletedCleanupRecoveryPage> {
  List<CompletedOwnershipCleanup> _requests = [];
  String? _message;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final requests = await widget.repository.pending(widget.playerId);
      if (mounted) setState(() => _requests = requests);
    } catch (_) {
      if (mounted) setState(() => _message = '저장된 요청을 읽지 못했습니다. 다시 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry(CompletedOwnershipCleanup request) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.repository.retry(request);
      if (mounted) setState(() => _message = '정리 완료를 확인했습니다. 기존 완료 기록은 유지됩니다.');
    } on StateError catch (error) {
      if (mounted) setState(() => _message = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              '처리 결과를 확인하지 못했습니다. 연결 또는 권한을 확인한 후 다시 시도해 주세요. 요청은 보관됩니다.',
        );
      }
    }
    await _load();
  }

  Future<void> _forget(CompletedOwnershipCleanup request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 기기의 요청 기록 지우기'),
        content: const Text(
          '서버에서 진행되었거나 완료된 정리는 취소되지 않습니다. 처리 결과를 아직 확인하지 못했다면 먼저 다시 확인해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('돌아가기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('기기 기록 지우기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.repository.forget(request);
    } catch (_) {
      if (mounted) setState(() => _message = '기기의 요청 기록을 지우지 못했습니다.');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('참가 정리 처리 결과')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '이 기기에서 확인한 참가 정리 요청입니다. 다시 확인하면 처리 결과를 조회하고, 아직 처리되지 않았다면 당시 확인한 조건으로 재시도합니다.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_message!),
          ),
        if (!_busy && _requests.isEmpty)
          const ListTile(title: Text('미확정 요청이 없습니다.')),
        for (final request in _requests)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.targetName ?? '참가 정리 요청'),
                  Text(
                    request.kind == CompletedCleanupKind.disband
                        ? '마지막 참가자 방 해산 · 결과 미확인'
                        : '다음 주 참가 정리 · 결과 미확인',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : () => _retry(request),
                        child: const Text('다시 확인'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _forget(request),
                        child: const Text('기기 기록 지우기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  setState(() {
                    _busy = true;
                    _message = null;
                  });
                  _load();
                },
          child: const Text('목록 새로고침'),
        ),
      ],
    ),
  );
}
