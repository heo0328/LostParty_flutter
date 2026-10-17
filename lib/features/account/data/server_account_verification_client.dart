import '../domain/account_read_session.dart';
import '../domain/server_account_verification.dart';
import '../domain/server_registration_api.dart';

/// Uses the existing authenticated transport. No polling, persistence or binding.
class ServerAccountVerificationClient {
  const ServerAccountVerificationClient(this.api, this.session);

  final BackendRegistrationApi api;
  final AccountReadSession session;

  Future<ServerAccountVerification> load(String challengeId) async {
    final scope = accountReadScope(session);
    final id = verificationUuid(challengeId);
    final json = await _request(
      scope,
      '${ServerVerificationCommand.basePath}/$id',
    );
    requireAccountReadScope(session, scope);
    return _decode(json, challengeId: id);
  }

  /// Null is returned only for a successful, bodyless DELETE response.
  Future<ServerAccountVerification?> execute(
    ServerVerificationCommand command,
  ) async {
    final json = await _request(
      command.scope,
      command.path,
      method: command.method,
      body: command.body,
      key: command.idempotencyKey,
      expectedStatus: command.expectedStatus,
    );
    requireAccountReadScope(session, command.scope);
    if (command.expectedStatus == 204) {
      if (json != null) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
      return null;
    }
    return _decode(
      json,
      challengeId: command.challengeId,
      registrationId: command.registrationId,
    );
  }

  Future<Map<String, dynamic>?> _request(
    AccountReadScope scope,
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? key,
    int expectedStatus = 200,
  }) async {
    requireAccountReadScope(session, scope);
    try {
      final result = await api.request(
        path,
        method: method,
        body: body,
        idempotencyKey: key,
        expectedStatus: expectedStatus,
      );
      requireAccountReadScope(session, scope);
      return result;
    } on Object {
      requireAccountReadScope(session, scope);
      rethrow;
    }
  }

  ServerAccountVerification _decode(
    Map<String, dynamic>? json, {
    String? challengeId,
    String? registrationId,
  }) {
    try {
      if (json == null) throw const FormatException('Missing verification.');
      final result = ServerAccountVerification.fromJson(json);
      if ((challengeId != null && result.challengeId != challengeId) ||
          (registrationId != null && result.registrationId != registrationId)) {
        throw const FormatException('Verification target changed.');
      }
      return result;
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }
}
