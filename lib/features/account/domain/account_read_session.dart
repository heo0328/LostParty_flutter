import 'package:flutter/foundation.dart';

import '../../auth/domain/auth_session_controller.dart';
import '../../auth/domain/backend_auth_models.dart';

typedef AccountReadScope = ({String userId, int generation});

class AccountReadException implements Exception {
  const AccountReadException(
    this.code, {
    this.status,
    this.requestId,
    this.retryAfter,
    this.retryAt,
  });
  final String code;
  final int? status;
  final String? requestId;
  final Duration? retryAfter;
  final DateTime? retryAt;
  @override
  String toString() => 'AccountReadException($code)';
}

abstract interface class AccountReadSession implements Listenable {
  bool get isAuthenticated;
  String? get userId;
  int get generation;
  Future<String> accessToken();
  Future<void> refresh();
  Future<void> reject(int generation, AuthApiException error);
}

class AuthAccountReadSession implements AccountReadSession {
  const AuthAccountReadSession(this.auth);
  final AuthSessionController auth;
  @override
  bool get isAuthenticated => auth.isAuthenticated;
  @override
  String? get userId => auth.userId;
  @override
  int get generation => auth.sessionGeneration;
  @override
  Future<String> accessToken() => auth.accessToken();
  @override
  Future<void> refresh() => auth.refresh();
  @override
  Future<void> reject(int generation, AuthApiException error) =>
      auth.rejectSessionResponse(generation, error);
  @override
  void addListener(VoidCallback listener) => auth.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => auth.removeListener(listener);
}

AccountReadScope accountReadScope(AccountReadSession session) {
  final id = session.userId;
  if (!session.isAuthenticated || id == null) {
    throw const AccountReadException('LOGIN_REQUIRED');
  }
  return (userId: id, generation: session.generation);
}

void requireAccountReadScope(
  AccountReadSession session,
  AccountReadScope scope,
) {
  if (!session.isAuthenticated ||
      session.userId != scope.userId ||
      session.generation != scope.generation) {
    throw const AccountReadException('SESSION_CHANGED');
  }
}
