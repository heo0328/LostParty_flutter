import '../domain/account_read_session.dart';
import '../domain/play_availability.dart';
import '../domain/server_registration_api.dart';

class BackendPlayAvailabilityRepository implements PlayAvailabilityRepository {
  const BackendPlayAvailabilityRepository(this.api);
  final BackendRegistrationApi api;
  static const path = '/v1/me/play-availability';

  Future<PlayAvailability> _decode(
    Future<Map<String, dynamic>?> Function() request,
  ) async {
    try {
      return PlayAvailability.fromJson((await request())!);
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  @override
  Future<PlayAvailability> load() => _decode(() => api.request(path));
  @override
  Future<PlayAvailability> save({
    required int version,
    required List<PlayTimeRow> rows,
    required String key,
  }) {
    final body = <String, dynamic>{
      'expected_version': version,
      'timezone': 'Asia/Seoul',
      'intervals': rows.map((r) => r.toJson()).toList(growable: false),
    };
    return _decode(
      () => api.request(path, method: 'PUT', body: body, idempotencyKey: key),
    );
  }
}
