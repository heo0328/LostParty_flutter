/// Google evidence must be verified by the Backend before an app session exists.
class GoogleAuthenticationProof {
  GoogleAuthenticationProof(this.idToken) {
    if (idToken.trim().isEmpty) {
      throw const FormatException('Google authentication proof is empty.');
    }
  }

  final String idToken;

  @override
  String toString() => 'GoogleAuthenticationProof(***)';
}

enum GoogleAuthenticationFailure {
  cancelled,
  busy,
  unavailable,
  invalidResponse,
  failed,
}

class GoogleAuthenticationException implements Exception {
  const GoogleAuthenticationException(this.failure);

  final GoogleAuthenticationFailure failure;

  @override
  String toString() => 'GoogleAuthenticationException(${failure.name})';
}

abstract interface class GoogleAuthenticationGateway {
  /// Each attempt must use the nonce from its own unconsumed server challenge.
  Future<GoogleAuthenticationProof> authenticate({
    required String serverClientId,
    required String nonce,
  });

  /// Clears provider account selection state; does not revoke a Backend session.
  Future<void> clearCredentialState();
}
