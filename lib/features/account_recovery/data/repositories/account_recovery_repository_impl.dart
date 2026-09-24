import '../../domain/entities/account_recovery_status.dart';
import '../../domain/repositories/account_recovery_repository.dart';

const googleAuthProviderId = 'google.com';

class AccountRecoveryIdentity {
  const AccountRecoveryIdentity({required this.uid, required this.providerIds});

  final String uid;
  final Set<String> providerIds;
}

class AccountRecoveryGatewayException implements Exception {
  const AccountRecoveryGatewayException(this.code);

  final String code;
}

abstract class AccountRecoveryGateway {
  AccountRecoveryIdentity? get currentIdentity;

  /// Returns the linked user's UID, or null when the user cancelled.
  Future<String?> linkGoogle();
}

class AccountRecoveryRepositoryImpl implements AccountRecoveryRepository {
  const AccountRecoveryRepositoryImpl(this._gateway);

  final AccountRecoveryGateway _gateway;

  @override
  Future<AccountRecoveryStatus> loadStatus() async {
    final identity = _gateway.currentIdentity;
    if (identity == null) {
      throw const AccountRecoveryException(
        AccountRecoveryFailureReason.noAuthenticatedUser,
      );
    }
    return AccountRecoveryStatus(
      isGoogleLinked: identity.providerIds.contains(googleAuthProviderId),
    );
  }

  @override
  Future<AccountRecoveryLinkResult> linkGoogle() async {
    final before = _gateway.currentIdentity;
    if (before == null) {
      throw const AccountRecoveryException(
        AccountRecoveryFailureReason.noAuthenticatedUser,
      );
    }
    if (before.providerIds.contains(googleAuthProviderId)) {
      return AccountRecoveryLinkResult.alreadyLinked;
    }

    final String? linkedUid;
    try {
      linkedUid = await _gateway.linkGoogle();
    } on AccountRecoveryGatewayException catch (error) {
      throw AccountRecoveryException(_mapFailure(error.code));
    }
    if (linkedUid == null) return AccountRecoveryLinkResult.cancelled;

    final after = _gateway.currentIdentity;
    if (linkedUid != before.uid ||
        after?.uid != before.uid ||
        after?.providerIds.contains(googleAuthProviderId) != true) {
      throw const AccountRecoveryException(
        AccountRecoveryFailureReason.uidChanged,
      );
    }
    return AccountRecoveryLinkResult.linked;
  }

  AccountRecoveryFailureReason _mapFailure(String code) => switch (code) {
    'credential-already-in-use' || 'account-exists-with-different-credential' =>
      AccountRecoveryFailureReason.credentialAlreadyInUse,
    'operation-not-allowed' ||
    'clientConfigurationError' ||
    'providerConfigurationError' =>
      AccountRecoveryFailureReason.providerNotEnabled,
    'invalid-credential' ||
    'missing-id-token' => AccountRecoveryFailureReason.invalidCredential,
    'network-request-failed' ||
    'network-error' => AccountRecoveryFailureReason.network,
    'too-many-requests' => AccountRecoveryFailureReason.tooManyRequests,
    _ => AccountRecoveryFailureReason.unknown,
  };
}
