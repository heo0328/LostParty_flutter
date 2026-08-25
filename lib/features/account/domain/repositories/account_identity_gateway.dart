import '../entities/local_game_account.dart';
import '../entities/server_account_identity_binding.dart';

abstract interface class AccountIdentityGateway {
  Future<ServerAccountIdentityBinding> getOrCreateIdentity(
    LocalGameAccount account,
  );
}

abstract interface class AccountIdentityMappingRepository {
  Future<void> bindServerIdentity(ServerAccountIdentityBinding binding);
}
