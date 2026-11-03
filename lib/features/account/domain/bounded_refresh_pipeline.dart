import 'dart:async';
import 'dart:collection';

class RefreshPipelineStats {
  int maxReads = 0, maxQueued = 0, fetched = 0, applied = 0;
}

/// Fetches overlap; applying results is serial and never waits for an upload.
/// A pending reservation covers either one in-flight read or one queued result.
/// The applying result has its own single slot. No HTTP/DTO policy lives here.
class BoundedRefreshPipeline<Input, Fetched> {
  BoundedRefreshPipeline({this.concurrentReads = 5, this.pendingCapacity = 5}) {
    if (concurrentReads < 1 || concurrentReads > 15 || pendingCapacity < 1) {
      throw ArgumentError('Invalid refresh pipeline bounds');
    }
  }

  final int concurrentReads, pendingCapacity;

  Future<RefreshPipelineStats> run({
    required List<Input> inputs,
    required Future<Fetched> Function(Input) fetch,
    required Future<void> Function(Input, Fetched) apply,
    required void Function(Input, Object, StackTrace) onFailure,
    required void Function() requireCurrent,
    required bool Function() shouldStopScheduling,
  }) async {
    // Callers can retain their source list without changing this run's targets.
    final targets = List<Input>.of(inputs);
    final stats = RefreshPipelineStats();
    final queue = Queue<({Input input, Fetched value})>();
    var next = 0, reads = 0;
    var applying = false, stopped = false;
    Object? interruption;
    StackTrace? interruptedAt;
    void Function() wake = () {};

    void interrupt(Object error, StackTrace stack) {
      interruption ??= error;
      interruptedAt ??= stack;
      stopped = true;
      queue.clear();
      wake();
    }

    bool current() {
      if (interruption != null) return false;
      try {
        requireCurrent();
        return true;
      } catch (error, stack) {
        interrupt(error, stack);
        return false;
      }
    }

    void failure(Input input, Object error, StackTrace stack) {
      if (!current()) return;
      try {
        onFailure(input, error, stack);
      } catch (error, stack) {
        interrupt(error, stack);
      }
    }

    Future<void> read(Input input) async {
      try {
        final value = await fetch(input);
        stats.fetched++;
        if (current()) {
          queue.add((input: input, value: value));
          if (queue.length > stats.maxQueued) stats.maxQueued = queue.length;
        }
      } catch (error, stack) {
        failure(input, error, stack);
      } finally {
        reads--;
        wake();
      }
    }

    Future<void> process(({Input input, Fetched value}) result) async {
      try {
        if (current()) {
          await apply(result.input, result.value);
          stats.applied++;
        }
      } catch (error, stack) {
        failure(result.input, error, stack);
      } finally {
        applying = false;
        wake();
      }
    }

    while (true) {
      final changed = Completer<void>();
      wake = () {
        if (!changed.isCompleted) changed.complete();
      };
      if (!applying && queue.isNotEmpty && current()) {
        final result = queue.removeFirst();
        applying = true;
        unawaited(process(result));
      }
      try {
        // A provider cooldown stops new reads, not already fetched results.
        stopped = stopped || shouldStopScheduling();
        while (!stopped &&
            !shouldStopScheduling() &&
            next < targets.length &&
            reads < concurrentReads &&
            reads + queue.length < pendingCapacity &&
            current()) {
          final input = targets[next++];
          reads++;
          if (reads > stats.maxReads) stats.maxReads = reads;
          unawaited(read(input));
        }
      } catch (error, stack) {
        interrupt(error, stack);
      }
      if (reads == 0 && !applying && queue.isEmpty) break;
      await changed.future;
    }
    // Drain peers before surfacing an interruption. Never cancel their HTTP or
    // report completion while an already-started local commit is still pending.
    if (interruption != null) {
      Error.throwWithStackTrace(interruption!, interruptedAt!);
    }
    return stats;
  }
}
