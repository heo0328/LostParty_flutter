import 'dart:async';
import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

enum StartupWork {
  splashWait,
  cacheConnection,
  cacheTransaction,
  services,
  sessionRestore,
  sessionRead,
  sessionParse,
  sessionWrite,
  accessToken,
  loadStage,
  localRead,
  listeners,
  dto,
  rosterRead,
  prepareBuild,
  profileBatch,
  armory,
  analysis,
  localSave,
  serverSync,
  catalog,
  character,
  pageWidgets,
}

enum StartupService { database, dio, router }

enum StartupEvent {
  start,
  firstAppFrame,
  entryGateReady,
  automaticWaiting,
  preparationBlocked,
  runnerStart,
  runnerDone,
  initialModel,
  finalModel,
  initialFrame,
  finalFrame,
  notVisible,
  sessionChanged,
  summary,
}

enum StartupResult {
  ok,
  partial,
  failed,
  interrupted,
  skipped,
  noTargets,
  incomplete,
}

/// One opt-in debug session; no identifiers, exception text or arbitrary labels.
class StartupTiming {
  static StartupTrace? _trace;
  static StartupTrace? get active => _trace?.active == true ? _trace : null;
  static void start() {
    if (!kDebugMode || !const bool.fromEnvironment('STARTUP_TIMING')) return;
    _trace ??= StartupTrace(sink: debugPrint);
  }

  @visibleForTesting
  static set testTrace(StartupTrace? value) => _trace = value;

  static T sync<T>(StartupWork work, T Function() action, {Enum? detail}) {
    final trace = active;
    if (trace == null) return action();
    if (work == StartupWork.pageWidgets || work == StartupWork.listeners) {
      final started = trace.micros;
      try {
        return action();
      } finally {
        trace.record(work, trace.micros - started);
      }
    }
    final span = trace.begin(work, detail: detail);
    try {
      return runZoned(action, zoneValues: {StartupTrace.parentKey: span.id});
    } catch (_) {
      span.result = StartupResult.failed;
      rethrow;
    } finally {
      span.end();
    }
  }

  static Future<T> run<T>(
    StartupWork work,
    Future<T> Function() action, {
    Enum? detail,
    int? ordinal,
  }) {
    final trace = active;
    if (trace == null) return action();
    final span = trace.begin(work, detail: detail, ordinal: ordinal);
    return runZoned(() async {
      try {
        return await action();
      } catch (_) {
        span.result = StartupResult.failed;
        rethrow;
      } finally {
        span.end();
      }
    }, zoneValues: {StartupTrace.parentKey: span.id});
  }
}

class StartupTrace {
  StartupTrace({
    required this.sink,
    Duration timeout = const Duration(seconds: 180),
  }) {
    _clock.start();
    event(StartupEvent.start);
    _timeout = Timer(timeout, () => finish(StartupResult.incomplete));
  }
  static final parentKey = Object();
  final void Function(String) sink;
  final int runId = DateTime.now().microsecondsSinceEpoch;
  final _clock = Stopwatch();
  Timer? _timeout;
  bool active = true;
  int _next = 0, requests = 0, _open = 0, _model = 0;
  final _work = <StartupWork, ({int calls, int micros, int max})>{};
  void record(StartupWork work, int micros) {
    if (!active) return;
    final old = _work[work];
    _work[work] = (
      calls: (old?.calls ?? 0) + 1,
      micros: (old?.micros ?? 0) + micros,
      max: micros > (old?.max ?? 0) ? micros : old!.max,
    );
  }

  int? _initialModel, _finalModel;
  int? _initialVsync, _finalVsync;
  int? _initialPublishedAt, _finalPublishedAt;
  bool _firstFrame = false, _entry = false, _visible = false;
  bool _initialFrame = false, _finalFrame = false, runnerDone = false;
  bool _framesAttached = false;
  Object? _session;
  bool _sessionBound = false;
  void session(Object identity, {required bool authenticated}) {
    if (_sessionBound && _session != identity) {
      event(StartupEvent.sessionChanged, result: StartupResult.interrupted);
      finish(StartupResult.interrupted);
    } else if (authenticated) {
      _session = identity;
      _sessionBound = true;
    }
  }

  int _frames = 0, _buildMax = 0, _rasterMax = 0;
  StartupResult _result = StartupResult.ok;
  int get micros => _clock.elapsedMicroseconds;
  int get modelGeneration => _model;
  int get parent => Zone.current[parentKey] as int? ?? 0;
  int nextRequest() => ++requests;

  void write(String fields) {
    if (!active) return;
    try {
      sink('[StartupTiming] run=$runId t_us=$micros $fields');
    } catch (_) {
      /* Diagnostics never change application results. */
    }
  }

  void event(
    StartupEvent event, {
    StartupResult result = StartupResult.ok,
    int? count,
  }) {
    write(
      'event=${event.name} result=${result.name}${count == null ? '' : ' count=$count'}',
    );
  }

  StartupSpan begin(StartupWork work, {Enum? detail, int? ordinal}) {
    final span = StartupSpan(this, ++_next, parent, work, detail, ordinal);
    if (active) _open++;
    span.emit('start');
    return span;
  }

  void attachFrames() {
    if (_framesAttached || !active) return;
    _framesAttached = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrames);
  }

  void _onFrames(List<FrameTiming> frames) {
    for (final frame in frames) {
      observeFrame(
        buildStart: frame.timestampInMicroseconds(FramePhase.buildStart),
        buildMicros: frame.buildDuration.inMicroseconds,
        rasterMicros: frame.rasterDuration.inMicroseconds,
      );
    }
  }

  @visibleForTesting
  void observeFrame({
    required int buildStart,
    required int buildMicros,
    required int rasterMicros,
  }) {
    if (!active) return;
    _frames++;
    if (buildMicros > _buildMax) _buildMax = buildMicros;
    if (rasterMicros > _rasterMax) _rasterMax = rasterMicros;
    if (!_firstFrame) {
      _firstFrame = true;
      event(StartupEvent.firstAppFrame);
      write(
        'event=frameDetail phase=first build_us=$buildMicros raster_us=$rasterMicros',
      );
    }
    if (!_initialFrame &&
        _initialVsync != null &&
        buildStart >= _initialVsync!) {
      _initialFrame = true;
      event(StartupEvent.initialFrame);
      write(
        'event=frameDetail phase=initial observed_after_model_us=${micros - _initialPublishedAt!} build_us=$buildMicros raster_us=$rasterMicros',
      );
    }
    if (!_finalFrame && _finalVsync != null && buildStart >= _finalVsync!) {
      _finalFrame = true;
      event(StartupEvent.finalFrame);
      write(
        'event=frameDetail phase=final observed_after_model_us=${micros - _finalPublishedAt!} build_us=$buildMicros raster_us=$rasterMicros',
      );
      finish(_result);
    }
  }

  void entryReady() {
    if (_entry) return;
    _entry = true;
    event(StartupEvent.entryGateReady);
    // Observe the existing gate transition's frame; never request a new frame.
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _finishIfNotVisible(),
    );
  }

  void visibility(bool value) {
    _visible = value;
  }

  int publishModel({required bool ready}) {
    if (!active) return 0;
    _model++;
    if (ready && _initialModel == null) {
      _initialModel = _model;
      _initialPublishedAt = micros;
      event(StartupEvent.initialModel, count: _model);
    }
    return _model;
  }

  void runnerFinished({required StartupResult result, required int count}) {
    if (runnerDone || !active) return;
    runnerDone = true;
    _result = result;
    event(StartupEvent.runnerDone, result: result, count: count);
  }

  void finalModelReady({required bool failed}) {
    if (!active || !runnerDone || _finalModel != null) return;
    _finalModel = _model;
    _finalPublishedAt = micros;
    if (failed) _result = StartupResult.failed;
    event(StartupEvent.finalModel, result: _result, count: _model);
    if (_entry) _finishIfNotVisible();
  }

  void _finishIfNotVisible() {
    if (active && _finalModel != null && _entry && !_visible) {
      event(StartupEvent.notVisible);
      finish(_result);
    }
  }

  /// Called from the actual account builder, not from a state notification.
  void builtModel(int generation, {required bool visible}) {
    if (!active || !visible || generation == 0) return;
    final initial =
        !_initialFrame && _initialModel != null && generation >= _initialModel!;
    final last =
        !_finalFrame && _finalModel != null && generation >= _finalModel!;
    if (!initial && !last) return;
    final vsync =
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!active) return;
      if (initial) _initialVsync ??= vsync;
      if (last) _finalVsync ??= vsync;
    });
  }

  void finish(StartupResult result) {
    if (!active) return;
    for (final entry in _work.entries) {
      write(
        'work=${entry.key.name} event=aggregate calls=${entry.value.calls} duration_us=${entry.value.micros} max_us=${entry.value.max}',
      );
    }
    event(StartupEvent.summary, result: result);
    write(
      'summary_ms=${micros ~/ 1000} requests=$requests open_spans=$_open '
      'frames=$_frames build_max_us=$_buildMax raster_max_us=$_rasterMax '
      'runner_done=$runnerDone final_model=${_finalModel != null} final_frame=$_finalFrame',
    );
    active = false;
    _timeout?.cancel();
    if (_framesAttached) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrames);
    }
  }
}

class StartupSpan {
  StartupSpan(
    this.trace,
    this.id,
    this.parent,
    this.work,
    this.detail,
    this.ordinal,
  ) : started = trace.micros;
  final StartupTrace trace;
  final int id, parent, started;
  final StartupWork work;
  final Enum? detail;
  final int? ordinal;
  StartupResult result = StartupResult.ok;
  bool _ended = false;
  void emit(String event) => trace.write(
    'span=$id parent=$parent work=${work.name} '
    '${detail == null ? '' : 'detail=${detail!.name} '}'
    '${ordinal == null ? '' : 'ordinal=$ordinal '}event=$event '
    'duration_us=${trace.micros - started} result=${result.name}',
  );
  void end() {
    if (_ended) return;
    _ended = true;
    if (trace.active) trace._open--;
    emit('end');
  }
}
