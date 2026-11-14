import '../domain/account_read_session.dart';
import '../domain/personal_reservations.dart';
import 'backend_account_read_api.dart';
import 'member_raid_client.dart';

abstract interface class PersonalReservationsRepository {
  Future<DateTime> serverTime();
  Future<ReservationPage> page(String key, {String? cursor});
}

class BackendPersonalReservationsRepository
    implements PersonalReservationsRepository {
  const BackendPersonalReservationsRepository(this.api);
  final DioBackendAccountReadApi api;
  @override
  Future<DateTime> serverTime() async =>
      (await MemberRaidClient(api).cycles()).serverNow;
  @override
  Future<ReservationPage> page(String key, {String? cursor}) async {
    try {
      return ReservationPage.fromJson(
        (await api.request(
          '/v2/me/raid-reservations',
          query: {'calendar_week_key': key, 'limit': 100, 'cursor': ?cursor},
        ))!,
        key: key,
      );
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }
}
