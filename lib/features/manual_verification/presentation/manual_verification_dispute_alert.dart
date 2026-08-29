import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/formatters/korea_time_formatter.dart';
import '../domain/entities/manual_verification_request.dart';

Future<void> showManualVerificationDisputeAlert(
  BuildContext context, {
  required List<ManualVerificationRequest> disputes,
}) async {
  if (disputes.isEmpty) return;
  final dispute = disputes.first;
  final deadline = dispute.ownerResponseDeadlineAt;
  final deadlineLabel = deadline == null
      ? '기한 정보 없음'
      : KoreaTimeFormatter.dayAndTime(deadline);
  final extraCount = disputes.length - 1;
  final accountLabel = dispute.localAccountLabelSnapshot;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('소유권 방어 필요'),
      content: Text(
        '다른 사용자가 「$accountLabel」 게임 계정의 수동 인증 증명을 제출했습니다.\n\n'
        '방어 기한: $deadlineLabel\n\n'
        '${extraCount > 0 ? '외 $extraCount건의 방어 대기 중입니다.\n\n' : ''}'
        '24시간 안에 설정의 수동 인증에서 방어 인증을 완료하지 않으면 '
        '기존 인증 자격이 해지됩니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            context.push('/settings/manual-verification');
          },
          child: const Text('수동 인증으로 이동'),
        ),
      ],
    ),
  );
}
