import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum LoadStage {
  accountBootstrap,
  accountRefresh,
  initialCache,
  roster,
  initialSelection,
  displayCache,
  activeRestore,
  displayReady,
  inactiveRestore,
  weeklyRefresh,
  weeklyCache,
  catalog,
  cycle,
  weeklyBatch,
  automaticRefresh,
  prepareRefresh,
  characterRefresh,
}

enum LocalLoadWork {
  registrations,
  roster,
  presentation,
  preferences,
  dealer,
  support,
  listeners,
}

/// Client elapsed time only. Never accepts URLs, identifiers or error text.
class LoadTiming {
  static final _key = Object();
  static int _sequence = 0;

  static List<_Span> get _spans =>
      Zone.current[_key] as List<_Span>? ?? const [];

  /// Elapsed local work, including DB/guard/wait time; not SQL execution time.
  static Future<T> local<T>(
    LocalLoadWork kind,
    Future<T> Function() action,
  ) async {
    final spans = _spans;
    if (!kDebugMode || spans.isEmpty) return action();
    final clock = Stopwatch()..start();
    try {
      return await action();
    } finally {
      clock.stop();
      for (final span in spans) {
        span.recordLocal(kind, clock.elapsedMicroseconds);
      }
    }
  }

  static void listeners(void Function() action) {
    final spans = _spans;
    if (!kDebugMode || spans.isEmpty) {
      action();
      return;
    }
    final clock = Stopwatch()..start();
    try {
      action();
    } finally {
      clock.stop();
      for (final span in spans) {
        span.recordLocal(LocalLoadWork.listeners, clock.elapsedMicroseconds);
      }
    }
  }

  static Future<T> run<T>(
    LoadStage stage,
    Future<T> Function() action, {
    bool root = false,
    bool enabled = kDebugMode,
    void Function(String)? sink,
  }) async {
    if (!kDebugMode || !enabled) return action();
    final parents = root ? <_Span>[] : _spans;
    final span = _Span(
      parents.isEmpty ? ++_sequence : parents.first.run,
      stage,
      sink ?? (parents.isEmpty ? (s) => debugPrint(s) : parents.first.sink),
    );
    span.emit('start');
    try {
      return await runZoned(
        action,
        zoneValues: {
          _key: [...parents, span],
        },
      );
    } catch (_) {
      span.failed = true;
      for (final parent in parents) {
        parent.failed = true;
      }
      rethrow;
    } finally {
      span.clock.stop();
      span.emitLocal();
      span.emit('end');
    }
  }

  /// Each actual network attempt, including a retry, counts once.
  static Future<T> http<T>(Future<T> Function() action) async {
    final spans = _spans;
    if (!kDebugMode || spans.isEmpty) return action();
    for (final span in spans) {
      span.requests++;
    }
    final clock = Stopwatch()..start();
    try {
      return await action();
    } catch (error) {
      for (final span in spans) {
        span.httpErrors++;
      }
      final category = error is DioException
          ? switch (error.type) {
              DioExceptionType.connectionTimeout ||
              DioExceptionType.sendTimeout ||
              DioExceptionType.receiveTimeout => 'timeout',
              DioExceptionType.connectionError => 'connection',
              DioExceptionType.badResponse => 'http_response',
              DioExceptionType.cancel => 'cancelled',
              _ => 'other',
            }
          : 'other';
      final status = error is DioException ? error.response?.statusCode : null;
      spans.last.emit(
        'http_error category=$category '
        'http_status=${status != null && status >= 100 && status <= 599 ? status : 0}',
      );
      rethrow;
    } finally {
      clock.stop();
      for (final span in spans) {
        span.httpMicros += clock.elapsedMicroseconds;
      }
    }
  }

  /// Report handled fallback/cancellation without logging the exception.
  static void failure() {
    for (final span in _spans) {
      span.failed = true;
    }
  }
}

class _Span {
  _Span(this.run, this.stage, this.sink);
  final int run;
  final LoadStage stage;
  final void Function(String) sink;
  final clock = Stopwatch()..start();
  int requests = 0, httpMicros = 0, httpErrors = 0;
  bool failed = false;
  final local = <LocalLoadWork, ({int count, int micros, int maxMicros})>{};

  void recordLocal(LocalLoadWork kind, int micros) {
    final previous = local[kind];
    local[kind] = (
      count: (previous?.count ?? 0) + 1,
      micros: (previous?.micros ?? 0) + micros,
      maxMicros: micros > (previous?.maxMicros ?? 0)
          ? micros
          : (previous?.maxMicros ?? 0),
    );
  }

  void emitLocal() {
    for (final entry in local.entries) {
      try {
        sink(
          '[LoadTiming] run=$run stage=${stage.name} event=local '
          'work=${entry.key.name} calls=${entry.value.count} '
          'total_ms=${entry.value.micros ~/ 1000} '
          'max_ms=${entry.value.maxMicros ~/ 1000}',
        );
      } catch (_) {
        // Logging must not affect the measured work.
      }
    }
  }

  void emit(String event) {
    try {
      sink(
        '[LoadTiming] run=$run stage=${stage.name} event=$event '
        'ms=${clock.elapsedMilliseconds} requests=$requests '
        'http_ms=${httpMicros ~/ 1000} http_errors=$httpErrors '
        'status=${failed ? 'interrupted' : 'ok'}',
      );
    } catch (_) {
      // Diagnostics must never change the operation's result or exception.
    }
  }
}
