import 'package:flutter/material.dart';

import '../../domain/account_read_session.dart';
import '../../domain/server_account_models.dart';

/// Shared editor; the original command owner still performs the write.
Future<(String, bool)?> showServerRegistrationEditDialog(
  BuildContext context, {
  required ServerAccountRegistration account,
  required String displayLabel,
  required AccountReadSession session,
}) async {
  if (!session.isAuthenticated) return null;
  final scope = accountReadScope(session);
  bool current() =>
      session.isAuthenticated &&
      session.userId == scope.userId &&
      session.generation == scope.generation;
  BuildContext? dialogContext;
  void changed() {
    final ctx = dialogContext;
    if (!current() && ctx != null && ctx.mounted) {
      final route = ModalRoute.of(ctx);
      if (route != null && route.isActive) Navigator.of(ctx).removeRoute(route);
    }
  }

  session.addListener(changed);
  try {
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (ctx) {
        dialogContext = ctx;
        if (!current()) {
          WidgetsBinding.instance.addPostFrameCallback((_) => changed());
        }
        return _ServerRegistrationEditDialog(
          account: account,
          displayLabel: displayLabel,
        );
      },
    );
    return current() ? result : null;
  } finally {
    session.removeListener(changed);
  }
}

class _ServerRegistrationEditDialog extends StatefulWidget {
  const _ServerRegistrationEditDialog({
    required this.account,
    required this.displayLabel,
  });
  final ServerAccountRegistration account;
  final String displayLabel;
  @override
  State<_ServerRegistrationEditDialog> createState() =>
      _ServerRegistrationEditDialogState();
}

class _ServerRegistrationEditDialogState
    extends State<_ServerRegistrationEditDialog> {
  late final TextEditingController label;
  late bool main;
  @override
  void initState() {
    super.initState();
    label = TextEditingController(text: widget.account.label);
    main = widget.account.isMain;
  }

  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.displayLabel} 수정'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: label,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: '표시명',
            helperText: '비워두면 현재 본·부계정 위치에 따라 표시합니다.',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('메인 계정'),
          value: main,
          onChanged: (value) => setState(() => main = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (label.text.trim(), main)),
        child: const Text('저장'),
      ),
    ],
  );
}
