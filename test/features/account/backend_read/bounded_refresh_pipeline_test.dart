import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/bounded_refresh_pipeline.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'five reads, serial writes, bounded waiting and no lost results',
    () async {
      final reads = List.generate(15, (_) => Completer<int>());
      final commits = List.generate(15, (_) => Completer<void>());
      final started = <int>[], saved = <int>[];
      var fetching = 0, maximumReads = 0, writing = 0, maximumWrites = 0;
      final run = BoundedRefreshPipeline<int, int>().run(
        inputs: List.generate(15, (i) => i),
        fetch: (id) async {
          started.add(id);
          fetching++;
          if (fetching > maximumReads) maximumReads = fetching;
          final result = await reads[id].future;
          fetching--;
          return result;
        },
        apply: (id, value) async {
          expect(value, id * 10);
          writing++;
          if (writing > maximumWrites) maximumWrites = writing;
          await commits[id].future;
          writing--;
          saved.add(id);
        },
        onFailure: (_, error, _) => fail('$error'),
        requireCurrent: () {},
        shouldStopScheduling: () => false,
      );
      expect(started, [0, 1, 2, 3, 4]);
      for (var i = 4; i >= 0; i--) {
        reads[i].complete(i * 10);
      }
      await tick();
      // One applying value plus at most five reserved reads/queued results.
      expect(started, hasLength(6));
      reads[5].complete(50);
      await tick();
      expect(
        started,
        hasLength(6),
      ); // Slow disk cannot grow the raw response queue.
      for (final commit in commits) {
        commit.complete();
      }
      for (var i = 6; i < reads.length; i++) {
        reads[i].complete(i * 10);
      }
      await run;
      expect(maximumReads, 5);
      expect(maximumWrites, 1);
      expect(saved, hasLength(15));
      expect(saved.toSet(), List.generate(15, (i) => i).toSet());
      expect(
        saved.first,
        4,
      ); // Arrival order, not array index, drives application.
    },
  );

  test('fifteen reads remain bounded and apply serially', () async {
    final gate = Completer<int>();
    var reads = 0, peakReads = 0, applying = 0, peakApply = 0;
    final run =
        BoundedRefreshPipeline<int, int>(
          concurrentReads: 15,
          pendingCapacity: 15,
        ).run(
          inputs: List.generate(20, (i) => i),
          fetch: (id) async {
            reads++;
            if (reads > peakReads) peakReads = reads;
            await gate.future;
            reads--;
            return id;
          },
          apply: (_, _) async {
            applying++;
            if (applying > peakApply) peakApply = applying;
            await tick();
            applying--;
          },
          onFailure: (_, error, _) => fail('$error'),
          requireCurrent: () {},
          shouldStopScheduling: () => false,
        );
    expect(reads, 15);
    gate.complete(0);
    final stats = await run;
    expect(peakReads, 15);
    expect(peakApply, 1);
    expect(stats.maxQueued, lessThanOrEqualTo(15));
    expect(stats.applied, 20);
  });

  test('comparison bound two and an immutable input snapshot', () async {
    final gate = Completer<int>();
    final inputs = [1, 2, 3];
    final started = <int>[], saved = <int>[];
    final run = BoundedRefreshPipeline<int, int>(concurrentReads: 2).run(
      inputs: inputs,
      fetch: (id) {
        started.add(id);
        return gate.future;
      },
      apply: (id, _) async {
        saved.add(id);
      },
      onFailure: (_, error, _) => fail('$error'),
      requireCurrent: () {},
      shouldStopScheduling: () => false,
    );
    inputs.clear();
    expect(started, [1, 2]);
    gate.complete(1);
    await run;
    expect(saved.toSet(), {1, 2, 3});
  });

  test('a read and a local save failure leave other items available', () async {
    final failed = <int>[], saved = <int>[];
    await BoundedRefreshPipeline<int, int>().run(
      inputs: List.generate(9, (i) => i),
      fetch: (id) async {
        if (id == 1) throw StateError('read');
        return id;
      },
      apply: (id, value) async {
        if (id == 5) throw StateError('save');
        saved.add(id);
      },
      onFailure: (id, _, _) {
        failed.add(id);
      },
      requireCurrent: () {},
      shouldStopScheduling: () => false,
    );
    expect(failed.toSet(), {1, 5});
    expect(saved, hasLength(7));
  });

  test(
    'cooldown stops assigning reads but saves in-flight peer successes',
    () async {
      final gates = List.generate(9, (_) => Completer<int>());
      final started = <int>[], saved = <int>[];
      var stopped = false;
      final run = BoundedRefreshPipeline<int, int>().run(
        inputs: List.generate(9, (i) => i),
        fetch: (id) {
          started.add(id);
          return gates[id].future;
        },
        apply: (id, _) async {
          saved.add(id);
        },
        onFailure: (_, _, _) {
          stopped = true;
        },
        requireCurrent: () {},
        shouldStopScheduling: () => stopped,
      );
      gates[0].completeError(StateError('cooldown'));
      await tick();
      for (var i = 1; i < 5; i++) {
        gates[i].complete(i);
      }
      await run;
      expect(started, [0, 1, 2, 3, 4]);
      expect(saved.toSet(), {1, 2, 3, 4});
    },
  );

  test('synchronous provider failure immediately stops assignment', () async {
    var attempts = 0, stopped = false;
    await BoundedRefreshPipeline<int, int>().run(
      inputs: [1, 2, 3],
      fetch: (_) {
        attempts++;
        throw StateError('key');
      },
      apply: (_, _) async {
        fail('No response to save');
      },
      onFailure: (_, _, _) {
        stopped = true;
      },
      requireCurrent: () {},
      shouldStopScheduling: () => stopped,
    );
    expect(attempts, 1);
  });

  test(
    'member change discards stale results and drains every started peer',
    () async {
      final gates = List.generate(5, (_) => Completer<int>());
      final error = StateError('scope changed');
      var valid = true, settled = false, saves = 0;
      final run = BoundedRefreshPipeline<int, int>().run(
        inputs: List.generate(9, (i) => i),
        fetch: (id) => gates[id].future,
        apply: (_, _) async {
          saves++;
        },
        onFailure: (_, _, _) {
          fail('Scope interruption is not an item failure');
        },
        requireCurrent: () {
          if (!valid) throw error;
        },
        shouldStopScheduling: () => false,
      );
      final observed = run.then<void>(
        (_) {
          fail('Expected interruption');
        },
        onError: (Object e) {
          expect(e, same(error));
          settled = true;
        },
      );
      valid = false;
      gates[0].complete(0);
      await tick();
      expect(settled, isFalse);
      for (var i = 1; i < 5; i++) {
        gates[i].complete(i);
      }
      await observed;
      expect(settled, isTrue);
      expect(saves, 0);
    },
  );

  test(
    'failure callback exception drains peers and preserves original error',
    () async {
      final peer = Completer<int>();
      final error = StateError('failure callback');
      final run = BoundedRefreshPipeline<int, int>(concurrentReads: 2).run(
        inputs: [0, 1, 2],
        fetch: (id) => id == 0 ? Future.error(StateError('read')) : peer.future,
        apply: (_, _) async {
          fail('Interrupted result');
        },
        onFailure: (_, _, _) {
          throw error;
        },
        requireCurrent: () {},
        shouldStopScheduling: () => false,
      );
      final check = expectLater(run, throwsA(same(error)));
      await tick();
      peer.complete(1);
      await check;
    },
  );

  test('empty run performs no requests or commits', () async {
    await BoundedRefreshPipeline<int, int>().run(
      inputs: [],
      fetch: (_) async => throw StateError('unexpected read'),
      apply: (_, _) async => throw StateError('unexpected save'),
      onFailure: (_, _, _) => fail('unexpected failure'),
      requireCurrent: () {},
      shouldStopScheduling: () => false,
    );
    expect(
      () => BoundedRefreshPipeline<int, int>(concurrentReads: 16),
      throwsArgumentError,
    );
    expect(
      () => BoundedRefreshPipeline<int, int>(pendingCapacity: 0),
      throwsArgumentError,
    );
  });
}
