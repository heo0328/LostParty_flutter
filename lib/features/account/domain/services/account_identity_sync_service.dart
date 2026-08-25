import '../entities/local_game_account.dart';
import '../entities/server_account_identity_binding.dart';
import '../repositories/account_identity_gateway.dart';

class AccountIdentitySyncService {
  const AccountIdentitySyncService({
    required AccountIdentityGateway gateway,
    required AccountIdentityMappingRepository mappingRepository,
  }) : _gateway = gateway,
       _mappingRepository = mappingRepository;

  final AccountIdentityGateway _gateway;
  final AccountIdentityMappingRepository _mappingRepository;

  Future<ServerAccountIdentityBinding> synchronize(
    LocalGameAccount account,
  ) async {
    final binding = await _gateway.getOrCreateIdentity(account);
    _validateCompleteResponse(account: account, binding: binding);
    await _mappingRepository.bindServerIdentity(binding);
    return binding;
  }

  static void _validateCompleteResponse({
    required LocalGameAccount account,
    required ServerAccountIdentityBinding binding,
  }) {
    if (binding.localAccountId != account.id) {
      throw StateError(
        'Server identity response targets another local account.',
      );
    }
    final requestedCharacterIds = account.characters
        .map((character) => character.id)
        .toSet();
    final returnedCharacterIds = binding.serverCharacterIdsByLocalId.keys
        .toSet();
    if (requestedCharacterIds.length != returnedCharacterIds.length ||
        !requestedCharacterIds.containsAll(returnedCharacterIds)) {
      throw StateError(
        'Server identity response must contain every requested character once.',
      );
    }
  }
}
