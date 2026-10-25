import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../account/domain/account_read_session.dart';
import '../../../account/domain/scoped_cache_models.dart';
import 'beta_contract.dart';
import 'recruitment_command.dart';
import 'recruitment_command_store.dart';

typedef RecruitmentCommandSender =
    Future<Map<String, dynamic>> Function(
      RecruitmentCommand command,
      AccountReadScope sessionScope,
    );

/// Raw body transport: no decode/encode cycle and no persisted Bearer token.
class DioRecruitmentCommandSender {
  const DioRecruitmentCommandSender(this.dio, this.session);
  final Dio dio;
  final AccountReadSession session;
  Future<Map<String, dynamic>> call(
    RecruitmentCommand command,
    AccountReadScope binding,
  ) async {
    final environment = dio.options.baseUrl;
    final token = await session.accessToken();
    requireAccountReadScope(session, binding);
    if (dio.options.baseUrl != environment) {
      throw const AccountReadException('ENVIRONMENT_CHANGED');
    }
    final response = await dio.request<Object?>(
      command.path,
      data: command.rawBody,
      queryParameters: command.query,
      options: Options(
        method: command.method,
        followRedirects: false,
        contentType: Headers.jsonContentType,
        headers: {
          'Authorization': 'Bearer $token',
          'Idempotency-Key': command.key,
        },
      ),
    );
    requireAccountReadScope(session, binding);
    if (response.statusCode != command.expectedStatus ||
        response.data is! Map<String, dynamic>) {
      throw const AccountReadException('INVALID_RESPONSE');
    }
    return response.data! as Map<String, dynamic>;
  }
}

/// App-owned journal/transport. Controllers keep UI state and mutation refreshes.
/// Restore is read-only with respect to the network; sending is always explicit.
class RecruitmentCommandTransport {
  RecruitmentCommandTransport({
    required this.store,
    required this.session,
    required this.baseUrl,
    required this.send,
    this.allowHttp = false,
    this.mode = RecruitmentContractMode.legacy,
    DateTime Function()? clock,
  }) : clock = clock ?? (() => DateTime.now().toUtc()) {
    _sessionIdentity = (
      session.isAuthenticated,
      session.userId,
      session.generation,
    );
    session.addListener(_sessionChanged);
  }
  final RecruitmentCommandStore store;
  final AccountReadSession session;
  final String Function() baseUrl;
  final RecruitmentCommandSender send;
  final DateTime Function() clock;
  final RecruitmentContractMode mode;
  final bool allowHttp;
  final Set<(StorageScope, RecruitmentCommandOwner)> _busy = {};
  // A validated ACK whose disk write failed must not trigger another HTTP in this runtime.
  final Map<(StorageScope, String), String> _validated = {};
  bool _disposed = false;
  late (bool, String?, int) _sessionIdentity;
  void _sessionChanged() {
    final current = (
      session.isAuthenticated,
      session.userId,
      session.generation,
    );
    if (current != _sessionIdentity) {
      _sessionIdentity = current;
      _validated.clear();
    }
  }

  StorageScope _scope(AccountReadScope binding) => StorageScope(
    baseUrl: baseUrl(),
    userId: binding.userId,
    allowHttp: allowHttp,
  );
  void _current(AccountReadScope binding, StorageScope scope) {
    if (_disposed) throw const AccountReadException('DISPOSED');
    requireAccountReadScope(session, binding);
    if (_scope(binding) != scope) {
      throw const AccountReadException('ENVIRONMENT_CHANGED');
    }
  }

  Future<RecruitmentCommand?> restore(RecruitmentCommandOwner owner) async {
    final binding = accountReadScope(session),
        scope = _scope(accountReadScope(session));
    _current(binding, scope);
    var command = await store.read(scope, owner);
    _current(binding, scope);
    if (command?.state == RecruitmentCommandState.pending &&
        command!.expired(clock())) {
      command = command.transition(state: RecruitmentCommandState.needsReview);
      await store.replace(scope, command);
      _current(binding, scope);
    }
    return command;
  }

  /// Returns only after the validated success has been durably acknowledged.
  /// Caller performs UI refresh afterwards; a failed refresh never calls submit again.
  Future<Map<String, dynamic>> submit(
    RecruitmentCommand command, {
    required void Function(Map<String, dynamic>) validateAck,
  }) async {
    final binding = accountReadScope(session),
        scope = _scope(accountReadScope(session));
    _current(binding, scope);
    if (command.contractMode != mode) {
      throw const AccountReadException('CONTRACT_MODE_MISMATCH');
    }
    final slot = (scope, command.owner);
    if (!_busy.add(slot)) {
      throw const AccountReadException('REQUEST_IN_PROGRESS');
    }
    try {
      var saved = await store.read(scope, command.owner);
      _current(binding, scope);
      if (saved == null) {
        await store.insert(scope, command);
        saved = command;
        _current(binding, scope);
      } else if (!saved.sameOriginal(command)) {
        throw const AccountReadException('UNRESOLVED_REQUEST_EXISTS');
      }
      if (saved.state == RecruitmentCommandState.acknowledged) {
        final ack = jsonDecode(saved.rawAck!) as Map<String, dynamic>;
        validateAck(ack);
        return betaFreeze(ack) as Map<String, dynamic>;
      }
      final ackKey = (scope, saved.key);
      var raw = _validated[ackKey];
      if (raw == null) {
        if (saved.state == RecruitmentCommandState.needsReview ||
            saved.expired(clock())) {
          await store.replace(
            scope,
            saved.transition(state: RecruitmentCommandState.needsReview),
          );
          throw const AccountReadException('REQUEST_REVIEW_REQUIRED');
        }
        saved = saved.transition(attemptedAt: clock());
        await store.replace(scope, saved);
        _current(binding, scope);
        final ack = await send(saved, binding);
        _current(binding, scope);
        if (mode == RecruitmentContractMode.betaWire2) {
          const BetaContract(
            mode: RecruitmentContractMode.betaWire2,
          ).validateResponse(
            saved.method,
            saved.path,
            saved.expectedStatus,
            ack,
          );
        }
        validateAck(ack);
        raw = jsonEncode(ack);
        _validated[ackKey] = raw;
      }
      await store.replace(
        scope,
        saved.transition(
          state: RecruitmentCommandState.acknowledged,
          rawAck: raw,
        ),
      );
      _current(binding, scope);
      _validated.remove(ackKey);
      return betaFreeze(jsonDecode(raw)) as Map<String, dynamic>;
    } finally {
      _busy.remove(slot);
    }
  }

  /// Called after the owning controller has consumed success, never after an unknown result.
  Future<void> releaseAcknowledged(
    RecruitmentCommandOwner owner,
    String key,
  ) async {
    final binding = accountReadScope(session),
        scope = _scope(accountReadScope(session));
    _current(binding, scope);
    await store.releaseAcknowledged(scope, owner, key);
    _current(binding, scope);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_sessionChanged);
    _validated.clear();
    await store.close();
  }
}
