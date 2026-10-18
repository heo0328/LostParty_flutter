import '../../../../shared/formatters/display_number_formatter.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/account_read_session.dart';
import '../viewmodels/scoped_account_view_model.dart';
import '../widgets/scoped_account_status.dart';

class ScopedCharacterRetirementsPage extends StatefulWidget {
  const ScopedCharacterRetirementsPage({
    required this.model,
    required this.onLogin,
    super.key,
  });
  final ScopedAccountViewModel model;
  final VoidCallback onLogin;
  @override
  State<ScopedCharacterRetirementsPage> createState() =>
      _ScopedCharacterRetirementsPageState();
}

class _ScopedCharacterRetirementsPageState
    extends State<ScopedCharacterRetirementsPage> {
  AccountReadScope? _openedSession;
  void _ensureSession() {
    final m = widget.model;
    if (!m.canRead) {
      _openedSession = null;
      return;
    }
    final scope = accountReadScope(m.runtime.session);
    if (_openedSession == scope) return;
    _openedSession = scope;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          identical(m, widget.model) &&
          m.canRead &&
          accountReadScope(m.runtime.session) == scope) {
        unawaited(m.openHistory());
      }
    });
  }

  @override
  void didUpdateWidget(covariant ScopedCharacterRetirementsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.model, widget.model)) {
      oldWidget.model.closeHistory(notify: false);
      _openedSession = null;
    }
  }

  @override
  void dispose() {
    widget.model.closeHistory(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final m = widget.model, h = m.history;
      _ensureSession();
      final busy = h.loading || m.historyRetrySeconds > 0;
      return Scaffold(
        appBar: AppBar(
          title: const Text('사라진 캐릭터명 기록'),
          actions: [
            IconButton(
              tooltip: '이력 처음부터 다시 조회',
              onPressed: !m.canRead || busy ? null : m.restartHistory,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: !m.canRead
            ? Center(
                child: TextButton(
                  onPressed: widget.onLogin,
                  child: const Text('로그인 후 조회할 수 있습니다.'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('서버에 기록된 캐릭터 이력입니다.'),
                  if (h.loading) const LinearProgressIndicator(),
                  if (!h.current && h.items.isNotEmpty)
                    const Text('이전 확인 기록 · 전체 목록 확인 필요'),
                  if (h.failure case final failure?)
                    ScopedAccountFailureMessage(
                      failure: failure,
                      seconds: m.historyRetrySeconds,
                    ),
                  if (h.loaded && h.current && h.items.isEmpty)
                    const Text('사라진 캐릭터명 기록이 없습니다.'),
                  for (final row in h.items)
                    Card(
                      child: ListTile(
                        title: Text(row.characterName),
                        subtitle: Text(
                          '${row.serverName} · ${row.className}\n마지막 전투력 ${DisplayNumberFormatter.whole(row.combatPower)} · 아이템 레벨 ${DisplayNumberFormatter.whole(row.itemLevel)}\n'
                          '${row.powerFetchedAt == null ? '' : '전투력 확인: ${scopedTime(row.powerFetchedAt!)}\n'}'
                          '${row.itemLevelFetchedAt == null ? '' : '아이템 레벨 확인: ${scopedTime(row.itemLevelFetchedAt!)}\n'}'
                          '기록 시각: ${scopedTime(row.retiredAt)}',
                        ),
                      ),
                    ),
                  if (h.needsRestart)
                    OutlinedButton(
                      onPressed: busy ? null : m.restartHistory,
                      child: const Text('처음부터 다시 조회'),
                    )
                  else if (h.hasMore)
                    OutlinedButton(
                      onPressed: busy ? null : m.loadMoreHistory,
                      child: const Text('더 보기'),
                    ),
                ],
              ),
      );
    },
  );
}
