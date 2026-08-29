import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../shared/formatters/korea_time_formatter.dart';
import '../../../operator_access/domain/repositories/operator_access_repository.dart';
import '../../domain/entities/manual_verification_request.dart';
import '../../domain/repositories/manual_verification_repository.dart';

class OperatorManualVerificationDetailPage extends StatefulWidget {
  const OperatorManualVerificationDetailPage({
    required this.requestId,
    required this.operatorAccessRepository,
    required this.repository,
    this.initialRequest,
    super.key,
  });

  final String requestId;
  final ManualVerificationRequest? initialRequest;
  final OperatorAccessRepository operatorAccessRepository;
  final ManualVerificationRepository repository;

  @override
  State<OperatorManualVerificationDetailPage> createState() =>
      _OperatorManualVerificationDetailPageState();
}

class _OperatorManualVerificationDetailPageState
    extends State<OperatorManualVerificationDetailPage> {
  late Future<_DetailState> _state;
  var _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _state = _load();
  }

  Future<_DetailState> _load() async {
    if (!await widget.operatorAccessRepository.isCurrentPlayerOperator()) {
      return const _DetailState.denied();
    }
    final queue = await widget.repository.loadPendingQueue();
    final request =
        widget.initialRequest ??
        queue.where((item) => item.id == widget.requestId).firstOrNull;
    if (request == null) {
      throw const ManualVerificationException('notFound', '요청을 찾을 수 없습니다.');
    }
    final context = await widget.repository.loadReviewContext(request);
    return _DetailState.allowed(request: request, review: context);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ManualVerificationException catch (error) {
      if (mounted) {
        var message = error.message ?? error.code;
        if (error.code == 'permission-denied') {
          final readiness =
              await widget.operatorAccessRepository.loadWriteReadiness();
          message = '$message\n${readiness.diagnosticSummary}';
        }
        setState(() {
          _message = message;
        });
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        var message = error.code == 'permission-denied'
            ? (error.message ?? error.code)
            : '요청을 처리하지 못했습니다. 네트워크를 확인해 주세요.';
        if (error.code == 'permission-denied') {
          final readiness =
              await widget.operatorAccessRepository.loadWriteReadiness();
          message = '$message\n${readiness.diagnosticSummary}';
        }
        setState(() => _message = message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = '처리하지 못했습니다. 네트워크를 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptReason({
    required String title,
    required Future<void> Function(String reason) onConfirm,
  }) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '사유'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _run(() => onConfirm(reason));
  }

  Future<void> _confirmForceApprove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('강제 인증'),
        content: const Text(
          '24시간 방어 기간 없이 요청자에게 즉시 소유권을 이전합니다. '
          '기존 소유자의 인증 자격은 해지됩니다. 계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('닫기'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('강제 인증'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => widget.repository.reviewForceApprove(widget.requestId));
  }

  Future<void> _confirmRejectDefense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방어 실패'),
        content: const Text(
          '기존 소유자의 방어를 실패 처리하고 챌린지 요청자에게 즉시 소유권을 이전합니다. '
          '기존 소유자에게 인증 금지는 적용하지 않습니다. 계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('닫기'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('방어 실패'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => widget.repository.reviewRejectDefense(widget.requestId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('수동 인증 상세')),
      body: FutureBuilder<_DetailState>(
        future: _state,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('요청을 불러오지 못했습니다.'));
          }
          final state = snapshot.data!;
          if (!state.allowed || state.request == null || state.review == null) {
            return const Center(child: Text('운영자 권한이 없습니다.'));
          }
          final request = state.request!;
          final review = state.review!;
          final isSelfOwned =
              review.existingOwnerPlayerId != null &&
              review.existingOwnerPlayerId == request.requesterPlayerId;
          final canForceApprove =
              review.hasActiveOwner &&
              !isSelfOwned &&
              !request.isDefenseRequest &&
              !review.isBlocked &&
              (request.isPending || request.isAwaitingOwnerResponse);
          final errorScheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('코드 ${request.verificationCode}'),
              Text(
                '${request.proofCharacterName} · ${request.proofServerName}'
                '${request.proofClassName == null ? '' : ' · ${request.proofClassName}'}',
              ),
              Text('요청 Player ${request.requesterPlayerId}'),
              Text('로컬 계정 ${request.localAccountLabelSnapshot}'),
              Text(
                '요청 ${KoreaTimeFormatter.dayAndTime(request.createdAt)} · '
                '만료 ${KoreaTimeFormatter.dayAndTime(request.expiresAt)}',
              ),
              Text(
                '대상 요청 ${request.attemptNumberForTarget}회 · '
                '전체 ${request.totalAttemptNumberForPlayer}회',
              ),
              Text(review.hasActiveOwner ? '기존 소유자 있음' : '기존 소유자 없음'),
              if (review.existingOwnerPlayerId != null)
                Text('기존 소유자 Player ${review.existingOwnerPlayerId}'),
              if (request.isDefenseRequest)
                Text('방어 요청 · 분쟁 ${request.defenseOfRequestId}'),
              Text(review.isBlocked ? '인증 금지됨' : '인증 금지 아님'),
              const SizedBox(height: 12),
              const Text('최신 원정대'),
              for (final line in review.rosterSummaries) Text(line),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!),
              ],
              const SizedBox(height: 16),
              if (!request.isDefenseRequest) ...[
                FilledButton(
                  key: const ValueKey('operatorManualApprove'),
                  onPressed: _busy || review.isBlocked || isSelfOwned
                      ? null
                      : () => _run(
                          () => widget.repository.reviewApprove(request.id),
                        ),
                  child: Text(
                    isSelfOwned
                        ? '요청자가 이미 소유 중'
                        : review.hasActiveOwner
                        ? '분쟁 개시 (24시간 방어)'
                        : '승인',
                  ),
                ),
                if (canForceApprove) ...[
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const ValueKey('operatorManualForceApprove'),
                    style: FilledButton.styleFrom(
                      backgroundColor: errorScheme.error,
                      foregroundColor: errorScheme.onError,
                    ),
                    onPressed: _busy ? null : _confirmForceApprove,
                    child: const Text('강제 인증'),
                  ),
                ],
              ] else ...[
                FilledButton(
                  key: const ValueKey('operatorManualApprove'),
                  onPressed: _busy || review.isBlocked
                      ? null
                      : () => _run(
                          () => widget.repository.reviewApproveDefense(
                            request.id,
                          ),
                        ),
                  child: const Text('방어 승인'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const ValueKey('operatorManualRejectDefense'),
                  style: FilledButton.styleFrom(
                    backgroundColor: errorScheme.error,
                    foregroundColor: errorScheme.onError,
                  ),
                  onPressed: _busy || review.isBlocked
                      ? null
                      : _confirmRejectDefense,
                  child: const Text('방어 실패'),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('operatorManualCancel'),
                onPressed: _busy
                    ? null
                    : () => _promptReason(
                        title: '요청 취소',
                        onConfirm: (reason) => widget.repository.reviewCancel(
                          requestId: request.id,
                          reason: reason,
                        ),
                      ),
                child: const Text('취소'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('operatorManualBlock'),
                onPressed: _busy
                    ? null
                    : () => _promptReason(
                        title: '인증 금지',
                        onConfirm: (reason) => widget.repository.reviewBlock(
                          requestId: request.id,
                          reason: reason,
                        ),
                      ),
                child: const Text('인증 금지'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailState {
  const _DetailState.denied()
    : allowed = false,
      request = null,
      review = null;

  const _DetailState.allowed({required this.request, required this.review})
    : allowed = true;

  final bool allowed;
  final ManualVerificationRequest? request;
  final ManualVerificationReviewContext? review;
}
