import '../../../../shared/formatters/display_number_formatter.dart';
import 'package:flutter/material.dart';
import '../widgets/ownership_notice_title.dart';
import '../../../../shared/formatters/local_date_time_formatter.dart';
import '../../domain/account_read_session.dart';
import '../../domain/server_account_models.dart';
import '../../domain/server_account_read_repository.dart';
import '../../domain/policies/account_label_policy.dart';
import '../../domain/services/roster_character_order.dart';
import '../viewmodels/server_account_read_view_model.dart';
import '../viewmodels/server_registration_view_model.dart';
import '../widgets/server_accounts_panel.dart';
import '../widgets/server_registration_edit_dialog.dart';

class ServerRegistrationPage extends StatefulWidget {
  const ServerRegistrationPage({
    required this.writes,
    required this.reads,
    required this.session,
    required this.onLogin,
    required this.onOpen,
    this.onVerify,
    super.key,
  });
  final ServerRegistrationViewModel writes;
  final ServerAccountReadRepository reads;
  final AccountReadSession session;
  final VoidCallback onLogin;
  final void Function(String) onOpen;
  final void Function(String)? onVerify;
  @override
  State<ServerRegistrationPage> createState() => _ServerRegistrationPageState();
}

class _ServerRegistrationPageState extends State<ServerRegistrationPage> {
  final _name = TextEditingController(), _label = TextEditingController();
  late final ServerAccountReadViewModel _reads;
  late (String?, int) _sessionKey;
  bool _main = false, _dialogOpen = false;
  @override
  void initState() {
    super.initState();
    widget.writes.clearCompletedNotice();
    _reads = ServerAccountReadViewModel(widget.reads, widget.session);
    _sessionKey = (widget.session.userId, widget.session.generation);
    widget.writes.addListener(_changed);
    _reads.addListener(_changed);
  }

  void _changed() {
    final key = (widget.session.userId, widget.session.generation);
    if (key != _sessionKey) {
      if (_dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        _dialogOpen = false;
      }
      _sessionKey = key;
      _name.clear();
      _label.clear();
      _main = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.writes.removeListener(_changed);
    _reads.removeListener(_changed);
    _reads.dispose();
    _name.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    await action();
    if (mounted && widget.session.isAuthenticated) await _reads.load();
  }

  Future<void> _edit(ServerAccountRegistration account) async {
    final scope = accountReadScope(widget.session);
    final result = await showServerRegistrationEditDialog(
      context,
      account: account,
      displayLabel: _reads.displayLabelFor(account),
      session: widget.session,
    );
    if (!mounted || result == null) return;
    if (!widget.session.isAuthenticated ||
        widget.session.userId != scope.userId ||
        widget.session.generation != scope.generation) {
      return;
    }
    await _perform(() => widget.writes.edit(account, result.$1, result.$2));
  }

  Future<void> _delete(ServerAccountRegistration account) async {
    final scope = accountReadScope(widget.session);
    _dialogOpen = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('서버 등록 제거'),
        content: Text(
          '${_reads.displayLabelFor(account)}의 서버 등록을 제거할까요? 기기에 저장한 캐릭터와 빌드는 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('등록 제거'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted ||
        accepted != true ||
        !widget.session.isAuthenticated ||
        widget.session.userId != scope.userId ||
        widget.session.generation != scope.generation) {
      return;
    }
    await _perform(() => widget.writes.remove(account));
  }

  Future<void> _review() async {
    final result = await widget.writes.review();
    if (!mounted || result == null || !widget.writes.canFinishReview) return;
    _dialogOpen = true;
    final labels = AccountLabelPolicy.serverLabels(result);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('현재 서버 등록 확인'),
        content: SingleChildScrollView(
          child: Text(
            '${result.isEmpty ? '등록된 계정이 없습니다.' : result.map((a) => '${labels[a.registrationId]} · ${a.isMain ? '메인' : '부계정'} · 캐릭터 ${a.characterCount}명').join('\n')}\n\n'
            '이 목록을 기준으로 이전 요청 확인을 종료할까요? 처리 중인 요청은 나중에 반영될 수 있으므로 같은 동작을 바로 새로 제출하지 마세요.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('요청 유지'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인 종료'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (accepted == true && mounted) widget.writes.finishReviewedRequest();
    if (mounted) await _reads.load();
  }

  @override
  Widget build(BuildContext context) {
    final writes = widget.writes;
    return Scaffold(
      appBar: AppBar(title: const OwnershipNoticeTitle(child: Text('원정대 관리'))),
      body: !widget.session.isAuthenticated
          ? Center(
              child: TextButton(
                onPressed: widget.onLogin,
                child: const Text('로그인하면 원정대를 등록할 수 있습니다.'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('미인증 원정대는 등록 후 인증해 주세요.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  enabled: writes.canWrite,
                  maxLength: 64,
                  decoration: const InputDecoration(
                    labelText: '검색 캐릭터명',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                FilledButton.icon(
                  onPressed: writes.canWrite
                      ? () => writes.search(_name.text)
                      : null,
                  icon: const Icon(Icons.search),
                  label: const Text('원정대 미리보기'),
                ),
                if (writes.busy) const LinearProgressIndicator(),
                if (writes.failure != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (writes.failure!.code.startsWith('LOSTARK_KEY_'))
                          AccountReadFailure(failure: writes.failure!)
                        else
                          Text(_message(writes.failure!)),
                      ],
                    ),
                  ),
                if (writes.retrySeconds > 0)
                  Text(
                    '호출 한도에 도달했습니다. 약 ${writes.retrySeconds}초 후 다시 시도해 주세요.',
                  ),
                if (writes.notice != null) Text(writes.notice!),
                if (writes.hasPending) ...[
                  const Text('결과 확인이 필요한 요청이 남아 있습니다. 입력을 바꾸어 재전송하지 않습니다.'),
                  OutlinedButton(
                    onPressed: writes.canRetry
                        ? () => _perform(writes.retry)
                        : null,
                    child: const Text('같은 요청 다시 시도'),
                  ),
                  TextButton(
                    onPressed: !writes.busy ? _review : null,
                    child: const Text('등록 결과 다시 확인'),
                  ),
                ],
                if (writes.preview case final preview?) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _label,
                    enabled: writes.canWrite,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: '계정 표시명',
                      hintText: '비워두면 현재 본·부계정 위치에 따라 표시',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('메인 계정으로 등록'),
                    value: _main,
                    onChanged: writes.canWrite
                        ? (value) => setState(() => _main = value)
                        : null,
                  ),
                  FilledButton(
                    onPressed:
                        writes.canWrite &&
                            _name.text.trim() == writes.previewName
                        ? () => _perform(
                            () => writes.register(_label.text, _main),
                          )
                        : null,
                    child: const Text('조회 목록에 저장'),
                  ),
                  const SizedBox(height: 12),
                  Text('미리보기 캐릭터 ${preview.characters.length}명 · 미인증'),
                  Text('유효 시각: ${localDateTimeToSeconds(preview.expiresAt)}'),
                  for (final c in rosterByItemLevel(
                    preview.characters,
                    (c) => c.itemLevel,
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.characterName),
                      subtitle: Text(
                        '${c.serverName} · ${c.className} · 아이템 ${DisplayNumberFormatter.whole(c.itemLevel)}',
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Text('서버 등록 목록')),
                    IconButton(
                      tooltip: '현재 서버 목록 다시 조회',
                      onPressed: !_reads.loading && !writes.busy
                          ? _reads.load
                          : null,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_reads.loading) const LinearProgressIndicator(),
                if (_reads.failure != null)
                  AccountReadFailure(failure: _reads.failure!),
                if (_reads.loaded && _reads.registrations.isEmpty)
                  const Text('서버에 등록한 계정이 없습니다.'),
                for (final a in _reads.registrations)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${_reads.displayLabelFor(a)} · ${a.isMain ? '메인 계정' : '부계정'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (serverOwnershipLabel(
                            a.ownershipStatus,
                          ).isNotEmpty)
                            Text(serverOwnershipLabel(a.ownershipStatus)),
                          Text('캐릭터 ${a.characterCount}명'),
                          Text(
                            '서버 조회 시각: ${serverRegistrationTimeLabel(a.serverFetchedAt)}',
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (a.ownershipStatus != 'owned' &&
                                  widget.onVerify != null)
                                FilledButton(
                                  onPressed: writes.busy
                                      ? null
                                      : () =>
                                            widget.onVerify!(a.registrationId),
                                  child: const Text('원정대 인증'),
                                ),
                              TextButton(
                                onPressed: writes.busy
                                    ? null
                                    : () => widget.onOpen(a.registrationId),
                                child: const Text('캐릭터 보기'),
                              ),
                              TextButton(
                                onPressed: writes.canWrite && !_reads.loading
                                    ? () => _edit(a)
                                    : null,
                                child: const Text('수정'),
                              ),
                              TextButton(
                                onPressed: writes.canWrite && !_reads.loading
                                    ? () => _perform(() => writes.refresh(a))
                                    : null,
                                child: const Text('정보 갱신'),
                              ),
                              TextButton(
                                onPressed: writes.canWrite && !_reads.loading
                                    ? () => _delete(a)
                                    : null,
                                child: const Text('등록 제거'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _message(AccountReadException error) => switch (error.code) {
    'PREVIEW_EXPIRED' => '미리보기 유효 시간이 지났습니다. 캐릭터를 다시 검색해 주세요.',
    'INVALID_REQUEST' => '캐릭터명과 계정 표시명을 확인해 주세요.',
    'UPSTREAM_UNAVAILABLE' => '게임 정보를 조회할 수 없습니다. 서버 API 키 준비와 연결 상태를 확인해 주세요.',
    'REQUEST_IN_PROGRESS' => '서버에서 요청을 처리 중입니다. 잠시 후 같은 요청으로 확인해 주세요.',
    'IDEMPOTENCY_CONFLICT' ||
    'IDEMPOTENCY_EXPIRED' => '이 요청을 그대로 재시도할 수 없습니다. 먼저 서버 상태를 확인해 주세요.',
    'REVISION_CONFLICT' => '계정 정보가 변경되었습니다. 최신 목록을 확인한 뒤 다시 수정해 주세요.',
    _ => accountReadErrorMessage(error),
  };
}
