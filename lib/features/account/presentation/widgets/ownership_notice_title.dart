import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/ownership_dispute_controller.dart';

/// App-owned dependencies only. Mounting a title never starts a request.
class OwnershipNoticeScope extends InheritedWidget {
  const OwnershipNoticeScope({
    required this.controller,
    required this.onOpen,
    required super.child,
    super.key,
  });
  final OwnershipDisputeController controller;
  final VoidCallback onOpen;
  static OwnershipNoticeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OwnershipNoticeScope>();
  @override
  bool updateShouldNotify(OwnershipNoticeScope oldWidget) =>
      controller != oldWidget.controller || onOpen != oldWidget.onOpen;
}

/// Keeps the existing AppBar dimensions, leading/actions and body position.
class OwnershipNoticeTitle extends StatelessWidget {
  const OwnershipNoticeTitle({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scope = OwnershipNoticeScope.maybeOf(context);
    if (scope == null) return child;
    return ListenableBuilder(
      listenable: scope.controller,
      child: child,
      builder: (context, title) {
        final notice = scope.controller.signedIn
            ? scope.controller.notice
            : OwnershipNotice.none;
        if (notice == OwnershipNotice.none) return title!;
        final label = switch (notice) {
          OwnershipNotice.defenseRequired => '원정대 방어 필요 · 확인',
          OwnershipNotice.processing => '원정대 인증 처리 중 · 확인',
          _ => '원정대 인증 확인 필요 · 확인',
        };
        final textStyle = Theme.of(context).textTheme.labelSmall!.copyWith(
          color: Theme.of(context).colorScheme.primary,
          height: 1.1,
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final scaler = MediaQuery.textScalerOf(context);
            final direction = Directionality.of(context);
            final painter = TextPainter(
              text: TextSpan(text: label, style: textStyle),
              textDirection: direction,
              textScaler: scaler,
            )..layout();
            final line = painter.height, width = painter.width;
            painter.dispose();
            final titleStyle = DefaultTextStyle.of(context).style;
            final titleHeight =
                scaler.scale(titleStyle.fontSize ?? 20) *
                (titleStyle.height ?? 1.2);
            final height = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : kToolbarHeight;
            final fits =
                width <= constraints.maxWidth &&
                titleHeight + line + 4 <= height &&
                line + 4 <= 24;
            final callback = ModalRoute.of(context)?.isCurrent == false
                ? null
                : scope.onOpen;
            final safeTitle = DefaultTextStyle.merge(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: title!,
            );
            final action = Semantics(
              button: true,
              label: label,
              onTap: callback,
              excludeSemantics: true,
              child: Tooltip(
                message: label,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: callback,
                    borderRadius: BorderRadius.circular(6),
                    child: fits
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(label, style: textStyle, maxLines: 1),
                          )
                        : const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.warning_amber_outlined, size: 20),
                          ),
                  ),
                ),
              ),
            );
            if (fits) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [safeTitle, action],
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: safeTitle),
                action,
              ],
            );
          },
        );
      },
    );
  }
}

/// Explicit navigation only; no confirmation/cancellation/defense POSTs.
class OwnershipNoticeNavigation {
  OwnershipNoticeNavigation(this.router, this.controller);
  static const path = '/settings/game-account-verification';
  final GoRouter router;
  final OwnershipDisputeController controller;
  bool _opening = false;
  Future<void> open() async {
    if (!controller.signedIn ||
        controller.notice == OwnershipNotice.none ||
        _opening) {
      return;
    }
    final owners = controller.activeDisputes
        .where((v) => v.viewerRole == 'owner')
        .toList();
    final id = owners.length == 1 ? owners.single.id : null;
    if (router.state.uri.path == path) {
      if (id != null && !controller.commandBusy) {
        await controller.selectDispute(id);
      }
      return;
    }
    _opening = true;
    try {
      await router.push<void>(
        Uri(
          path: path,
          queryParameters: id == null ? null : {'disputeId': id},
        ).toString(),
      );
    } finally {
      _opening = false;
    }
  }

  void onOpen() => unawaited(open());
}
