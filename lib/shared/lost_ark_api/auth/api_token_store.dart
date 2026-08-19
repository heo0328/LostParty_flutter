import 'api_token.dart';

abstract interface class ApiTokenStore {
  Future<ApiToken?> read();

  Future<void> write(ApiToken token);

  Future<void> delete();
}
