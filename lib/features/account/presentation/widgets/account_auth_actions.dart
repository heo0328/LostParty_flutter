import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../auth/domain/auth_session_controller.dart';
import '../../../auth/presentation/login_page.dart';

/// Shared account header actions; uses the existing authentication lifecycle.
class AccountAuthActions extends StatefulWidget {
  const AccountAuthActions({required this.auth, super.key});
  final AuthSessionController auth;
  static double toolbarHeight(BuildContext context) {
    final line = MediaQuery.textScalerOf(context).scale(16) * 1.4;
    return math.max(kToolbarHeight, line + 24);
  }

  @override
  State<AccountAuthActions> createState() => _AccountAuthActionsState();
}

class _AccountAuthActionsState extends State<AccountAuthActions> {
  bool _working = false;
  Future<void> _logout() async {
    if (_working || widget.auth.isBusy) return;
    final auth = widget.auth, generation = widget.auth.sessionGeneration;
    setState(() => _working = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('로그아웃할까요?'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('로그아웃'),
            ),
          ],
        ),
      );
      if (confirmed == true &&
          mounted &&
          auth.isAuthenticated &&
          auth.sessionGeneration == generation) {
        await auth.logout();
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) {
      final auth = widget.auth;
      final disabled = _working || auth.isBusy;
      if (!auth.isAuthenticated) {
        return Center(
          child: FilledButton(
            onPressed: disabled ? null : () => showLoginRequired(context, auth),
            child: const Text('로그인'),
          ),
        );
      }
      return Center(
        child: FilledButton(
          onPressed: disabled ? null : _logout,
          child: const Text('로그아웃'),
        ),
      );
    },
  );
}
