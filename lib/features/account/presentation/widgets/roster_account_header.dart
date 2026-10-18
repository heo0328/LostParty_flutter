import 'package:flutter/material.dart';

/// The authentication action stays beside the name, with an independent hit target.
class RosterAccountHeader extends StatelessWidget {
  const RosterAccountHeader({
    required this.label,
    this.onVerify,
    this.onEdit,
    this.onCharacters,
    this.showEdit = false,
    this.showCharacters = false,
    this.showVerify = false,
    super.key,
  });
  final String label;
  final bool showEdit, showCharacters, showVerify;
  final VoidCallback? onVerify, onEdit, onCharacters;

  Widget _name(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        fit: FlexFit.loose,
        child: Tooltip(
          message: label,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
      if (showVerify || onVerify != null) ...[
        const SizedBox(width: 6),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 26),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          onPressed: onVerify,
          child: const Text('원정대 인증'),
        ),
      ],
    ],
  );
  List<Widget> get _actions => [
    if (showEdit || onEdit != null)
      IconButton(
        tooltip: '원정대 이름 변경',
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
      ),
    if (showCharacters || onCharacters != null)
      IconButton(
        tooltip: '캐릭터 관리',
        onPressed: onCharacters,
        icon: const Icon(Icons.tune),
      ),
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actions = _actions;
      if (constraints.maxWidth < 400 &&
          MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _name(context),
            if (actions.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: _name(context)),
          ...actions,
        ],
      );
    },
  );
}
