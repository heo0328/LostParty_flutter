import 'dart:math' as math;

import 'package:flutter/material.dart';

const lostPartyEntryAnimationDuration = Duration(milliseconds: 2200);

class LostPartyEntryScreen extends StatefulWidget {
  const LostPartyEntryScreen({this.onAnimationCompleted, super.key});

  final VoidCallback? onAnimationCompleted;

  @override
  State<LostPartyEntryScreen> createState() => _LostPartyEntryScreenState();
}

class _LostPartyEntryScreenState extends State<LostPartyEntryScreen>
    with SingleTickerProviderStateMixin {
  static const _designSize = Size(941, 1672);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: lostPartyEntryAnimationDuration,
    )..addStatusListener(_handleAnimationStatus);
    _controller.forward();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onAnimationCompleted?.call();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF211747),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final coverScale = math.max(
              constraints.maxWidth / _designSize.width,
              constraints.maxHeight / _designSize.height,
            );

            return ClipRect(
              child: SizedBox.expand(
                child: OverflowBox(
                  alignment: Alignment.center,
                  minWidth: _designSize.width,
                  maxWidth: _designSize.width,
                  minHeight: _designSize.height,
                  maxHeight: _designSize.height,
                  child: Transform.scale(
                    scale: coverScale,
                    child: RepaintBoundary(
                      key: const ValueKey('lostPartyEntryScreen'),
                      child: SizedBox.fromSize(
                        size: _designSize,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/images/lost_party_loading_screen.png',
                              width: _designSize.width,
                              height: _designSize.height,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            ),
                            _LogoGlow(controller: _controller),
                            IgnorePointer(
                              child: _TwinkleLayer(controller: _controller),
                            ),
                            _LogoShine(controller: _controller),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LogoGlow extends StatelessWidget {
  const _LogoGlow({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey('lostPartyEntryGlow'),
      left: 176,
      top: 407,
      width: 589,
      height: 650,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final progress = _interval(controller.value, 0.04, 0.72);
          final pulse = math.sin(progress * math.pi);
          return Opacity(
            opacity: 0.03 + (pulse * 0.11),
            child: Transform.scale(scale: 0.96 + (pulse * 0.08), child: child),
          );
        },
        child: const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xBFD8B6FF), Color(0x45B99AF2), Color(0x00725A9F)],
              stops: [0, 0.46, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _TwinkleLayer extends StatelessWidget {
  const _TwinkleLayer({required this.controller});

  final AnimationController controller;

  static const _stars = <_StarSpec>[
    _StarSpec(left: 83, top: 78, size: 22, delay: 0),
    _StarSpec(left: 774, top: 99, size: 31, delay: 0.08),
    _StarSpec(left: 222, top: 230, size: 20, delay: 0.15),
    _StarSpec(left: 704, top: 241, size: 14, delay: 0.22),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey('lostPartyEntryTwinkles'),
      children: [
        for (final star in _stars)
          Positioned(
            left: star.left,
            top: star.top,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final progress = _interval(
                  controller.value,
                  star.delay,
                  star.delay + 0.42,
                );
                final pulse = math.sin(progress * math.pi);
                return Opacity(
                  opacity: pulse * 0.72,
                  child: Transform.scale(
                    scale: 0.72 + (pulse * 0.48),
                    child: child,
                  ),
                );
              },
              child: CustomPaint(
                size: Size.square(star.size),
                painter: const _StarPainter(),
              ),
            ),
          ),
      ],
    );
  }
}

class _LogoShine extends StatelessWidget {
  const _LogoShine({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey('lostPartyEntryShine'),
      left: 93,
      top: 485,
      width: 755,
      height: 690,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final progress = _interval(controller.value, 0.22, 0.78);
            final opacity = math.sin(progress * math.pi).clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned(
                  left: -145 + (progress * 1010),
                  top: -75,
                  width: 74,
                  height: 820,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(angle: -0.18, child: child),
                  ),
                ),
              ],
            );
          },
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x00FFFFFF),
                  Color(0x20FFFFFF),
                  Color(0x66FFFFFF),
                  Color(0x45DAB8FF),
                  Color(0x00FFFFFF),
                ],
                stops: [0, 0.24, 0.5, 0.7, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarSpec {
  const _StarSpec({
    required this.left,
    required this.top,
    required this.size,
    required this.delay,
  });

  final double left;
  final double top;
  final double size;
  final double delay;
}

class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, 0)
      ..quadraticBezierTo(
        center.dx * 1.14,
        center.dy * 0.84,
        size.width,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx * 1.14,
        center.dy * 1.16,
        center.dx,
        size.height,
      )
      ..quadraticBezierTo(center.dx * 0.86, center.dy * 1.16, 0, center.dy)
      ..quadraticBezierTo(center.dx * 0.86, center.dy * 0.84, center.dx, 0);

    canvas.drawPath(
      path,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFDCC8FF)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => false;
}

double _interval(double value, double begin, double end) {
  return ((value - begin) / (end - begin)).clamp(0.0, 1.0);
}
