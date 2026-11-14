import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../auth/domain/auth_session_controller.dart';
import '../../../auth/presentation/login_page.dart';

/// Shared account header actions; uses the existing authentication lifecycle.
class AccountAuthActions extends StatefulWidget {
  const AccountAuthActions({required this.auth, super.key});
  final AuthSessionController auth;
  static double toolbarHeight(BuildContext context) {
    final line = MediaQuery.textScalerOf(context).scale(16) * 1.4;
    return math.max(kToolbarHeight, line * 2 + 16);
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

  Future<void> _copy() async {
    final auth = widget.auth,
        id = widget.auth.userId,
        generation = widget.auth.sessionGeneration;
    if (_working || !auth.isAuthenticated || id == null) return;
    setState(() => _working = true);
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: id));
      message = '회원 ID를 복사했습니다.';
    } catch (_) {
      message = '회원 ID를 복사하지 못했습니다. 다시 시도해 주세요.';
    } finally {
      if (mounted) setState(() => _working = false);
    }
    if (!mounted ||
        !auth.isAuthenticated ||
        auth.sessionGeneration != generation) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      return SizedBox(
        width: math.max(120.0, MediaQuery.sizeOf(context).width - 160),
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              children: [
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Google 로그인 중'),
                    Text('오류 문의 시 사용자 ID를 함께 알려주세요.'),
                  ],
                ),
                IconButton(
                  tooltip: '회원 ID 복사',
                  onPressed: disabled ? null : _copy,
                  icon: const Icon(Icons.copy_outlined),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: disabled ? null : _logout,
                  child: const Text('로그아웃'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
