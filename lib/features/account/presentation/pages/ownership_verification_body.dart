import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/ownership_notice_title.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../../data/ownership_command_store.dart';
import '../../domain/ownership_command.dart';
import '../../domain/ownership_verification_models.dart';
import '../../domain/server_account_verification.dart';
import '../viewmodels/ownership_dispute_controller.dart';
import '../viewmodels/ownership_verification_view_model.dart';
import '../viewmodels/server_verification_selection_view_model.dart';
import '../widgets/server_accounts_panel.dart';

class OwnershipVerificationBody extends StatefulWidget {
  const OwnershipVerificationBody({
    required this.controller,
    required this.selection,
    required this.onLogin,
    required this.onVerified,
    this.onVerifiedRegistration,
    this.onCompleted,
    this.onRegister,
    this.proofId,
    this.disputeId,
    this.registrationId,
    super.key,
  });
  final OwnershipDisputeController controller;
  final ServerVerificationSelectionViewModel selection;
  final VoidCallback onLogin;
  final Future<void> Function() onVerified;
  final Future<void> Function(String)? onVerifiedRegistration;
  final VoidCallback? onCompleted;
  final Future<void> Function()? onRegister;
  final String? proofId, disputeId, registrationId;
  @override
  State<OwnershipVerificationBody> createState() =>
      _OwnershipVerificationBodyState();
}

class _OwnershipVerificationBodyState extends State<OwnershipVerificationBody> {
  late final OwnershipVerificationViewModel model;
  final name = TextEditingController();
  bool direct = false, handoffBusy = false;
  String? completed, handoffRegistration;
  bool handoffFailed = false;
  bool handoffQueued = false;
  bool dialogOpen = false;
  bool invalidEntry = false;
  late (String?, int) identity;
  Timer? timer;
  OwnershipDisputeController get controller => widget.controller;
  ServerVerificationSelectionViewModel get selection => widget.selection;
  bool get ready =>
      !invalidEntry &&
      controller.commandFailure?.canRetry(controller.now()) != false &&
      model.ready &&
      !handoffBusy &&
      controller.pendingCommands.isEmpty;
  @override
  void initState() {
    super.initState();
    model = OwnershipVerificationViewModel(controller)..addListener(changed);
    selection.addListener(changed);
    identity = (controller.session.userId, controller.session.generation);
    try {
      final ids = [
        widget.proofId,
        widget.disputeId,
        widget.registrationId,
      ].whereType<String>().toList();
      if (ids.length > 1) throw const FormatException();
      for (final id in ids) {
        verificationUuid(id);
      }
      openEntry();
    } on FormatException {
      invalidEntry = true;
    }
    // Only active/current work produces a completion while this page is open.
    completed =
        controller.selectedProof?.outcome == 'verified' ||
            controller.selectedProof?.outcome == 'defended'
        ? controller.selectedProof?.id
        : null;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          (controller.selectedProof?.equipmentStatus == 'pending' ||
              controller.commandFailure?.retryAt != null)) {
        setState(() {});
      }
    });
  }

  void openEntry() {
    if (invalidEntry) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.signedIn) return;
      if (widget.proofId case final id?) {
        unawaited(model.run(() => controller.selectProof(id)));
      } else if (widget.disputeId case final id?) {
        unawaited(model.run(() => controller.selectDispute(id)));
      }
    });
  }

  void changed() {
    if (!mounted) return;
    final next = (controller.session.userId, controller.session.generation);
    if (next != identity) {
      if (dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      identity = next;
      name.clear();
      direct = false;
      completed = null;
      handoffFailed = false;
      handoffRegistration = null;
      openEntry();
    }
    final proof = controller.selectedProof;
    if (proof != null &&
        controller.proofIsCurrent(proof.id) &&
        {'verified', 'defended'}.contains(proof.outcome) &&
        completed != proof.id &&
        controller.pendingCommands.isEmpty &&
        !handoffBusy &&
        !handoffQueued) {
      handoffQueued = true;
      final member = identity;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handoffQueued = false;
        if (mounted &&
            identity == member &&
            controller.selectedProofId == proof.id &&
            controller.proofIsCurrent(proof.id)) {
          completed = proof.id;
          unawaited(handoff(proof.registrationId));
        }
      });
    }
    setState(() {});
  }

  Future<void> handoff(String? registration) async {
    if (handoffBusy) return;
    final member = identity;
    handoffBusy = true;
    handoffFailed = false;
    handoffRegistration = registration;
    setState(() {});
    try {
      await controller.retryAccountSync();
      if (controller.accountSyncFailure != null) throw StateError('sync');
      if (!mounted || member != identity) return;
      // The app controller already refreshed ownership/account state. Standalone
      // consumers keep the existing callback as a fallback.
      if (controller.onAccountStateChanged == null) {
        await widget.onVerified();
      }
      if (!mounted || member != identity) return;
      if (registration != null) {
        await widget.onVerifiedRegistration?.call(registration);
      }
      if (!mounted || member != identity) return;
      if (widget.onCompleted case final complete?) {
        complete();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted && member == identity) handoffFailed = true;
    } finally {
      handoffBusy = false;
      if (mounted) setState(() {});
    }
  }

  Future<bool> confirm(String title, String explanation, String action) async {
    final member = identity;
    dialogOpen = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(explanation)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('돌아가기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    dialogOpen = false;
    return mounted && identity == member && accepted == true;
  }

  Future<void> reconcile(OwnershipJournalEntry entry) => model.run(() async {
    final key = entry.command.idempotencyKey;
    final history = await controller.reviewReconciliation(key);
    if (!mounted) return;
    if (await confirm(
      '이전 요청을 확인했나요?',
      '인증 이력 ${history.proofs.length}건 · 도전/방어 이력 ${history.disputes.length}건을 조회했습니다. '
          '이전 요청의 성공은 확정되지 않았습니다. 이 요청의 재전송을 중단하고 현재 상태에서 새 행동을 선택합니다.\n\n'
          '${history.proofs.map((p) => '${target(p.target)} · ${_proofStatus(p)}').join('\n')}\n'
          '${history.disputes.map((d) => '${target(d.target)} · ${_disputeStatus(d)}').join('\n')}',
      '확인',
    )) {
      await controller.acknowledgeReconciliation(key);
      await controller.refresh();
    }
  });
  Future<void> history() => model.run(() async {
    final member = identity;
    final values = await controller.history();
    if (!mounted || member != identity) return;
    dialogOpen = true;
    final selected = await showDialog<(bool, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('인증·도전 이력'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (values.proofs.isEmpty && values.disputes.isEmpty)
                  const Text('확인된 이력이 없습니다.'),
                for (final p in values.proofs)
                  ListTile(
                    title: Text(target(p.target)),
                    subtitle: Text(_proofStatus(p)),
                    onTap: () => Navigator.pop(context, (true, p.id)),
                  ),
                for (final d in values.disputes)
                  ListTile(
                    title: Text(target(d.target)),
                    subtitle: Text(_disputeStatus(d)),
                    onTap: () => Navigator.pop(context, (false, d.id)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
    dialogOpen = false;
    if (!mounted || member != identity || selected == null) return;
    if (selected.$1) {
      await controller.selectProof(selected.$2);
    } else {
      await controller.selectDispute(selected.$2);
    }
  });
  Widget card(List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
  String target(VerificationTarget value) =>
      '${value.characterName} · ${value.serverName}';
  String time(DateTime value) => value.toLocal().toString().split('.').first;
  Future<void> inspect() async {
    await model.inspect(direct ? name.text : selection.target!.characterName);
  }

  @override
  Widget build(BuildContext context) {
    final proof = controller.selectedProof,
        dispute = controller.selectedDispute;
    final available = selection.registrations;
    final selected =
        available.any((a) => a.registrationId == selection.registrationId)
        ? selection.registrationId
        : null;
    final pendingProof = proof?.equipmentStatus == 'pending';
    return Scaffold(
      appBar: AppBar(title: const OwnershipNoticeTitle(child: Text('원정대 인증'))),
      body: !controller.signedIn
          ? Center(
              child: FilledButton(
                onPressed: widget.onLogin,
                child: const Text('로그인 후 인증하기'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (handoffBusy ||
                    model.busy ||
                    controller.commandBusy ||
                    controller.loading)
                  const LinearProgressIndicator(),
                if (handoffFailed) ...[
                  const Text('목록을 갱신하지 못했습니다.'),
                  TextButton(
                    onPressed: handoffBusy
                        ? null
                        : () => handoff(handoffRegistration),
                    child: const Text('목록 다시 조회'),
                  ),
                ],
                if (invalidEntry)
                  const Text('올바르지 않은 인증 대상입니다. 이전 화면에서 다시 진입해 주세요.'),
                if (!pendingProof) ...[
                  const Text('무기와 방어구 5부위를 모두 착용해 주세요.'),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('등록 원정대 선택')),
                      ButtonSegment(value: true, label: Text('캐릭터 검색')),
                    ],
                    selected: {direct},
                    onSelectionChanged: ready
                        ? (values) {
                            model.clearPreview();
                            setState(() => direct = values.single);
                          }
                        : null,
                  ),
                  if (controller.selectedProofId != null &&
                      proof == null &&
                      controller.proofFailure(controller.selectedProofId!) !=
                          null) ...[
                    const Text('인증 상태를 불러오지 못했습니다.'),
                    TextButton(
                      onPressed: model.ready
                          ? () => model.run(
                              () => controller.selectProof(
                                controller.selectedProofId!,
                              ),
                            )
                          : null,
                      child: const Text('인증 결과 다시 확인'),
                    ),
                  ],
                  if (controller.selectedDisputeId != null &&
                      dispute == null &&
                      controller.disputeFailure(
                            controller.selectedDisputeId!,
                          ) !=
                          null) ...[
                    const Text('인증 도전/방어 상태를 불러오지 못했습니다.'),
                    TextButton(
                      onPressed: model.ready
                          ? () => model.run(
                              () => controller.selectDispute(
                                controller.selectedDisputeId!,
                              ),
                            )
                          : null,
                      child: const Text('현재 결과 다시 조회'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (direct)
                    TextField(
                      controller: name,
                      enabled: ready,
                      maxLength: 64,
                      onChanged: (_) => model.clearPreview(),
                      decoration: const InputDecoration(
                        labelText: '캐릭터명',
                        hintText: '현재 접속할 수 있는 캐릭터명',
                      ),
                    )
                  else ...[
                    if (selection.loading) const LinearProgressIndicator(),
                    DropdownButtonFormField<String>(
                      key: ValueKey((identity, selected)),
                      initialValue: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '인증할 원정대'),
                      items: available
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.registrationId,
                              enabled: selection.canVerify(a),
                              child: Text(
                                '${selection.displayLabelFor(a)}${selection.canVerify(a) ? '' : ' - 인증됨'}',
                                overflow: TextOverflow.ellipsis,
                                style: selection.canVerify(a)
                                    ? null
                                    : TextStyle(
                                        color: Theme.of(context).disabledColor,
                                      ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: ready
                          ? (id) {
                              model.clearPreview();
                              unawaited(selection.select(id));
                            }
                          : null,
                    ),
                    if (selection.loaded && available.isEmpty)
                      const Text('등록된 원정대가 없습니다.'),
                    TextButton(
                      onPressed: ready && !selection.loading
                          ? () {
                              model.clearPreview();
                              unawaited(selection.load());
                            }
                          : null,
                      child: const Text('원정대·캐릭터 다시 조회'),
                    ),
                    if (selection.roster != null)
                      DropdownButtonFormField<VerificationTarget>(
                        key: ValueKey((identity, selected, selection.roster)),
                        initialValue: selection.target,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '인증할 캐릭터'),
                        items: selection.characters
                            .map(
                              (c) => DropdownMenuItem(
                                value: VerificationTarget(
                                  serverName: c.serverName,
                                  characterName: c.characterName,
                                ),
                                child: Text(
                                  '${c.characterName} · ${c.serverName} · ${c.className} · ${DisplayNumberFormatter.whole(c.itemLevel, missing: '레벨 미확인')}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: ready
                            ? (value) {
                                model.clearPreview();
                                selection.choose(value);
                              }
                            : null,
                      ),
                  ],
                  if (selection.failure != null)
                    AccountReadFailure(failure: selection.failure!),
                  if (model.preview case final preview?) ...[
                    Text(switch (preview.context.relation) {
                      'self' => '이미 인증된 원정대입니다.',
                      'other' => '다른 사용자에게 인증된 원정대입니다. 장비 확인 후 24시간 방어가 시작됩니다.',
                      'unresolved' => '원정대 정보를 확인할 수 없습니다.',
                      _ => '인증할 캐릭터: ${model.previewName}',
                    }),
                    if (!preview.context.canStartClaim &&
                        preview.context.relation == 'other')
                      Text(_reason(preview.context.blockedReason)),
                  ],
                  FilledButton(
                    onPressed:
                        ready &&
                            controller.journalLoaded &&
                            controller.proofsCurrent &&
                            controller.disputesCurrent &&
                            !selection.loading &&
                            (direct || selection.canStart)
                        ? () async {
                            if (model.preview == null) {
                              await inspect();
                              if (!mounted ||
                                  !ready ||
                                  model.preview == null ||
                                  model.preview!.context.relation == 'other') {
                                return;
                              }
                            }
                            if (model.preview!.context.canStartClaim) {
                              await model.startClaim(
                                registrationId: direct
                                    ? null
                                    : selection.registration!.registrationId,
                                version: direct
                                    ? null
                                    : selection.registration!.version,
                                target: direct ? null : selection.target,
                              );
                            }
                          }
                        : null,
                    child: const Text('인증 시작'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (controller.activeProofs.length > 1) ...[
                  const Text('진행 중인 인증'),
                  ...controller.activeProofs.map(
                    (v) => ListTile(
                      title: Text(target(v.target)),
                      subtitle: Text(
                        v.purpose == 'defense' ? '방어 장비 확인' : '인증 장비 확인',
                      ),
                      selected: v.id == proof?.id,
                      onTap: ready
                          ? () => model.run(() => controller.selectProof(v.id))
                          : null,
                    ),
                  ),
                ],
                if (proof != null)
                  card([
                    const Text('인증 대상'),
                    Text(target(proof.target)),
                    Text(_proofStatus(proof)),
                    if (pendingProof) ...[
                      const SizedBox(height: 8),
                      Text('해제할 장비: ${proof.requiredSlots.join(', ')}'),
                      const Text('다른 부위 장비는 변경하지 마세요.'),
                      const Text(
                        '장비 변경 이후 캐릭터 선택창으로 이동하여 캐릭터 정보를 갱신하여야 합니다.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '남은 시간: ${controller.proofRemaining(proof.id).inSeconds}초',
                      ),
                      if (proof.resultCode != null)
                        Text(_reason(proof.resultCode)),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed:
                                ready &&
                                    controller.proofIsCurrent(proof.id) &&
                                    proof.allowedActions.contains('cancel')
                                ? () async {
                                    if (await confirm(
                                      '인증을 취소할까요?',
                                      '진행 중인 장비 인증을 취소합니다.',
                                      '인증 취소',
                                    )) {
                                      await model.act(
                                        OwnershipOperation.cancelProof,
                                        proof.id,
                                        proof.version,
                                      );
                                    }
                                  }
                                : null,
                            child: const Text('인증 취소'),
                          ),
                          FilledButton(
                            onPressed:
                                ready &&
                                    controller.proofIsCurrent(proof.id) &&
                                    controller.proofRemaining(proof.id) >
                                        Duration.zero &&
                                    proof.allowedActions.contains('confirm')
                                ? () => model.act(
                                    OwnershipOperation.confirm,
                                    proof.id,
                                    proof.version,
                                  )
                                : null,
                            child: const Text('장비 변경 확인'),
                          ),
                        ],
                      ),
                    ],
                    if (proof.disputeId != null &&
                        proof.allowedActions.contains('view_dispute'))
                      TextButton(
                        onPressed: ready
                            ? () => model.run(
                                () =>
                                    controller.selectDispute(proof.disputeId!),
                              )
                            : null,
                        child: const Text('인증 도전/방어 보기'),
                      ),
                    if (controller.proofFailure(proof.id) != null ||
                        (pendingProof &&
                            controller.proofRemaining(proof.id) ==
                                Duration.zero))
                      TextButton(
                        onPressed: model.ready
                            ? () => model.run(
                                () => controller.selectProof(proof.id),
                              )
                            : null,
                        child: const Text('인증 결과 다시 확인'),
                      ),
                  ]),
                if (controller.activeDisputes.isNotEmpty) ...[
                  const Text('원정대 인증 도전/방어'),
                  if (controller.activeDisputes.length > 1 || dispute == null)
                    ...controller.activeDisputes.map(
                      (d) => ListTile(
                        leading: Icon(
                          d.viewerRole == 'owner'
                              ? Icons.shield_outlined
                              : Icons.schedule,
                        ),
                        title: Text(target(d.target)),
                        selected: dispute?.id == d.id,
                        subtitle: Text(
                          d.viewerRole == 'owner' ? '원정대 방어 필요' : '인증 도전 진행 중',
                        ),
                        onTap: ready
                            ? () => model.run(
                                () => controller.selectDispute(d.id),
                              )
                            : null,
                      ),
                    ),
                ],
                if (dispute != null) _disputeCard(dispute),
                for (final entry in controller.pendingCommands)
                  card([
                    const Text('이전 요청 확인 필요'),
                    Text(
                      entry.phase == OwnershipCommandPhase.awaitingCurrent
                          ? '요청은 접수됐습니다. 현재 결과를 다시 조회합니다.'
                          : '요청 결과가 확정되지 않았습니다.',
                    ),
                    if (entry.phase ==
                            OwnershipCommandPhase.reconciliationRequired ||
                        (entry.phase != OwnershipCommandPhase.awaitingCurrent &&
                            !entry.command.replayableAt(controller.now())))
                      TextButton(
                        onPressed: model.ready ? () => reconcile(entry) : null,
                        child: const Text('현재 상태 검토'),
                      )
                    else
                      TextButton(
                        onPressed: model.ready
                            ? () => model.run(
                                () => controller.recoverCommand(
                                  entry.command.idempotencyKey,
                                ),
                              )
                            : null,
                        child: Text(
                          entry.phase == OwnershipCommandPhase.awaitingCurrent
                              ? '현재 결과 다시 조회'
                              : '요청 다시 확인',
                        ),
                      ),
                  ]),
                if (model.failure != null) Text(_reason(model.failure!.code)),
                TextButton(
                  onPressed: model.ready ? history : null,
                  child: const Text('인증·도전 이력'),
                ),
                if (controller.commandFailure != null)
                  Text(_reason(controller.commandFailure!.code)),
                if (controller.proofsFailure != null ||
                    controller.disputesFailure != null ||
                    controller.journalFailure != null) ...[
                  const Text('진행 정보를 불러오지 못했습니다. 마지막 확인 상태를 표시합니다.'),
                  TextButton(
                    onPressed: model.ready
                        ? () => model.run(controller.refresh)
                        : null,
                    child: const Text('다시 불러오기'),
                  ),
                ],
                if (widget.onRegister != null &&
                    (model.preview?.context.relation == 'self' ||
                        (dispute?.viewerRole == 'owner' &&
                            dispute?.myRegistrationId == null)))
                  TextButton(
                    onPressed: ready ? widget.onRegister : null,
                    child: const Text('원정대 등록 관리'),
                  ),
              ],
            ),
    );
  }

  Widget _disputeCard(OwnershipDispute d) {
    final canAct = ready && controller.disputeIsCurrent(d.id);
    return card([
      Row(
        children: [
          Icon(
            d.viewerRole == 'owner' ? Icons.shield_outlined : Icons.schedule,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(_disputeStatus(d))),
        ],
      ),
      Text(target(d.target)),
      Text(
        '${d.viewerRole == 'owner' ? '방어 가능 기한' : '방어 기한'}: ${time(d.viewerRole == 'owner' ? d.defenseAvailableUntil ?? d.defenseDeadline : d.defenseDeadline)}',
      ),
      if (d.phase == 'awaiting_defense')
        Text(
          d.viewerRole == 'owner'
              ? '다른 사용자의 인증 도전이 있습니다.'
              : '기존 소유자의 방어를 기다리고 있습니다.',
        ),
      if (d.reasonCode != null) Text(_reason(d.reasonCode)),
      if (d.nextRetryAt != null) Text('다음 처리 예정: ${time(d.nextRetryAt!)}'),
      if (d.allowedActions.contains('start_defense') &&
          controller.defenseRemaining(d.id) > Duration.zero) ...[
        TextButton(
          onPressed: canAct ? () => model.prepareDefense(d.id) : null,
          child: const Text('원정대 방어'),
        ),
        if (model.defenseDisputeId == d.id) ...[
          DropdownButtonFormField<String>(
            key: ValueKey(model.defenseRoster),
            initialValue: model.defenseCharacter?.characterId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '방어할 캐릭터'),
            items: model.defenseCharacters
                .map(
                  (c) => DropdownMenuItem(
                    value: c.characterId,
                    child: Text(
                      '${c.characterName} · ${c.serverName} · ${DisplayNumberFormatter.whole(c.wire['item_level'] as String?, missing: '레벨 미확인')}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: canAct ? model.chooseDefense : null,
          ),
          if (model.defenseCharacters.isEmpty)
            const Text('방어할 수 있는 캐릭터가 없습니다. 원정대를 다시 조회해 주세요.'),
          FilledButton(
            onPressed: canAct && model.defenseCharacter != null
                ? model.startDefense
                : null,
            child: const Text('방어 인증 시작'),
          ),
        ],
      ],
      for (final id in d.myActiveVerificationIds)
        TextButton(
          onPressed: ready
              ? () => model.run(() => controller.selectProof(id))
              : null,
          child: const Text('진행 중인 장비 확인 이어가기'),
        ),
      if (d.allowedActions.contains('cancel_dispute'))
        TextButton(
          onPressed: canAct
              ? () async {
                  if (await confirm(
                    '인증 도전을 취소할까요?',
                    '현재 인증 도전을 취소합니다.',
                    '도전 취소',
                  )) {
                    await model.act(
                      OwnershipOperation.cancelDispute,
                      d.id,
                      d.version,
                    );
                  }
                }
              : null,
          child: const Text('도전 취소'),
        ),
      if (d.allowedActions.contains('request_settlement'))
        TextButton(
          onPressed: canAct
              ? () => model.act(OwnershipOperation.settle, d.id, d.version)
              : null,
          child: const Text('이전 처리 요청'),
        ),
      if (controller.disputeFailure(d.id) != null ||
          d.phase != 'awaiting_defense')
        TextButton(
          onPressed: model.ready
              ? () => model.run(() => controller.selectDispute(d.id))
              : null,
          child: const Text('현재 결과 다시 조회'),
        ),
    ]);
  }

  @override
  void dispose() {
    timer?.cancel();
    selection.removeListener(changed);
    model.removeListener(changed);
    model.dispose();
    name.dispose();
    super.dispose();
  }
}

String _proofStatus(OwnershipVerification p) => switch (p.equipmentStatus) {
  'pending' => '장비 변경 대기',
  'expired' => '인증 시간이 만료되었습니다.',
  'cancelled' => '인증을 취소했습니다.',
  'invalidated' => '대상 정보가 변경되었습니다.',
  _ => switch (p.outcome) {
    'verified' => '인증 완료',
    'defended' => '원정대를 방어했습니다.',
    'dispute_opened' => '인증 도전 시작',
    _ => _reason(p.resultCode),
  },
};
String _disputeStatus(OwnershipDispute d) => switch (d.phase) {
  'awaiting_defense' => d.viewerRole == 'owner' ? '원정대 방어 필요' : '인증 도전 진행 중',
  'settlement_due' => '이전 처리 중',
  'retrying_settlement' => '다시 처리할 예정입니다.',
  'review_required' => '확인 필요',
  _ => switch (d.state) {
    'defended' => '원정대 방어 완료',
    'transferred' => '소유권 이전 완료',
    'cancelled' => '인증 도전 취소',
    _ => '대상 정보가 변경되었습니다.',
  },
};
String _reason(String? code) => switch (code) {
  'ALREADY_VERIFIED' => '이미 인증된 원정대입니다.',
  'DISPUTE_CAPACITY_REACHED' => '진행 중인 인증 도전이 가득 찼습니다.',
  'DISPUTE_ALREADY_ACTIVE' => '이미 진행 중인 인증 도전이 있습니다.',
  'PARTY_IMPACT_REVIEW_REQUIRED' => '참가 중인 파티 영향 확인이 필요합니다.',
  'WAITING_FOR_EARLIER_DISPUTE' => '먼저 시작된 인증 도전의 처리를 기다립니다.',
  'REQUIRED_EQUIPMENT_PRESENT' => '지정 장비를 해제하고 캐릭터 정보를 갱신해 주세요.',
  'NON_REQUIRED_EQUIPMENT_CHANGED' => '지정하지 않은 장비를 원래대로 돌려주세요.',
  'PROVIDER_EVIDENCE_PENDING' ||
  'ROSTER_EVIDENCE_PENDING' => '장비·원정대 정보를 확인 중입니다.',
  'CURRENT_READ_REQUIRED' ||
  'REVISION_CONFLICT' ||
  'CURSOR_STALE' => '정보가 변경되었습니다. 현재 상태를 다시 조회해 주세요.',
  'RETRY_LATER' || 'RATE_LIMITED' => '잠시 후 다시 확인해 주세요.',
  'NETWORK_UNAVAILABLE' || 'UPSTREAM_UNAVAILABLE' => '서버 연결을 확인한 뒤 다시 조회해 주세요.',
  'DISPUTE_OPENED' => '장비 확인을 마치고 인증 도전을 시작했습니다.',
  'OWNER_DEFENDED' => '원정대를 방어했습니다.',
  'OWNERSHIP_TRANSFERRED' || 'VERIFIED' => '현재 소유 상태를 반영했습니다.',
  'CHALLENGER_CANCELLED' || 'VERIFICATION_CANCELLED' => '취소된 요청입니다.',
  _ => '현재 상태를 확인해 주세요.',
};
