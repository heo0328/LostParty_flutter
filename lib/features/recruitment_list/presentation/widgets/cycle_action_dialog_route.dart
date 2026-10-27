import 'package:flutter/material.dart';

/// Keep dialogs on the root navigator, including its full-screen modal barrier.
/// The detail page may dismiss only dialogs belonging to its own room/week.
RouteSettings cycleActionDialogRoute(String room, String target) =>
    RouteSettings(name: 'recruitment-action/$room/$target');

void closeCycleActionDialogs(BuildContext context, String room, String target) {
  final name = cycleActionDialogRoute(room, target).name;
  Navigator.of(
    context,
    rootNavigator: true,
  ).popUntil((route) => route is! PopupRoute || route.settings.name != name);
}
