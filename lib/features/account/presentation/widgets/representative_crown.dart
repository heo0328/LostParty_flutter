import 'package:flutter/material.dart';

/// Small crown with a full 48px hit target, independent of the card's tap.
class RepresentativeCrown extends StatelessWidget {
  const RepresentativeCrown({
    required this.selected,
    required this.busy,
    required this.label,
    required this.onPressed,
    super.key,
  });
  final bool selected, busy;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: IconButton(
      tooltip: onPressed == null && !selected
          ? '$label · 서버 상태 또는 활동 자격 확인 필요'
          : label,
      onPressed: onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : CustomPaint(size: const Size(18, 18), painter: _Crown(selected)),
    ),
  );
}

class _Crown extends CustomPainter {
  const _Crown(this.selected);
  final bool selected;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 18, size.height / 18);
    final path = Path()
      ..moveTo(3, 13)
      ..lineTo(1.5, 5)
      ..lineTo(6, 8)
      ..lineTo(9, 2)
      ..lineTo(12, 8)
      ..lineTo(16.5, 5)
      ..lineTo(15, 13)
      ..close();
    if (selected) {
      canvas.drawPath(path, Paint()..color = const Color(0xFFF5DEA0));
    }
    final outline = Paint()
      ..color = const Color(0xFF806420)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outline);
    canvas.drawLine(const Offset(3, 16), const Offset(15, 16), outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Crown oldDelegate) => selected != oldDelegate.selected;
}
