class AccountRecoveryStatus {
  const AccountRecoveryStatus({required this.isGoogleLinked});

  final bool isGoogleLinked;
}

enum AccountRecoveryLinkResult { linked, alreadyLinked, cancelled }

enum AccountRecoveryFailureReason {
  noAuthenticatedUser,
  credentialAlreadyInUse,
  providerNotEnabled,
  invalidCredential,
  network,
  tooManyRequests,
  recoveryAccountNotFound,
  uidChanged,
  unknown,
}

class AccountRecoveryException implements Exception {
  const AccountRecoveryException(this.reason);

  final AccountRecoveryFailureReason reason;
}
