import '../../../account/domain/server_registration_api.dart';
import 'beta_contract.dart';

/// Contract boundary for existing participation readers and commands.
/// The repository instance fixes the profile for the lifetime of its requests.
class BetaInteractionApi implements BackendRegistrationApi {
  BetaInteractionApi(this.delegate);
  final BackendRegistrationApi delegate;
  static const contract = BetaContract(mode: RecruitmentContractMode.betaWire2);

  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) async {
    // Account/catalog APIs outside the pinned recruitment contract stay intact.
    if (!path.startsWith('/v2/')) {
      return delegate.request(
        path,
        method: method,
        body: body,
        query: query,
        idempotencyKey: idempotencyKey,
        expectedStatus: expectedStatus,
      );
    }
    final q = contract.query(method, path, query ?? const {});
    contract.validateRequest(method, path, q, body);
    final raw = await delegate.request(
      path,
      method: method,
      body: body,
      query: q.isEmpty ? null : q,
      idempotencyKey: idempotencyKey,
      expectedStatus: expectedStatus,
    );
    return BetaResponse.parse(
      method: method,
      path: path,
      status: expectedStatus,
      json: raw!,
      parseLegacy: (value) => value,
    ).value;
  }
}
