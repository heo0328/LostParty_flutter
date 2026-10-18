import 'package:dio/dio.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/diagnostics/load_timing.dart';

void main() {
  test('disabled timing preserves exact failure without emitting', () async {
    final lines = <String>[];
    final error = StateError('private token and character name');
    await expectLater(
      LoadTiming.run<void>(
        LoadStage.roster,
        () async => throw error,
        enabled: false,
        sink: lines.add,
      ),
      throwsA(same(error)),
    );
    expect(lines, isEmpty);
  });

  test(
    'parallel phases and independent roots do not mix request counts',
    () async {
      final lines = <String>[];
      final gate = Completer<void>();
      await LoadTiming.run(
        LoadStage.accountRefresh,
        () async {
          await Future.wait([
            LoadTiming.run(LoadStage.activeRestore, () async {
              await LoadTiming.http(() async {
                gate.complete();
                return 1;
              });
              await LoadTiming.http(() async => 2);
            }),
            LoadTiming.run(
              LoadStage.weeklyRefresh,
              () async {
                await gate.future;
                await LoadTiming.http(() async => 3);
              },
              root: true,
              sink: lines.add,
            ),
          ]);
        },
        root: true,
        sink: lines.add,
      );
      final active = lines.singleWhere(
        (s) => s.contains('stage=activeRestore event=end'),
      );
      final total = lines.singleWhere(
        (s) => s.contains('stage=accountRefresh event=end'),
      );
      expect(active, contains('requests=2'));
      expect(total, contains('requests=2'));
      final weekly = lines.singleWhere(
        (s) => s.contains('stage=weeklyRefresh event=end'),
      );
      expect(weekly, contains('requests=1'));
      expect(weekly.split(' ')[1], isNot(total.split(' ')[1]));
    },
  );

  test(
    'handled request failures count attempts without logging secrets',
    () async {
      final lines = <String>[];
      final error = StateError(
        'Bearer secret name UUID /v1/private?key=secret',
      );
      await LoadTiming.run(LoadStage.roster, () async {
        try {
          await LoadTiming.http<void>(() async => throw error);
        } catch (caught) {
          expect(caught, same(error));
          LoadTiming.failure();
        }
        await LoadTiming.http(() async => 7);
      }, sink: lines.add);
      expect(lines.last, contains('requests=2'));
      expect(lines.last, contains('http_errors=1'));
      expect(lines.last, contains('status=interrupted'));
      expect(lines.join(), isNot(contains('secret')));
      expect(lines.join(), isNot(contains('/v1')));
      expect(lines.join(), isNot(contains('UUID')));
    },
  );

  test(
    'HTTP failure class and status are safe and preserve original errors',
    () async {
      for (final type in [
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.badResponse,
        DioExceptionType.cancel,
      ]) {
        final lines = <String>[];
        final options = RequestOptions(
          path: '/private/secret-UUID',
          headers: {'Authorization': 'Bearer secret'},
        );
        final error = DioException(
          requestOptions: options,
          type: type,
          message: 'secret error body',
          response: type == DioExceptionType.badResponse
              ? Response(
                  requestOptions: options,
                  statusCode: 503,
                  data: 'secret',
                )
              : null,
        );
        await expectLater(
          LoadTiming.run<void>(
            LoadStage.activeRestore,
            () => LoadTiming.http<void>(() async => throw error),
            sink: lines.add,
          ),
          throwsA(same(error)),
        );
        final line = lines.singleWhere((s) => s.contains('event=http_error'));
        expect(
          line,
          contains(
            'http_status=${type == DioExceptionType.badResponse ? 503 : 0}',
          ),
        );
        expect(
          line,
          contains(
            'category=${switch (type) {
              DioExceptionType.receiveTimeout => 'timeout',
              DioExceptionType.connectionError => 'connection',
              DioExceptionType.cancel => 'cancelled',
              _ => 'http_response',
            }}',
          ),
        );
        expect(lines.join(), isNot(contains('secret')));
        expect(lines.join(), isNot(contains('UUID')));
      }
    },
  );

  test('broken diagnostic sink cannot replace results or exceptions', () async {
    void broken(String _) => throw StateError('log failure');
    expect(
      await LoadTiming.run(LoadStage.cycle, () async => 42, sink: broken),
      42,
    );
    final error = StateError('operation failure');
    await expectLater(
      LoadTiming.run<void>(
        LoadStage.cycle,
        () async => throw error,
        sink: broken,
      ),
      throwsA(same(error)),
    );
  });
}
