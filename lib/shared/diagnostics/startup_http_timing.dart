import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'startup_timing.dart';

/// Decorates the existing client. No alternate decoder, buffering or retries.
class StartupHttpTiming {
  static final _requests = Expando<_RequestTiming>();

  static void attach(Dio dio, {required bool lostArk}) {
    if (StartupTiming.active == null || dio.httpClientAdapter is _Adapter) {
      return;
    }
    dio.httpClientAdapter = _Adapter(dio.httpClientAdapter);
    dio.transformer = _Transformer(dio.transformer);
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final trace = StartupTiming.active;
          if (trace != null) {
            final host = options.uri.host;
            final target = lostArk
                ? 'lostark'
                : (host == '127.0.0.1' ||
                      host == 'localhost' ||
                      host == '10.0.2.2')
                ? 'backend_local'
                : 'backend_other';
            final request = _RequestTiming(
              trace,
              target,
              _operation(options, lostArk),
            );
            _requests[options] = request;
            request.emit('start');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          _requests[response.requestOptions]?.end(response.statusCode, 'ok');
          handler.next(response);
        },
        onError: (error, handler) {
          _requests[error.requestOptions]?.end(
            error.response?.statusCode,
            error.type.name,
          );
          handler.next(error);
        },
      ),
    );
  }

  // Only fixed operation labels leave this function, even for unknown routes.
  static String _operation(RequestOptions options, bool lostArk) {
    final path = options.uri.path;
    if (lostArk) {
      if (path.startsWith('/armories/characters/')) return 'armory';
      if (path.startsWith('/characters/')) return 'roster';
      return 'lostark_other';
    }
    if (path == '/v1/me') return 'me';
    if (path == '/v1/auth/refresh') return 'auth_refresh';
    if (path.startsWith('/v1/auth/')) return 'auth_other';
    if (path.contains('bootstrap')) return 'bootstrap';
    if (path == '/v2/me/role-summary-batches') return 'role_batch';
    if (path == '/v2/me/characters/personal-profiles') return 'profile_batch';
    if (path.endsWith('/refresh')) return 'refresh';
    if (path.contains('weekly')) return 'weekly';
    if (path.contains('combat-power')) return 'combat_power';
    if (path.contains('role-build') || path.contains('role-summaries')) {
      return 'role_build';
    }
    if (path.contains('personal')) return 'personal';
    if (path.contains('lostark') || path.contains('lost-ark')) return 'key';
    if (path.contains('settings')) return 'settings';
    if (path.contains('representative')) return 'representative';
    if (path.endsWith('/characters')) return 'characters';
    if (path == '/v1/me/game-accounts') return 'registrations';
    return 'backend_other';
  }
}

class _RequestTiming {
  _RequestTiming(this.trace, this.target, this.operation)
    : id = trace.nextRequest(),
      parent = trace.parent,
      start = trace.micros;
  final StartupTrace trace;
  final String target, operation;
  final int id, parent, start;
  int? headersAt, bodyAt, transformedAt;
  int bytes = 0;
  bool ended = false;
  void emit(String event, {int? status, String result = 'ok'}) {
    trace.write(
      'request=$id parent=$parent target=$target op=$operation event=$event '
      'duration_us=${trace.micros - start} headers_us=${headersAt == null ? -1 : headersAt! - start} '
      'body_us=${bodyAt == null ? -1 : bodyAt! - start} '
      'post_body_us=${bodyAt == null || transformedAt == null ? -1 : transformedAt! - bodyAt!} '
      'bytes=$bytes status=${status != null && status >= 100 && status <= 599 ? status : 0} result=$result',
    );
  }

  void end(int? status, String result) {
    if (ended) return;
    ended = true;
    emit('end', status: status, result: result);
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.delegate);
  final HttpClientAdapter delegate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    final body = await delegate.fetch(options, stream, cancelFuture);
    final timing = StartupHttpTiming._requests[options];
    if (timing != null && timing.trace.active) {
      timing.headersAt = timing.trace.micros;
      body.stream = body.stream.transform(
        StreamTransformer.fromHandlers(
          handleData: (Uint8List data, EventSink<Uint8List> sink) {
            timing.bytes += data.length;
            sink.add(data);
          },
          handleDone: (sink) {
            timing.bodyAt = timing.trace.micros;
            sink.close();
          },
        ),
      );
    }
    return body;
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}

class _Transformer extends Transformer {
  _Transformer(this.delegate);
  final Transformer delegate;
  @override
  Future<String> transformRequest(RequestOptions options) =>
      delegate.transformRequest(options);
  @override
  Future<dynamic> transformResponse(
    RequestOptions options,
    ResponseBody responseBody,
  ) async {
    try {
      return await delegate.transformResponse(options, responseBody);
    } finally {
      final timing = StartupHttpTiming._requests[options];
      if (timing != null) timing.transformedAt = timing.trace.micros;
    }
  }
}
