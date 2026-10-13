import 'backend_auth_models.dart';

abstract interface class BackendAuthApi {
  Future<AuthChallenge> challenge(String secretHash);
  Future<AuthLogin> login({
    required String transactionId,
    required String secret,
    required String proof,
    required bool remember,
  });
  Future<AuthTokens> refresh(String token, String requestId);
  Future<AuthUser> me(String access);
  Future<AuthSession> session(String access);
  Future<void> logout(String refresh);
}

abstract interface class AuthSessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}
