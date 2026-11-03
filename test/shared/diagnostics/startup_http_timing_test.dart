import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/diagnostics/startup_http_timing.dart';
import 'package:lost_party/shared/diagnostics/startup_timing.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions, Future<void>?) respond;
  int calls = 0;
  bool? forced;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    return respond(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    forced = force;
  }
}

class Decoder extends Transformer {
  final delegate = BackgroundTransformer();
  int responses = 0, requests = 0;
  @override
  Future<String> transformRequest(RequestOptions options) {
    requests++;
    return delegate.transformRequest(options);
  }

  @override
  Future<dynamic> transformResponse(RequestOptions options, ResponseBody body) {
    responses++;
    return delegate.transformResponse(options, body);
  }
}

void main() {
  late StartupTrace trace;
  late List<String> lines;
  late Dio dio;
  setUp(() {
    lines = [];
    trace = StartupTrace(sink: lines.add);
    StartupTiming.testTrace = trace;
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'));
  });
  tearDown(() {
    dio.close(force: true);
    trace.finish(StartupResult.interrupted);
    StartupTiming.testTrace = null;
  });

  test(
    'off leaves existing client components, response and request count intact',
    () async {
      StartupTiming.testTrace = null;
      final adapter = Adapter(
        (_, _) async => ResponseBody.fromString(
          '{"ok":true}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      dio.httpClientAdapter = adapter;
      final transformer = dio.transformer;
      final interceptors = dio.interceptors.length;
      StartupHttpTiming.attach(dio, lostArk: false);
      expect(dio.httpClientAdapter, same(adapter));
      expect(dio.transformer, same(transformer));
      expect(dio.interceptors, hasLength(interceptors));
      expect((await dio.get('/v1/me')).data, {'ok': true});
      expect(adapter.calls, 1);
      expect(lines, hasLength(1));
    },
  );

  test(
    'delegates large JSON once, preserving decoder, data and byte counts',
    () async {
      final text = jsonEncode({'private': List.filled(60000, 'x').join()});
      final bytes = Uint8List.fromList(utf8.encode(text));
      var listens = 0;
      final body = ResponseBody(
        Stream<Uint8List>.multi((controller) {
          listens++;
          controller.add(bytes);
          controller.close();
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
      final adapter = Adapter((_, _) async => body);
      final decoder = Decoder();
      dio.httpClientAdapter = adapter;
      dio.transformer = decoder;
      StartupHttpTiming.attach(dio, lostArk: false);
      final response = await dio.post(
        '/v1/me/private-name',
        data: {'secret': 'token'},
      );
      expect(response.data, jsonDecode(text));
      expect(listens, 1);
      expect(decoder.responses, 1);
      expect(decoder.requests, 1);
      expect(adapter.calls, 1);
      expect(lines.last, contains('bytes=${bytes.length}'));
      expect(lines.last, isNot(contains('post_body_us=-1')));
      for (final secret in [
        'private-name',
        'token',
        'secret',
        '127.0.0.1',
        text,
      ]) {
        expect(lines.join(), isNot(contains(secret)));
      }
      dio.close(force: true);
      expect(adapter.forced, isTrue);
    },
  );

  test(
    'parallel attempts and later retry have distinct IDs and correct parents',
    () async {
      final one = Completer<ResponseBody>(), two = Completer<ResponseBody>();
      var attempts = 0;
      final adapter = Adapter((options, _) {
        if (++attempts > 2) {
          return Future.value(ResponseBody.fromString('one', 200));
        }
        return options.path.endsWith('one') ? one.future : two.future;
      });
      dio.httpClientAdapter = adapter;
      StartupHttpTiming.attach(dio, lostArk: true);
      final first = StartupTiming.run(
        StartupWork.character,
        () => dio.get('/armories/characters/one'),
      );
      final second = StartupTiming.run(
        StartupWork.character,
        () => dio.get('/armories/characters/two'),
      );
      await Future<void>.delayed(Duration.zero);
      two.complete(ResponseBody.fromString('two', 200));
      one.complete(ResponseBody.fromString('one', 200));
      expect((await Future.wait([first, second])).map((r) => r.data), [
        'one',
        'two',
      ]);
      await dio.get('/armories/characters/one');
      final starts = lines
          .where((l) => l.contains('request=') && l.contains('event=start'))
          .toList();
      expect(starts, hasLength(3));
      expect(starts[0], contains('request=1 parent=1 '));
      expect(starts[1], contains('request=2 parent=2 '));
      expect(starts[2], contains('request=3 parent=0 '));
      expect(adapter.calls, 3);
    },
  );

  test(
    'response byte stream preserves chunks, errors and cancellation',
    () async {
      final source = StreamController<Uint8List>();
      var cancelled = false;
      source.onCancel = () {
        cancelled = true;
      };
      final adapter = Adapter((_, _) async => ResponseBody(source.stream, 200));
      dio.httpClientAdapter = adapter;
      StartupHttpTiming.attach(dio, lostArk: false);
      final response = await dio.get<ResponseBody>(
        '/stream',
        options: Options(responseType: ResponseType.stream),
      );
      final received = <Uint8List>[];
      final errors = <Object>[];
      final a = Uint8List.fromList([1, 2]), b = Uint8List.fromList([3]);
      final error = StateError('private stream error');
      final subscription = response.data!.stream.listen(
        received.add,
        onError: (Object e) => errors.add(e),
      );
      source.add(a);
      source.add(b);
      source.addError(error);
      await Future<void>.delayed(Duration.zero);
      expect(received[0], same(a));
      expect(received[1], same(b));
      expect(errors.single, same(error));
      await subscription.cancel();
      expect(cancelled, isTrue);
      await source.close();
      expect(adapter.calls, 1);
    },
  );

  test(
    'passes cancelFuture and preserves cancellation category without secrets',
    () async {
      final started = Completer<void>();
      final adapter = Adapter((options, cancel) async {
        started.complete();
        await cancel;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: 'private-error',
        );
      });
      dio.httpClientAdapter = adapter;
      StartupHttpTiming.attach(dio, lostArk: false);
      final token = CancelToken();
      final response = dio.get('/private', cancelToken: token);
      await started.future;
      token.cancel('secret');
      await expectLater(
        response,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(adapter.calls, 1);
      expect(lines.any((l) => l.contains('result=cancel')), isTrue);
      expect(lines.join(), isNot(contains('secret')));
    },
  );

  test('HTTP failure and decoder exception remain failures', () async {
    var attempt = 0;
    final adapter = Adapter(
      (_, _) async => ++attempt == 1
          ? ResponseBody.fromString(
              '{"error":"private"}',
              503,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            )
          : ResponseBody.fromString(
              '{broken',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            ),
    );
    dio.httpClientAdapter = adapter;
    StartupHttpTiming.attach(dio, lostArk: false);
    await expectLater(
      dio.get('/v1/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          503,
        ),
      ),
    );
    await expectLater(
      dio.get('/v1/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'error',
          isA<FormatException>(),
        ),
      ),
    );
    expect(adapter.calls, 2);
    expect(
      lines.where((l) => l.contains('request=') && l.contains('event=end')),
      hasLength(2),
    );
    expect(lines.join(), isNot(contains('private')));
  });
}
