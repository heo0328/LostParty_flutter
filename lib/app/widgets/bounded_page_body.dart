import 'package:flutter/widgets.dart';

/// Bounds the page viewport without owning scrolling or sizing its contents.
class BoundedPageBody extends StatelessWidget {
  const BoundedPageBody({
    required this.child,
    this.viewportMaxWidth = maxWidth,
    super.key,
  });

  static const maxWidth = 1600.0;
  final Widget child;
  final double viewportMaxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: viewportMaxWidth),
      child: child,
    ),
  );
}
