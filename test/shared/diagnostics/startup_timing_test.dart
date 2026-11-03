import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/diagnostics/startup_timing.dart';
import 'package:lost_party/shared/diagnostics/load_timing.dart';
import 'package:lost_party/features/account/presentation/viewmodels/scoped_startup_refresh_controller.dart';

import '../../features/account/backend_read/scoped_startup_refresh_controller_test.dart'
    as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> lines;
  late StartupTrace trace;
  setUp(() {
    lines = [];
    trace = StartupTrace(sink: lines.add);
    StartupTiming.testTrace = trace;
  });
  tearDown(() {
    trace.finish(StartupResult.interrupted);
    StartupTiming.testTrace = null;
  });

  test(
    'disabled instrumentation preserves result, call count and same error',
    () async {
      StartupTiming.testTrace = null;
      var calls = 0;
      expect(
        await StartupTiming.run(StartupWork.services, () async => ++calls),
        1,
      );
      final error = StateError('private-error');
      await expectLater(
        StartupTiming.run(StartupWork.services, () async {
          throw error;
        }),
        throwsA(same(error)),
      );
      expect(calls, 1);
      expect(lines, hasLength(1));
      StartupTiming.start(); // No STARTUP_TIMING define in this test process.
      expect(StartupTiming.active, isNull);
    },
  );

  test(
    'independent LoadTiming roots retain common startup parent and run',
    () async {
      await StartupTiming.run(StartupWork.services, () async {
        await Future.wait([
          LoadTiming.run(
            LoadStage.initialCache,
            () async {},
            root: true,
            sink: (_) {},
          ),
          LoadTiming.run(
            LoadStage.catalog,
            () async {},
            root: true,
            sink: (_) {},
          ),
        ]);
      });
      final starts = lines
          .where((l) => l.contains('span=') && l.contains('event=start'))
          .toList();
      expect(starts, hasLength(3));
      expect(starts.skip(1).every((l) => l.contains('parent=1 ')), isTrue);
      expect(lines.every((l) => l.contains('run=${trace.runId} ')), isTrue);
    },
  );

  test(
    'watchdog stops diagnostics without cancelling application future',
    () async {
      trace.finish(StartupResult.interrupted);
      trace = StartupTrace(
        sink: lines.add,
        timeout: const Duration(milliseconds: 1),
      );
      StartupTiming.testTrace = trace;
      final completion = Completer<int>();
      final result = StartupTiming.run(
        StartupWork.armory,
        () => completion.future,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(trace.active, isFalse);
      expect(
        lines.any((l) => l.contains('event=summary result=incomplete')),
        isTrue,
      );
      completion.complete(42);
      expect(await result, 42);
    },
  );

  testWidgets('runner, final model and its observed frame are separate', (
    tester,
  ) async {
    trace.visibility(true);
    trace.publishModel(ready: true);
    trace.runnerFinished(result: StartupResult.ok, count: 1);
    expect(lines.any((l) => l.contains('event=finalModel')), isFalse);
    trace.publishModel(ready: true);
    trace.finalModelReady(failed: false);
    expect(trace.active, isTrue);
    await tester.pumpWidget(
      Builder(
        builder: (_) {
          trace.builtModel(trace.modelGeneration, visible: true);
          return const SizedBox();
        },
      ),
    );
    expect(
      trace.active,
      isTrue,
    ); // A post-frame callback alone is not raster evidence.
    trace.observeFrame(buildStart: 1 << 60, buildMicros: 12, rasterMicros: 8);
    expect(trace.active, isFalse);
    expect(
      lines.indexWhere((l) => l.contains('event=runnerDone')),
      lessThan(lines.indexWhere((l) => l.contains('event=finalModel'))),
    );
    expect(
      lines.indexWhere((l) => l.contains('event=finalModel')),
      lessThan(lines.indexWhere((l) => l.contains('event=finalFrame'))),
    );
  });

  testWidgets(
    'hidden account screen is not reported as a rendered final frame',
    (tester) async {
      trace.runnerFinished(result: StartupResult.skipped, count: 0);
      trace.publishModel(ready: true);
      trace.finalModelReady(failed: false);
      trace.entryReady();
      await tester.pumpWidget(const SizedBox());
      expect(trace.active, isFalse);
      expect(lines.any((l) => l.contains('event=notVisible')), isTrue);
      expect(lines.any((l) => l.contains('event=finalFrame')), isFalse);
    },
  );

  test('member change interrupts safely without disclosing identity', () {
    trace.session('secret-member', authenticated: true);
    trace.session('other-secret', authenticated: true);
    expect(trace.active, isFalse);
    expect(lines.join(), isNot(contains('secret')));
    expect(lines.any((l) => l.contains('result=interrupted')), isTrue);
  });

  test('throwing sink cannot change successful or failed work', () async {
    trace.finish(StartupResult.interrupted);
    trace = StartupTrace(sink: (_) => throw StateError('sink unavailable'));
    StartupTiming.testTrace = trace;
    expect(StartupTiming.sync(StartupWork.dto, () => 7), 7);
    final error = StateError('source');
    await expectLater(
      StartupTiming.run(StartupWork.localSave, () async {
        throw error;
      }),
      throwsA(same(error)),
    );
    trace.finish(StartupResult.ok);
  });

  test('no targets is distinct from incomplete preparation', () async {
    final source = fixture.FakeSource()..rosters = [];
    final controller = ScopedStartupRefreshController(source);
    controller.initialize();
    await controller.startIfReady();
    expect(
      lines.any(
        (line) => line.contains('event=runnerDone result=noTargets count=0'),
      ),
      isTrue,
    );
    controller.dispose();
    source.dispose();
  });

  test(
    'unready key does not consume the run or declare a final model',
    () async {
      final source = fixture.FakeSource()..keyVersion = null;
      final controller = ScopedStartupRefreshController(source);
      controller.initialize();
      await controller.startIfReady();
      expect(controller.consumed, isFalse);
      expect(trace.runnerDone, isFalse);
      expect(trace.active, isTrue);
      expect(
        lines.any((line) => line.contains('event=preparationBlocked')),
        isTrue,
      );
      source.keyVersion = 1;
      source.changed();
      await controller.startIfReady();
      expect(trace.runnerDone, isTrue);
      expect(trace.active, isTrue);
      expect(controller.savedCount, 2);
      expect(lines.any((line) => line.contains('event=summary')), isFalse);
      controller.dispose();
      source.dispose();
    },
  );

  test(
    'real runner remains two workers, once only, and does not finish UI',
    () async {
      final source = fixture.FakeSource();
      final controller = ScopedStartupRefreshController(source);
      final barrier = Completer<void>();
      var current = 0, maximum = 0;
      source.onRefresh = (batch, target, guard, saved) async {
        current++;
        if (current > maximum) maximum = current;
        await barrier.future;
        current--;
        source.onRefresh = null;
        return source.refresh(batch, target, guard, saved);
      };
      controller.initialize();
      final pending = controller.startIfReady();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(maximum, 2);
      barrier.complete();
      await pending;
      await controller.startIfReady();
      expect(source.preparations, 1);
      expect(controller.savedCount, 2);
      expect(trace.runnerDone, isTrue);
      expect(lines.any((l) => l.contains('event=finalModel')), isFalse);
      expect(lines.join(), isNot(contains(fixture.member)));
      controller.dispose();
      source.dispose();
    },
  );
}
