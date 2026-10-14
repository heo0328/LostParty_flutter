import 'dart:math';

import '../../domain/entities/game_account_verification.dart';
import '../../domain/repositories/game_account_verification_gateway.dart';
import '../datasources/lost_ark_character_remote_data_source.dart';
import '../dtos/sibling_character_dto.dart';

/// Local equipment preview only. Server ownership is never granted here.
class EquipmentVerificationPreview {
  EquipmentVerificationPreview({
    required LostArkCharacterRemoteDataSource remoteDataSource,
    Random? random,
    DateTime Function()? clock,
  }) : _remoteDataSource = remoteDataSource,
       _random = random ?? Random.secure(),
       _clock = clock ?? DateTime.now;

  static const _slots = <String, String>{
    'weapon': '무기',
    'head': '투구',
    'shoulders': '어깨',
    'chest': '상의',
    'legs': '하의',
    'hands': '장갑',
  };

  final LostArkCharacterRemoteDataSource _remoteDataSource;
  final Random _random;
  final DateTime Function() _clock;
  _LocalChallenge? _activeChallenge;

  GameAccountVerificationChallenge? get activeChallenge {
    final challenge = _activeChallenge;
    if (challenge == null) return null;
    if (!_clock().isBefore(challenge.expiresAt)) {
      _activeChallenge = null;
      return null;
    }
    return challenge.publicValue;
  }

  Future<GameAccountVerificationChallenge> start({
    required String characterName,
    required String source,
    int? localAccountId,
  }) async {
    final normalizedName = characterName.trim();
    final responses = await Future.wait<Object>([
      _remoteDataSource.fetchSiblings(normalizedName),
      _remoteDataSource.fetchCharacterArmory(normalizedName),
    ]);
    final siblings = responses[0] as List<SiblingCharacterDto>;
    if (!siblings.any((item) => item.characterName == normalizedName)) {
      throw const FormatException('Requested character is not in the roster.');
    }
    final baseline = _equipment(
      responses[1] as Map<String, dynamic>,
      requireComplete: false,
    );
    if (baseline.length != _slots.length) {
      throw const GameAccountVerificationStartException(
        GameAccountVerificationStartFailure.incompleteEquipment,
      );
    }

    final candidates = _slots.keys.toList()..shuffle(_random);
    final required = candidates.take(1 + _random.nextInt(3)).toList();
    final createdAt = _clock();
    final challenge = _LocalChallenge(
      id: '${createdAt.microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
      characterName: normalizedName,
      baseline: baseline,
      requiredSlots: required,
      siblings: siblings,
      expiresAt: createdAt.add(const Duration(minutes: 10)),
    );
    _activeChallenge = challenge;
    return challenge.publicValue;
  }

  Map<String, _EquipmentIdentity> _equipment(
    Map<String, dynamic> armory, {
    bool requireComplete = true,
  }) {
    final rawItems = armory['ArmoryEquipment'];
    if (rawItems is! List) throw const FormatException('Invalid equipment.');
    final result = <String, _EquipmentIdentity>{};
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final type = raw['Type'];
      final matching = _slots.entries.where((entry) => entry.value == type);
      if (matching.isEmpty) continue;
      final name = raw['Name'];
      final grade = raw['Grade'];
      if (name is! String || grade is! String) {
        throw const FormatException('Invalid equipment item.');
      }
      final slot = matching.single.key;
      if (result.containsKey(slot)) {
        throw const FormatException('Duplicate equipment slot.');
      }
      result[slot] = _EquipmentIdentity(name, grade);
    }
    if (requireComplete && result.length != _slots.length) {
      throw const FormatException('Incomplete equipment.');
    }
    return result;
  }
}

class _LocalChallenge {
  const _LocalChallenge({
    required this.id,
    required this.characterName,
    required this.baseline,
    required this.requiredSlots,
    required this.siblings,
    required this.expiresAt,
  });

  final String id;
  final String characterName;
  final Map<String, _EquipmentIdentity> baseline;
  final List<String> requiredSlots;
  final List<SiblingCharacterDto> siblings;
  final DateTime expiresAt;

  GameAccountVerificationChallenge get publicValue =>
      GameAccountVerificationChallenge(
        challengeId: id,
        characterName: characterName,
        requiredUnequippedSlots: requiredSlots,
        expiresAt: expiresAt,
      );
}

class _EquipmentIdentity {
  const _EquipmentIdentity(this.name, this.grade);

  final String name;
  final String grade;

  @override
  bool operator ==(Object other) =>
      other is _EquipmentIdentity && other.name == name && other.grade == grade;

  @override
  int get hashCode => Object.hash(name, grade);
}
