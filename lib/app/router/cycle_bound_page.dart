import 'package:flutter/widgets.dart';

import '../../features/recruitment_list/domain/policies/party_cycle_policy.dart';
import '../../features/recruitment_list/domain/services/party_cycle_runtime.dart';

/// Route refreshes can reuse an unchanged branch Navigator. Listen inside the
/// page so both visible and retained tabs receive the new query/command cycle.
class CycleBoundPage extends StatelessWidget {
  const CycleBoundPage({
    super.key,
    required this.runtime,
    required this.builder,
  });

  final PartyCycleRuntime runtime;
  final Widget Function(BuildContext context, PartyCycleWindow cycle) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: runtime,
    builder: (context, _) => builder(context, runtime.current),
  );
}
