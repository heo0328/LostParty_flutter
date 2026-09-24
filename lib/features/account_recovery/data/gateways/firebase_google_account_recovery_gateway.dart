import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../repositories/account_recovery_repository_impl.dart';

class FirebaseGoogleAccountRecoveryGateway implements AccountRecoveryGateway {
  FirebaseGoogleAccountRecoveryGateway({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

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
      await (_googleInitialization ??= _googleSignIn.initialize());
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AccountRecoveryGatewayException('missing-id-token');
      }

      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        throw const AccountRecoveryGatewayException('no-current-user');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await currentUser.linkWithCredential(credential);
      return result.user?.uid;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw AccountRecoveryGatewayException(error.code.name);
    } on FirebaseAuthException catch (error) {
      throw AccountRecoveryGatewayException(error.code);
    }
  }
}
