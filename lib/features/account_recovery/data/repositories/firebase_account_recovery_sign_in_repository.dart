import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/account_recovery_status.dart';
import '../../domain/repositories/account_recovery_sign_in_repository.dart';
import '../gateways/google_recovery_credential_provider.dart';
import 'account_recovery_repository_impl.dart';

class FirebaseAccountRecoverySignInRepository
    implements AccountRecoverySignInRepository {
  FirebaseAccountRecoverySignInRepository({
    FirebaseAuth? firebaseAuth,
    GoogleRecoveryCredentialProvider? credentialProvider,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _credentialProvider =
           credentialProvider ?? GoogleRecoveryCredentialProvider.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleRecoveryCredentialProvider _credentialProvider;

  @override
  Future<AccountRecoverySignInResult> signInWithGoogle() async {
    if (_firebaseAuth.currentUser != null) {
      throw const AccountRecoveryException(
        AccountRecoveryFailureReason.unknown,
      );
    }

    try {
      final credential = await _credentialProvider.requestCredential();
      if (credential == null) return const AccountRecoverySignInCancelled();
      final result = await _firebaseAuth.signInWithCredential(credential);
      final user = result.user;
      if (user == null ||
          !user.providerData.any(
            (provider) => provider.providerId == googleAuthProviderId,
          )) {
        throw const AccountRecoveryException(
          AccountRecoveryFailureReason.invalidCredential,
        );
      }
      return AccountRecoverySignInRecovered(
        isNewUser: result.additionalUserInfo?.isNewUser == true,
      );
    } on AccountRecoveryGatewayException catch (error) {
      throw AccountRecoveryException(_mapFailure(error.code));
    } on FirebaseAuthException catch (error) {
      throw AccountRecoveryException(_mapFailure(error.code));
    } finally {
      await _credentialProvider.clearLocalSession();
    }
  }

  AccountRecoveryFailureReason _mapFailure(String code) => switch (code) {
    'operation-not-allowed' ||
    'clientConfigurationError' ||
    'providerConfigurationError' =>
      AccountRecoveryFailureReason.providerNotEnabled,
    'invalid-credential' ||
    'missing-id-token' ||
    'user-disabled' => AccountRecoveryFailureReason.invalidCredential,
    'network-request-failed' ||
    'network-error' => AccountRecoveryFailureReason.network,
    'too-many-requests' => AccountRecoveryFailureReason.tooManyRequests,
    _ => AccountRecoveryFailureReason.unknown,
  };
}
