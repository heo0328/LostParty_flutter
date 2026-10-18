import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Static presentation; the app-owned gate determines when navigation starts.
class LostPartyEntryScreen extends StatelessWidget {
  const LostPartyEntryScreen({this.embedded = false, super.key});

  final bool embedded;
  static const _designSize = Size(941, 1672);

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
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
    );
    return embedded
        ? screen
        : MaterialApp(debugShowCheckedModeBanner: false, home: screen);
  }
}
