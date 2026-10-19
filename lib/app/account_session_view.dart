import 'package:flutter/widgets.dart';

import '../features/account/domain/account_read_session.dart';

/// Selects the existing account page without owning its models or API work.
class AccountSessionView extends StatelessWidget {
  const AccountSessionView({
    super.key,
    required this.session,
    required this.localBuilder,
    this.memberBuilder,
  });

  final AccountReadSession session;
  final WidgetBuilder localBuilder;
  final WidgetBuilder? memberBuilder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) =>
        (session.isAuthenticated ? memberBuilder : null)?.call(context) ??
        localBuilder(context),
  );
}
