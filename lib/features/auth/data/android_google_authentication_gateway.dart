import 'package:flutter/services.dart';

import '../domain/google_authentication_gateway.dart';

class AndroidGoogleAuthenticationGateway
    implements GoogleAuthenticationGateway {
  AndroidGoogleAuthenticationGateway({
    MethodChannel channel = const MethodChannel('lostparty/google_auth'),
  }) : _channel = channel;

  final MethodChannel _channel;
  bool _busy = false;

  @override
  Future<GoogleAuthenticationProof> authenticate({
    required String serverClientId,
    required String nonce,
  }) async {
    // Reject inputs without putting credentials or transaction material in errors.
    if (serverClientId.trim().isEmpty || nonce.trim().isEmpty) {
      throw ArgumentError('Google client ID and server nonce are required.');
    }
    return _run(() async {
      final token = await _channel.invokeMethod<String>('authenticate', {
        'serverClientId': serverClientId,
        'nonce': nonce,
      });
      if (token == null || token.trim().isEmpty) {
        throw const GoogleAuthenticationException(
          GoogleAuthenticationFailure.invalidResponse,
        );
      }
      return GoogleAuthenticationProof(token);
    });
  }

  @override
  Future<void> clearCredentialState() =>
      _run(() => _channel.invokeMethod<void>('clearCredentialState'));

  Future<T> _run<T>(Future<T> Function() operation) async {
    if (_busy) {
      throw const GoogleAuthenticationException(
        GoogleAuthenticationFailure.busy,
      );
    }
    _busy = true;
    try {
      return await operation();
    } on MissingPluginException {
      throw const GoogleAuthenticationException(
        GoogleAuthenticationFailure.unavailable,
      );
    } on PlatformException catch (error) {
      final failure = switch (error.code) {
        'CANCELLED' => GoogleAuthenticationFailure.cancelled,
        'BUSY' => GoogleAuthenticationFailure.busy,
        'UNAVAILABLE' => GoogleAuthenticationFailure.unavailable,
        'INVALID_RESPONSE' => GoogleAuthenticationFailure.invalidResponse,
        _ => GoogleAuthenticationFailure.failed,
      };
      // Native error messages/details may contain provider data. Do not forward.
      throw GoogleAuthenticationException(failure);
    } on TypeError {
      throw const GoogleAuthenticationException(
        GoogleAuthenticationFailure.invalidResponse,
      );
    } finally {
      _busy = false;
    }
  }
}
