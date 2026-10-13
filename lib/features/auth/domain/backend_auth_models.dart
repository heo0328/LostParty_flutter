import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String newAuthSecret() {
  final random = Random.secure();
  return base64UrlEncode(
    List<int>.generate(32, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
}

String authSecretDigest(String secret) =>
    sha256.convert(ascii.encode(secret)).toString();

class AuthApiException implements Exception {
  const AuthApiException(this.code, {this.status, this.retryAfter});
  final String code;
  final int? status;
  final Duration? retryAfter;
  bool get transient =>
      code == 'NETWORK_UNAVAILABLE' || status == 503 || status == 429;
  @override
  String toString() => 'AuthApiException($code)';
}

class AuthChallenge {
  AuthChallenge.fromJson(Map<String, dynamic> json)
    : id = _text(json, 'transaction_id'),
      nonce = _text(json, 'nonce'),
      expiresAt = _time(json, 'expires_at');
  final String id;
  final String nonce;
  final DateTime expiresAt;
}

class AuthUser {
  AuthUser.fromJson(Map<String, dynamic> json)
    : id = _text(json, 'id'),
      status = _text(json, 'status'),
      createdAt = _time(json, 'created_at');
  final String id;
  final String status;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}

class AuthSession {
  AuthSession.fromJson(Map<String, dynamic> json)
    : id = _text(json, 'id'),
      remember = json['remember_me'] as bool,
      createdAt = _time(json, 'created_at'),
      absoluteExpiresAt = _time(json, 'absolute_expires_at'),
      idleExpiresAt = _time(json, 'idle_expires_at'),
      expiresAt = _time(json, 'expires_at');
  final String id;
  final bool remember;
  final DateTime createdAt, absoluteExpiresAt, idleExpiresAt, expiresAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'remember_me': remember,
    'created_at': createdAt.toIso8601String(),
    'absolute_expires_at': absoluteExpiresAt.toIso8601String(),
    'idle_expires_at': idleExpiresAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
  };
}

class AuthTokens {
  AuthTokens.fromJson(Map<String, dynamic> json)
    : access = _text(json, 'access_token'),
      refresh = _text(json, 'refresh_token'),
      accessExpiresAt = _time(json, 'access_expires_at'),
      refreshExpiresAt = _time(json, 'refresh_expires_at'),
      session = AuthSession.fromJson(json['session'] as Map<String, dynamic>) {
    if (json['token_type'] != 'Bearer') {
      throw const FormatException('Invalid authentication response.');
    }
  }
  final String access, refresh;
  final DateTime accessExpiresAt, refreshExpiresAt;
  final AuthSession session;
  Map<String, dynamic> toJson() => {
    'token_type': 'Bearer',
    'access_token': access,
    'refresh_token': refresh,
    'access_expires_at': accessExpiresAt.toIso8601String(),
    'refresh_expires_at': refreshExpiresAt.toIso8601String(),
    'session': session.toJson(),
  };
  @override
  String toString() => 'AuthTokens(***)';
}

class AuthLogin {
  AuthLogin.fromJson(Map<String, dynamic> json)
    : user = AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      tokens = AuthTokens.fromJson(json),
      isNewUser = json['is_new_user'] as bool;
  final AuthUser user;
  final AuthTokens tokens;
  final bool isNewUser;
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid authentication response.');
  }
  return value;
}

DateTime _time(Map<String, dynamic> json, String key) =>
    DateTime.parse(_text(json, key)).toUtc();
