import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/account_recovery_repository_impl.dart';
import 'google_recovery_credential_provider.dart';

class FirebaseGoogleAccountRecoveryGateway implements AccountRecoveryGateway {
  FirebaseGoogleAccountRecoveryGateway({
    FirebaseAuth? firebaseAuth,
    GoogleRecoveryCredentialProvider? credentialProvider,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _credentialProvider =
           credentialProvider ?? GoogleRecoveryCredentialProvider.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleRecoveryCredentialProvider _credentialProvider;

  @override
  AccountRecoveryIdentity? get currentIdentity {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return AccountRecoveryIdentity(
      uid: user.uid,
      providerIds: user.providerData
          .map((provider) => provider.providerId)
          .toSet(),
    );
  }

  @override
  Future<String?> linkGoogle() async {
    try {
      final credential = await _credentialProvider.requestCredential();
      if (credential == null) return null;

      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        throw const AccountRecoveryGatewayException('no-current-user');
      }
      final result = await currentUser.linkWithCredential(credential);
      return result.user?.uid;
    } on AccountRecoveryGatewayException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AccountRecoveryGatewayException(error.code);
    } finally {
      await _credentialProvider.clearLocalSession();
    }
  }
}
