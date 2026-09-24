import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../repositories/account_recovery_repository_impl.dart';

class GoogleRecoveryCredentialProvider {
  GoogleRecoveryCredentialProvider._(this._googleSignIn);

  static final GoogleRecoveryCredentialProvider instance =
      GoogleRecoveryCredentialProvider._(GoogleSignIn.instance);

  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;

  Future<AuthCredential?> requestCredential() async {
    try {
      await (_initialization ??= _googleSignIn.initialize());
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AccountRecoveryGatewayException('missing-id-token');
      }
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw AccountRecoveryGatewayException(error.code.name);
    }
  }

  Future<void> clearLocalSession() async {
    try {
      await _googleSignIn.signOut();
    } on Object {
      // Firebase Auth owns the app session. Google SDK cleanup is best effort.
    }
  }
}
