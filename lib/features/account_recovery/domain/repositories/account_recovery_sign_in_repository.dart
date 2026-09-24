sealed class AccountRecoverySignInResult {
  const AccountRecoverySignInResult();
}

class AccountRecoverySignInRecovered extends AccountRecoverySignInResult {
  const AccountRecoverySignInRecovered({required this.isNewUser});

  final bool isNewUser;
}

class AccountRecoverySignInCancelled extends AccountRecoverySignInResult {
  const AccountRecoverySignInCancelled();
}

abstract class AccountRecoverySignInRepository {
  Future<AccountRecoverySignInResult> signInWithGoogle();
}
