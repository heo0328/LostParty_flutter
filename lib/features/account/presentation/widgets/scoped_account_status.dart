import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../shared/formatters/local_date_time_formatter.dart';

import '../../data/repositories/scoped_character_cache_repository.dart';
import '../../domain/account_read_session.dart';
import '../../domain/policies/account_label_policy.dart';
import '../../domain/server_character_lifecycle.dart';
import '../../domain/services/roster_character_order.dart';
import '../viewmodels/scoped_account_view_model.dart';
import 'server_accounts_panel.dart';

Map<String, String> scopedAccountLabels(ScopedAccountViewModel model) =>
    model.registrationsCurrent
    ? AccountLabelPolicy.serverLabels(model.metadata)
    : {
        for (final r in model.registrations)
          r.registrationId: r.label.trim().isNotEmpty
              ? r.label
              : r.isMain
              ? '메인 계정'
              : '부계정',
      };

/// Invalid cached display data is an error, never a successful empty roster.
List<LifecycleCharacter>? scopedRosterCharacters(CachedRosterView view) {
  try {
    final values = view.registration.ownershipStatus == 'owned'
        ? view.characters.map((c) => jsonDecode(c.profileJson)).toList()
        : (view.registration.toStorage()['display']
              as Map<String, dynamic>)['preview'];
    if (values is! List) return null;
    return rosterByItemLevel(
      values.map((v) => LifecycleCharacter.fromJson(v as Map<String, dynamic>)),
      (c) => c.wire['item_level'] as String?,
    );
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

String scopedTime(DateTime value) => localDateTimeToSeconds(value);

class ScopedAccountFailureMessage extends StatelessWidget {
  const ScopedAccountFailureMessage({
    required this.failure,
    required this.seconds,
    this.onVerify,
    super.key,
  });
  final ScopedReadFailure failure;
  final int seconds;
  final VoidCallback? onVerify;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(switch (failure.kind) {
        ScopedReadFailureKind.storage =>
          '이 기기에 저장된 확인 정보를 읽거나 저장하지 못했습니다. 다시 시도해 주세요.',
        ScopedReadFailureKind.configuration =>
          '계정 연결 설정을 확인하지 못했습니다. 앱을 다시 실행해 주세요.',
        _ => accountReadErrorMessage(
          AccountReadException(failure.code, status: failure.status),
        ),
      }),
      if (seconds > 0) Text('$seconds초 후 다시 시도해 주세요.'),
      if (failure.code == 'OWNERSHIP_REQUIRED' && onVerify != null)
        TextButton(onPressed: onVerify, child: const Text('원정대 인증')),
    ],
  );
}
