import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/diagnostics/ui_timing.dart';

void main() {
  test(
    'bounded frame/work summary counts once, resets and ignores inactive input',
    () {
      final lines = <String>[];
      final window = UiTimingWindow(sink: lines.add);
      window.addWork(UiWork.pageWidgets, 0);
      window.addWork(UiWork.pageWidgets, 2500);
      window.addWork(UiWork.buildAnalysis, 30000);
      window.addFrame(uiMicros: 20000, rasterMicros: 9000, vsyncMicros: 6000);
      window.addFrame(uiMicros: 3000, rasterMicros: 17000, vsyncMicros: 1000);
      window.flush(2000);
      expect(lines.single, contains('frames=2'));
      expect(lines.single, contains('ui_max_ms=20.0 ui_over8=1 ui_over16=1'));
      expect(
        lines.single,
        contains('raster_max_ms=17.0 raster_over8=2 raster_over16=1'),
      );
      expect(
        lines.single,
        contains(
          'pageWidgets_calls=2 pageWidgets_total_ms=2.5 pageWidgets_max_ms=2.5',
        ),
      );
      expect(lines.single, contains('buildAnalysis_calls=1'));
      window.flush(2000);
      expect(lines, hasLength(1));
      window.active = false;
      window.addWork(UiWork.pageWidgets, 8000);
      window.addFrame(uiMicros: 50000, rasterMicros: 40000, vsyncMicros: 0);
      window.flush(2000);
      expect(lines, hasLength(1));
    },
  );

  test('broken output is ignored and its window still clears', () {
    final window = UiTimingWindow(sink: (_) => throw StateError('output'));
    window.addFrame(uiMicros: 0, rasterMicros: 0, vsyncMicros: 0);
    expect(() => window.flush(2), returnsNormally);
    window.flush(2);
  });

  testWidgets(
    'probe preserves action failures, pauses offscreen and releases on disposal',
    (tester) async {
      final lines = <String>[];
      Widget screen(bool active) => MaterialApp(
        home: TickerMode(
          enabled: active,
          child: UiFrameProbe(sink: lines.add, child: const SizedBox()),
        ),
      );
      await tester.pumpWidget(screen(true));
      final failure = StateError('private payload');
      expect(UiTiming.measure(UiWork.pageWidgets, () => 7), 7);
      expect(
        () => UiTiming.measure<void>(UiWork.buildAnalysis, () => throw failure),
        throwsA(same(failure)),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(lines.single, contains('buildAnalysis_calls=1'));
      expect(lines.join(), isNot(contains('private payload')));
      await tester.pumpWidget(screen(false));
      final count = lines.length;
      UiTiming.measure(UiWork.buildAnalysis, () => 9);
      await tester.pump(const Duration(seconds: 2));
      expect(lines, hasLength(count));
      await tester.pumpWidget(const SizedBox());
      expect(UiTiming.measure(UiWork.pageWidgets, () => 11), 11);
      await tester.pump(const Duration(seconds: 3));
      expect(lines, hasLength(count));
    },
  );
}
