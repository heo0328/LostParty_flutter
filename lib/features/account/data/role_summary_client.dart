import '../../../shared/diagnostics/startup_timing.dart';

import '../domain/account_read_session.dart';
import '../domain/role_summary.dart';
import '../domain/scoped_cache_models.dart';
import 'backend_account_read_api.dart';

/// P1 role wire with P2 personal-profile preferences. Explicit calls only.
class RoleSummaryClient {
  RoleSummaryClient(this.api) : baseUrl = api.dio.options.baseUrl;
  final DioBackendAccountReadApi api;
  final String baseUrl;

  void requireScope(ScopedCharacterRef ref, AccountReadScope captured) {
    requireStorageScope(ref.scope, captured);
  }

  void requireStorageScope(StorageScope scope, AccountReadScope captured) {
    requireAccountReadScope(api.session, captured);
    if (api.dio.options.baseUrl != baseUrl ||
        scope !=
            StorageScope(
              baseUrl: baseUrl,
              userId: captured.userId,
              allowHttp: true,
            )) {
      throw const AccountReadException('ENVIRONMENT_CHANGED');
    }
  }

  Future<T> _decode<T>(
    ScopedCharacterRef ref,
    Future<T> Function() action,
  ) async {
    final captured = accountReadScope(api.session);
    requireScope(ref, captured);
    try {
      final result = await action();
      requireScope(ref, captured);
      return result;
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  Future<PersonalProfile> get(ScopedCharacterRef ref) => _decode(ref, () async {
    final json = (await api.request(
      '/v2/me/characters/${ref.characterId}/personal-profile',
    ))!;
    final value = StartupTiming.sync(
      StartupWork.dto,
      () => PersonalProfile.fromJson(json),
    );
    roleCheck(
      value.characterId == ref.characterId && value.accountId == ref.accountId,
    );
    return value;
  });
}
