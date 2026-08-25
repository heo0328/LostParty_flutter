import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/game_account_verification.dart';
import '../../domain/repositories/game_account_verification_gateway.dart';

class FirebaseGameAccountVerificationGateway
    implements GameAccountVerificationGateway {
  FirebaseGameAccountVerificationGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<GameAccountVerificationChallenge> start({
    required String characterName,
    required String source,
    int? localAccountId,
  }) async {
    final result = await _functions
        .httpsCallable('startGameAccountVerification')
        .call(<String, Object?>{
          'characterName': characterName,
          'source': source,
          'localAccountId': localAccountId,
        });
    final data = _map(result.data);
    return GameAccountVerificationChallenge(
      challengeId: _string(data, 'challengeId'),
      characterName: _string(data, 'characterName'),
      requiredUnequippedSlots: _strings(data['requiredUnequippedSlots']),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        _integer(data, 'expiresAtMillis'),
      ),
    );
  }

  @override
  Future<GameAccountVerificationResult> confirm(String challengeId) async {
    final result = await _functions
        .httpsCallable('confirmGameAccountVerification')
        .call(<String, Object?>{'challengeId': challengeId});
    final data = _map(result.data);
    final characters = (data['serverCharacters'] as List<Object?>? ?? const [])
        .map(_map)
        .map(
          (character) => VerifiedServerCharacter(
            serverName: _string(character, 'serverName'),
            characterName: _string(character, 'characterName'),
            serverCharacterId: _string(character, 'serverCharacterId'),
          ),
        )
        .toList(growable: false);
    return GameAccountVerificationResult(
      status: _string(data, 'status'),
      serverGameAccountId: data['serverGameAccountId'] as String?,
      serverCharacters: characters,
      slots: _strings(data['slots']),
    );
  }

  static Map<Object?, Object?> _map(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const FormatException('Callable response must be a map.');
    }
    return value;
  }

  static String _string(Map<Object?, Object?> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing $key.');
    }
    return value;
  }

  static int _integer(Map<Object?, Object?> data, String key) {
    final value = data[key];
    if (value is! int) throw FormatException('Missing $key.');
    return value;
  }

  static List<String> _strings(Object? value) =>
      (value as List<Object?>? ?? const []).map((item) {
        if (item is! String) throw const FormatException('Invalid list item.');
        return item;
      }).toList(growable: false);
}
