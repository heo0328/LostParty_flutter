import 'package:flutter/material.dart';
import '../../../../app/widgets/bounded_page_body.dart';
import 'account_auth_actions.dart';
import 'account_responsive_layout.dart';
import 'ownership_notice_title.dart';

/// Shared current account shell for real member data and read-only examples.
class AccountOverviewFrame extends StatelessWidget {
  const AccountOverviewFrame({
    super.key,
    required this.children,
    required this.onSettings,
    this.authActions,
    this.busy = false,
  });
  final List<Widget> children;
  final VoidCallback onSettings;
  final Widget? authActions;
  final bool busy;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: authActions == null
          ? kToolbarHeight
          : AccountAuthActions.toolbarHeight(context),
      title: const OwnershipNoticeTitle(child: Text('내 계정')),
      flexibleSpace: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: busy
              ? const LinearProgressIndicator(
                  key: ValueKey('member-network-progress'),
                  minHeight: 2,
                )
              : const SizedBox.shrink(),
        ),
      ),
      actions: [
        ?authActions,
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
          tooltip: '설정',
        ),
      ],
    ),
    body: SafeArea(
      child: BoundedPageBody(
        viewportMaxWidth: AccountResponsiveLayout.pageMaxWidth + 32,
        child: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    ),
  );
}
