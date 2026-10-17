import '../../../../shared/formatters/display_number_formatter.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/account_read_session.dart';
import '../../domain/server_account_read_repository.dart';
import '../../domain/server_account_verification.dart';
import '../viewmodels/server_verification_selection_view_model.dart';
import '../viewmodels/server_verification_view_model.dart';
import '../widgets/server_accounts_panel.dart';

class ServerVerificationPage extends StatefulWidget {
  const ServerVerificationPage({
    required this.model,
    required this.accounts,
    required this.onLogin,
    required this.onVerified,
    this.initialRegistrationId,
    this.onVerifiedRegistration,
    this.onCompleted,
    this.onRegister,
    super.key,
  });
  final ServerVerificationViewModel model;
  final ServerAccountReadRepository accounts;
  final VoidCallback onLogin;
  final Future<void> Function() onVerified;
  final String? initialRegistrationId;
  final Future<void> Function(String)? onVerifiedRegistration;
  final VoidCallback? onCompleted;
  final Future<void> Function()? onRegister;

  @override
  State<ServerVerificationPage> createState() => _ServerVerificationPageState();
}

class _ServerVerificationPageState extends State<ServerVerificationPage>
    with WidgetsBindingObserver {
  final _name = TextEditingController();
  late final ServerVerificationSelectionViewModel _accounts;
  late (String?, int) _scope;
  String? _notifiedChallenge;
  AccountReadException? _handledFailure;
  bool _direct = false;
  bool _dialogOpen = false;
  bool _handoffBusy = false, _handoffFailed = false;
  bool _handledAlreadyVerified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scope = (widget.model.session.userId, widget.model.session.generation);
    // App-owned verification state may still contain an earlier success.
    if (widget.model.value?.status == ServerVerificationStatus.verified) {
      _notifiedChallenge = widget.model.value!.challengeId;
    }
    _accounts = ServerVerificationSelectionViewModel(
      widget.accounts,
      widget.model.session,
      initialRegistrationId: widget.initialRegistrationId,
    );
    _accounts.addListener(_changed);
    widget.model.addListener(_changed);
    if (widget.model.canReload) unawaited(widget.model.reload());
  }

  void _changed() {
    final scope = (
      widget.model.session.userId,
      widget.model.session.generation,
    );
    if (scope != _scope) {
      if (_dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        _dialogOpen = false;
      }
      _scope = scope;
      _name.clear();
      _notifiedChallenge = null;
      _direct = false;
      _handoffFailed = false;
      _handledAlreadyVerified = false;
    }
    final failure = widget.model.failure;
    if (!widget.model.alreadyVerified) _handledAlreadyVerified = false;
    if (widget.model.alreadyVerified && !_handledAlreadyVerified) {
      _handledAlreadyVerified = true;
      unawaited(_refreshVerified(null, complete: false));
    }
    if (failure == null) _handledFailure = null;
    if (failure != null &&
        !identical(failure, _handledFailure) &&
        !widget.model.hasPending &&
        {
          'REVISION_CONFLICT',
          'IDENTITY_CONFLICT',
          'CHARACTER_NOT_FOUND',
          'REGISTRATION_NOT_FOUND',
        }.contains(failure.code)) {
      _handledFailure = failure;
      _accounts.invalidate();
    }
    final snapshot = widget.model.value;
    if (snapshot?.status == ServerVerificationStatus.verified &&
        snapshot!.challengeId != _notifiedChallenge &&
        !widget.model.hasPending) {
      _notifiedChallenge = snapshot.challengeId;
      // Re-read server accounts only. Ownership/ID binding is a separate step.
      unawaited(_refreshVerified(snapshot.registrationId));
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshVerified(
    String? registrationId, {
    bool complete = true,
  }) async {
    if (_handoffBusy) return;
    final scope = _scope;
    _handoffBusy = true;
    _handoffFailed = false;
    try {
      await _accounts.load();
      if (mounted &&
          scope == _scope &&
          scope ==
              (widget.model.session.userId, widget.model.session.generation)) {
        await widget.onVerified();
        if (mounted &&
            scope == _scope &&
            complete &&
            registrationId != null &&
            scope ==
                (
                  widget.model.session.userId,
                  widget.model.session.generation,
                )) {
          await widget.onVerifiedRegistration?.call(registrationId);
        }
        if (complete &&
            mounted &&
            scope == _scope &&
            scope ==
                (
                  widget.model.session.userId,
                  widget.model.session.generation,
                )) {
          if (widget.onCompleted case final complete?) {
            complete();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
        }
      }
    } catch (_) {
      if (mounted && scope == _scope) _handoffFailed = true;
    } finally {
      _handoffBusy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _cancel() async {
    final scope = _scope;
    final challengeId = widget.model.value?.challengeId;
    _dialogOpen = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('인증을 취소할까요?'),
        content: const Text('진행 중인 인증을 취소합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('돌아가기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('인증 취소'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (mounted &&
        accepted == true &&
        scope == _scope &&
        widget.model.value?.challengeId == challengeId) {
      await widget.model.cancel();
    }
  }

  Future<void> _start() async {
    final model = widget.model;
    if (!model.canStart || _accounts.loading || _accounts.checking) return;
    final scope = _scope, direct = _direct;
    final registration = _accounts.registration, target = _accounts.target;
    if (!direct && !_accounts.canStart) return;
    final label = registration == null
        ? null
        : _accounts.displayLabelFor(registration);
    final name = _name.text;
    if (!await _accounts.checkStart(characterName: direct ? name : null)) {
      return;
    }
    if (!mounted || scope != _scope || !model.canStart) return;
    await model.start(
      registrationId: direct ? null : registration!.registrationId,
      characterName: direct ? name : null,
      targetCharacter: direct ? null : target,
      expectedRegistrationVersion: direct ? null : registration!.version,
      registrationLabel: direct ? null : label,
    );
  }

  @override
  void didUpdateWidget(covariant ServerVerificationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRegistrationId != widget.initialRegistrationId) {
      unawaited(_accounts.select(widget.initialRegistrationId));
      _direct = false;
      _handoffFailed = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.model.canReload) {
      unawaited(widget.model.reload());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.model.removeListener(_changed);
    _accounts.removeListener(_changed);
    _accounts.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model, snapshot = model.value;
    final available = _accounts.registrations;
    final selected =
        available.any((a) => a.registrationId == _accounts.registrationId)
        ? _accounts.registrationId
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('원정대 인증')),
      body: !model.signedIn
          ? Center(
              child: FilledButton(
                onPressed: widget.onLogin,
                child: const Text('로그인 후 인증하기'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_handoffBusy) const LinearProgressIndicator(),
                if (_handoffFailed) ...[
                  const Text('목록을 갱신하지 못했습니다.'),
                  TextButton(
                    onPressed: _handoffBusy
                        ? null
                        : () => _refreshVerified(
                            model.value?.registrationId,
                            complete: !model.alreadyVerified,
                          ),
                    child: const Text('목록 다시 조회'),
                  ),
                ],
                if (snapshot == null && !model.hasPending)
                  const Text('무기와 방어구 5부위를 모두 착용해 주세요.'),
                const SizedBox(height: 16),
                if (model.attempt != null) _AttemptSummary(model: model),
                if (model.canStart ||
                    (!model.hasChallenge && !model.hasPending)) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('등록 원정대 선택')),
                      ButtonSegment(value: true, label: Text('캐릭터 검색')),
                    ],
                    selected: {_direct},
                    onSelectionChanged: model.canStart && !_accounts.checking
                        ? (selection) =>
                              setState(() => _direct = selection.single)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  if (_direct)
                    TextField(
                      controller: _name,
                      enabled: model.canStart && !_accounts.checking,
                      maxLength: 64,
                      decoration: const InputDecoration(
                        labelText: '캐릭터명',
                        hintText: '현재 접속할 수 있는 캐릭터명',
                      ),
                    )
                  else ...[
                    if (_accounts.loading) const LinearProgressIndicator(),
                    DropdownButtonFormField<String>(
                      key: ValueKey((_scope, selected)),
                      initialValue: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '인증할 원정대'),
                      items: available
                          .map(
                            (account) => DropdownMenuItem(
                              value: account.registrationId,
                              enabled: _accounts.canVerify(account),
                              child: Text(
                                '${_accounts.displayLabelFor(account)}${_accounts.canVerify(account) ? '' : ' - 인증됨'}',
                                style: _accounts.canVerify(account)
                                    ? null
                                    : TextStyle(
                                        color: Theme.of(context).disabledColor,
                                      ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: model.canStart && !_accounts.checking
                          ? (id) => _accounts.select(id)
                          : null,
                    ),
                    if (_accounts.loaded && available.isEmpty)
                      const Text('등록된 원정대가 없습니다.'),
                    TextButton(
                      onPressed: _accounts.loading || _accounts.checking
                          ? null
                          : _accounts.load,
                      child: const Text('원정대·캐릭터 다시 조회'),
                    ),
                    if (selected != null && _accounts.roster != null) ...[
                      DropdownButtonFormField<VerificationTarget>(
                        key: ValueKey((_scope, selected, _accounts.roster)),
                        initialValue: _accounts.target,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '인증할 캐릭터'),
                        items: _accounts.characters
                            .map(
                              (character) => DropdownMenuItem(
                                value: VerificationTarget(
                                  serverName: character.serverName,
                                  characterName: character.characterName,
                                ),
                                child: Text(
                                  '${character.characterName} · ${character.serverName} · ${character.className} · ${DisplayNumberFormatter.whole(character.itemLevel, missing: '레벨 미확인')}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: model.canStart && !_accounts.checking
                            ? _accounts.choose
                            : null,
                      ),
                      if (_accounts.roster!.characters.isEmpty)
                        const Text('캐릭터가 없습니다. 다시 조회해 주세요.'),
                    ],
                  ],
                  if (_accounts.failure != null)
                    AccountReadFailure(failure: _accounts.failure!),
                  if (_accounts.checking) const LinearProgressIndicator(),
                  FilledButton(
                    onPressed:
                        model.canStart &&
                            !_accounts.loading &&
                            !_accounts.checking &&
                            (_direct || _accounts.canStart)
                        ? _start
                        : null,
                    child: const Text('인증 시작'),
                  ),
                ],
                if (snapshot != null && !model.alreadyVerified)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(switch (snapshot.status) {
                            ServerVerificationStatus.pending => '장비 변경 대기',
                            ServerVerificationStatus.verified => '인증 완료',
                            ServerVerificationStatus.expired =>
                              '인증 시간이 만료되었습니다.',
                            ServerVerificationStatus.cancelled => '인증을 취소했습니다.',
                          }),
                          if (snapshot.status ==
                              ServerVerificationStatus.pending) ...[
                            const SizedBox(height: 8),
                            Text(
                              '해제할 장비: ${snapshot.requiredSlots.join(', ')}',
                            ),
                            const Text('다른 부위 장비는 변경하지 마세요.'),
                            const Text(
                              '장비 변경 이후 캐릭터 선택창으로 이동하여 캐릭터 정보를 갱신하여야 합니다.',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('남은 시간: ${model.remainingSeconds}초'),
                            if (model.remainingSeconds == 0)
                              const Text('인증 상태를 다시 확인해 주세요.'),
                            if (model.verdictCode != null)
                              Text(_verdict(model.verdictCode!)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: model.canCancel ? _cancel : null,
                                  child: const Text('인증 취소'),
                                ),
                                FilledButton(
                                  onPressed: model.canConfirm
                                      ? model.confirm
                                      : null,
                                  child: const Text('장비 변경 확인'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (model.busy) const LinearProgressIndicator(),
                if (model.failure != null) ...[
                  const SizedBox(height: 12),
                  Text(_failure(model.failure!)),
                ],
                if (model.alreadyVerified && widget.onRegister != null)
                  TextButton(
                    onPressed: _handoffBusy
                        ? null
                        : () async {
                            final scope = _scope;
                            await widget.onRegister!();
                            if (mounted && scope == _scope) {
                              await _refreshVerified(null, complete: false);
                            }
                          },
                    child: const Text('원정대 등록 관리'),
                  ),
                if (model.retrySeconds > 0)
                  Text('${model.retrySeconds}초 후 다시 시도할 수 있습니다.'),
                if (model.hasPending) ...[
                  FilledButton(
                    onPressed: model.canRetry ? model.retry : null,
                    child: const Text('인증 요청 다시 시도'),
                  ),
                  if (!model.canRetry && !model.busy && model.retrySeconds == 0)
                    Text(
                      model.hasChallenge
                          ? '요청을 재전송할 수 없습니다. 인증 상태를 확인해 주세요.'
                          : '이전 요청을 확인할 수 없어 새 인증을 시작할 수 없습니다.',
                    ),
                ],
                if (model.hasChallenge &&
                    !model.alreadyVerified &&
                    !model.busy &&
                    ((snapshot == null && !model.hasPending) ||
                        (snapshot?.status == ServerVerificationStatus.pending &&
                            model.remainingSeconds == 0) ||
                        (model.hasPending &&
                            !model.canRetry &&
                            model.retrySeconds == 0)))
                  TextButton(
                    onPressed: model.canReload ? model.reload : null,
                    child: const Text('인증 결과 다시 확인'),
                  ),
                if (model.hasChallenge && snapshot == null && !model.hasPending)
                  const Text('인증 상태를 불러오지 못했습니다.'),
              ],
            ),
    );
  }
}

class _AttemptSummary extends StatelessWidget {
  const _AttemptSummary({required this.model});

  final ServerVerificationViewModel model;

  @override
  Widget build(BuildContext context) {
    final attempt = model.attempt!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('인증 대상'),
            if (attempt.registrationId != null) ...[
              Text('원정대: ${attempt.registrationLabel ?? '선택한 등록 원정대'}'),
              if (attempt.characterName != null)
                Text('캐릭터: ${attempt.characterName} · ${attempt.serverName}')
              else
                const Text('등록된 캐릭터로 인증 중'),
            ] else
              Text('캐릭터: ${attempt.characterName}'),
            if (model.hasPending)
              Text(
                model.busy
                    ? '${model.pendingAction} 요청 중'
                    : '${model.pendingAction} 결과 확인 필요',
              )
            else if (model.hasChallenge && model.value == null)
              const Text('현재 인증 상태 확인 필요'),
          ],
        ),
      ),
    );
  }
}

String _verdict(String code) => switch (code) {
  'ACCOUNT_BINDING_EVIDENCE_PENDING' => '장비 확인 완료 · 소유 인증 보류',
  'PROVIDER_EVIDENCE_PENDING' => '장비 확인 완료 · 인증 보류',
  'ROSTER_EVIDENCE_PENDING' => '원정대 정보 확인 중',
  'REQUIRED_EQUIPMENT_PRESENT' => '지정 장비를 해제하고 캐릭터 정보를 갱신해 주세요.',
  'NON_REQUIRED_EQUIPMENT_CHANGED' => '지정하지 않은 장비를 원래대로 돌려주세요.',
  _ => '아직 인증되지 않았습니다.',
};
String _failure(AccountReadException error) => switch (error.code) {
  'REVISION_CONFLICT' ||
  'IDENTITY_CONFLICT' ||
  'CHARACTER_NOT_FOUND' ||
  'REGISTRATION_NOT_FOUND' => '정보가 변경되었습니다. 다시 조회 후 선택해 주세요.',
  'EQUIPMENT_INCOMPLETE' => '무기와 방어구 5부위를 모두 착용해 주세요.',
  'INVALID_REQUEST' => '인증할 캐릭터를 선택하거나 입력해 주세요.',
  'VERIFICATION_EXPIRED' => '인증 시간이 만료되었습니다.',
  'VERIFICATION_CANCELLED' => '취소된 인증입니다.',
  'VERIFICATION_NOT_FOUND' => '인증 정보를 찾을 수 없습니다.',
  'IDEMPOTENCY_CONFLICT' || 'IDEMPOTENCY_EXPIRED' => '이전 요청을 다시 전송할 수 없습니다.',
  'UPSTREAM_UNAVAILABLE' => '로스트아크 정보를 불러오지 못했습니다.',
  'NETWORK_UNAVAILABLE' => '서버 연결을 확인해 주세요.',
  _ => accountReadErrorMessage(error),
};
