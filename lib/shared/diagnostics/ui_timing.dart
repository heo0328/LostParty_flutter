import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

enum UiWork { pageWidgets, buildAnalysis }

/// Fixed labels only. Durations describe work on this isolate, not API latency.
class UiTiming {
  static UiTimingWindow? _current;

  static T measure<T>(UiWork work, T Function() action) {
    final window = _current;
    if (!kDebugMode || window == null || !window.active) return action();
    final clock = Stopwatch()..start();
    try {
      return action();
    } finally {
      window.addWork(work, clock.elapsedMicroseconds);
    }
  }
}

/// A bounded summary. Frames are engine UI/raster work; pageWidgets measures
/// only this page's widget construction, not descendant layout/paint.
class UiTimingWindow {
  UiTimingWindow({required this.sink});
  final void Function(String) sink;
  bool active = true;
  int _frames = 0, _uiMax = 0, _rasterMax = 0, _vsyncMax = 0;
  int _uiOver8 = 0, _uiOver16 = 0, _rasterOver8 = 0, _rasterOver16 = 0;
  final _work = <UiWork, ({int calls, int total, int max})>{};

  void addWork(UiWork work, int micros) {
    if (!active) return;
    final old = _work[work];
    _work[work] = (
      calls: (old?.calls ?? 0) + 1,
      total: (old?.total ?? 0) + micros,
      max: micros > (old?.max ?? 0) ? micros : (old?.max ?? 0),
    );
  }

  void addFrame({
    required int uiMicros,
    required int rasterMicros,
    required int vsyncMicros,
  }) {
    if (!active) return;
    _frames++;
    if (uiMicros > _uiMax) _uiMax = uiMicros;
    if (rasterMicros > _rasterMax) _rasterMax = rasterMicros;
    if (vsyncMicros > _vsyncMax) _vsyncMax = vsyncMicros;
    if (uiMicros > 8333) _uiOver8++;
    if (uiMicros > 16667) _uiOver16++;
    if (rasterMicros > 8333) _rasterOver8++;
    if (rasterMicros > 16667) _rasterOver16++;
  }

  void flush(int elapsedMs) {
    if (active && (_frames > 0 || _work.isNotEmpty)) {
      final fields = [
        '[UiTiming] screen=memberAccount mode=debug window_ms=$elapsedMs frames=$_frames',
        'ui_max_ms=${_uiMax / 1000} ui_over8=$_uiOver8 ui_over16=$_uiOver16',
        'raster_max_ms=${_rasterMax / 1000} raster_over8=$_rasterOver8 raster_over16=$_rasterOver16',
        'vsync_max_ms=${_vsyncMax / 1000}',
        for (final work in UiWork.values)
          '${work.name}_calls=${_work[work]?.calls ?? 0} '
              '${work.name}_total_ms=${(_work[work]?.total ?? 0) / 1000} '
              '${work.name}_max_ms=${(_work[work]?.max ?? 0) / 1000}',
      ];
      try {
        sink(fields.join(' '));
      } catch (_) {
        // Diagnostic output must never interrupt rendering or application work.
      }
    }
    _frames = _uiMax = _rasterMax = _vsyncMax = 0;
    _uiOver8 = _uiOver16 = _rasterOver8 = _rasterOver16 = 0;
    _work.clear();
  }
}

/// No visual/layout changes and no state updates from measurements.
class UiFrameProbe extends StatefulWidget {
  const UiFrameProbe({required this.child, this.sink, super.key});
  final Widget child;
  final void Function(String)? sink;
  @override
  State<UiFrameProbe> createState() => _UiFrameProbeState();
}

class _UiFrameProbeState extends State<UiFrameProbe> {
  UiTimingWindow? _window;
  Timer? _timer;
  final _clock = Stopwatch();

  @override
  void initState() {
    super.initState();
    if (!kDebugMode) return;
    _window = UiTimingWindow(sink: widget.sink ?? (line) => debugPrint(line));
    UiTiming._current = _window;
    _clock.start();
    SchedulerBinding.instance.addTimingsCallback(_frames);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _flush());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final window = _window;
    if (window == null) return;
    final active =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (window.active != active) {
      _flush();
      window.active = active;
    }
  }

  void _frames(List<FrameTiming> frames) {
    if (!mounted || _window?.active != true) return;
    for (final frame in frames) {
      _window!.addFrame(
        uiMicros: frame.buildDuration.inMicroseconds,
        rasterMicros: frame.rasterDuration.inMicroseconds,
        vsyncMicros: frame.vsyncOverhead.inMicroseconds,
      );
    }
  }

  void _flush() {
    _window?.flush(_clock.elapsedMilliseconds);
    _clock.reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_window != null) {
      SchedulerBinding.instance.removeTimingsCallback(_frames);
      _flush();
      _window!.active = false;
      if (identical(UiTiming._current, _window)) UiTiming._current = null;
    }
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
