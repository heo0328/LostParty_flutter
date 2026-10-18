import 'package:flutter/material.dart';

/// Keep the complete game name in a stable two-line area beside the crown.
class CharacterNameLabel extends StatelessWidget {
  const CharacterNameLabel(this.name, {this.style, super.key});
  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? Theme.of(context).textTheme.titleMedium!;
    final base = style.fontSize ?? 16;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var size = base;
        while (size > 1) {
          final painter = TextPainter(
            text: TextSpan(
              text: name,
              style: style.copyWith(fontSize: size, height: 1.2),
            ),
            textDirection: Directionality.of(context),
            maxLines: 2,
            textScaler: scaler,
          )..layout(maxWidth: constraints.maxWidth);
          final fits = !painter.didExceedMaxLines;
          painter.dispose();
          if (fits) break;
          size -= 0.5;
        }
        return SizedBox(
          height: scaler.scale(base) * 2.4,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              name,
              maxLines: 2,
              softWrap: true,
              style: style.copyWith(fontSize: size, height: 1.2),
            ),
          ),
        );
      },
    );
  }
}
