import 'dart:math';

import '../../domain/character_identity_key.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/game_account_verification.dart';
import '../../domain/repositories/game_account_verification_gateway.dart';
import '../datasources/lost_ark_character_remote_data_source.dart';
import '../dtos/sibling_character_dto.dart';

class LocalGameAccountVerificationGateway
    implements GameAccountVerificationGateway {
  LocalGameAccountVerificationGateway({
    required LostArkCharacterRemoteDataSource remoteDataSource,
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    Random? random,
    DateTime Function()? clock,
  }) : _remoteDataSource = remoteDataSource,
       _firestore = firestore,
       _firebaseAuth = firebaseAuth,
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
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final Random _random;
  final DateTime Function() _clock;
  _LocalChallenge? _activeChallenge;

  @override
  GameAccountVerificationChallenge? get activeChallenge {
    final challenge = _activeChallenge;
    if (challenge == null) return null;
    if (!_clock().isBefore(challenge.expiresAt)) {
      _activeChallenge = null;
      return null;
    }
    return challenge.publicValue;
  }

  @override
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
    final baseline = _equipment(responses[1] as Map<String, dynamic>);
    if (baseline.length != _slots.length) {
      throw const FormatException('All six verification items are required.');
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

  @override
  Future<GameAccountVerificationResult> confirm(String challengeId) async {
    final challenge = _activeChallenge;
    if (challenge == null || challenge.id != challengeId) {
      return const GameAccountVerificationResult(status: 'expired');
    }
    if (!_clock().isBefore(challenge.expiresAt)) {
      _activeChallenge = null;
      return const GameAccountVerificationResult(status: 'expired');
    }
    final armory = await _remoteDataSource.fetchCharacterArmory(
      challenge.characterName,
    );
    final current = _equipment(armory, requireComplete: false);
    final stillEquipped = challenge.requiredSlots
        .where(current.containsKey)
        .toList(growable: false);
    if (stillEquipped.isNotEmpty) {
      return GameAccountVerificationResult(
        status: 'requiredSlotsStillEquipped',
        slots: stillEquipped,
      );
    }
    for (final slot in _slots.keys.where(
      (slot) => !challenge.requiredSlots.contains(slot),
    )) {
      if (current[slot] != challenge.baseline[slot]) {
        return GameAccountVerificationResult(
          status: 'unchallengedSlotChanged',
          slots: [slot],
        );
      }
    }

    final result = await _claimOwnership(challenge);
    _activeChallenge = null;
    return result;
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

  Future<GameAccountVerificationResult> _claimOwnership(
    _LocalChallenge challenge,
  ) async {
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null) throw StateError('Authentication is required.');
    final claimRefs = challenge.siblings
        .map(
          (item) => _firestore
              .collection('characterIdentityClaims')
              .doc(_identityKey(item.serverName, item.characterName)),
        )
        .toList(growable: false);

    return _firestore.runTransaction((transaction) async {
      final binding = await transaction.get(
        _firestore.collection('authBindings').doc(authUid),
      );
      final playerId = binding.data()?['playerId'];
      if (!binding.exists || playerId is! String || playerId.isEmpty) {
        throw StateError('Active player binding is required.');
      }
      final claims = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in claimRefs) {
        claims.add(await transaction.get(ref));
      }
      final accountIds = claims
          .where((snapshot) => snapshot.exists)
          .map((snapshot) => snapshot.data()?['gameAccountId'])
          .whereType<String>()
          .toSet();
      if (accountIds.length > 1) {
        throw StateError('Conflicting game account identities.');
      }
      final accountRef = accountIds.isEmpty
          ? _firestore.collection('gameAccounts').doc()
          : _firestore.collection('gameAccounts').doc(accountIds.single);
      final account = accountIds.isEmpty
          ? null
          : await transaction.get(accountRef);
      final previousOwner = account?.data()?['ownerPlayerId'];
      final storedCharacterIds =
          (account?.data()?['characterIds'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      final characterRefs = <DocumentReference<Map<String, dynamic>>>[];
      for (var index = 0; index < claims.length; index++) {
        final characterId = claims[index].data()?['characterId'];
        characterRefs.add(
          characterId is String && characterId.isNotEmpty
              ? _firestore.collection('characters').doc(characterId)
              : _firestore.collection('characters').doc(),
        );
      }
      final allCharacterIds = {
        ...storedCharacterIds,
        ...characterRefs.map((ref) => ref.id),
      };
      final storedCharacters = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final id in allCharacterIds) {
        storedCharacters.add(
          await transaction.get(_firestore.collection('characters').doc(id)),
        );
      }

      final now = FieldValue.serverTimestamp();
      for (final snapshot in storedCharacters) {
        if (snapshot.exists &&
            !characterRefs.any((ref) => ref.id == snapshot.id)) {
          transaction.update(snapshot.reference, {
            'ownerPlayerId': playerId,
            'rosterStatus': 'missingFromLatestRoster',
            'updatedAt': now,
          });
        }
      }
      transaction.set(accountRef, {
        'schemaVersion': 1,
        'ownerPlayerId': playerId,
        'status': 'active',
        'lookupCharacterName': challenge.characterName,
        'characterIds': allCharacterIds.toList(growable: false),
        'createdAt': account?.data()?['createdAt'] ?? now,
        'updatedAt': now,
      });
      final serverCharacters = <VerifiedServerCharacter>[];
      for (var index = 0; index < challenge.siblings.length; index++) {
        final sibling = challenge.siblings[index];
        final characterRef = characterRefs[index];
        final storedCharacter = storedCharacters
            .where((item) => item.id == characterRef.id)
            .firstOrNull;
        transaction.set(characterRef, {
          'schemaVersion': 1,
          'ownerPlayerId': playerId,
          'gameAccountId': accountRef.id,
          'status': 'active',
          'rosterStatus': 'confirmed',
          'serverName': sibling.serverName,
          'characterName': sibling.characterName,
          'characterClassName': sibling.characterClassName,
          'characterLevel': sibling.characterLevel,
          'itemAvgLevel': sibling.itemAvgLevel,
          'createdAt': storedCharacter?.data()?['createdAt'] ?? now,
          'updatedAt': now,
        });
        transaction.set(claimRefs[index], {
          'schemaVersion': 1,
          'gameAccountId': accountRef.id,
          'characterId': characterRef.id,
          'serverName': sibling.serverName,
          'characterName': sibling.characterName,
          'updatedAt': now,
        });
        serverCharacters.add(
          VerifiedServerCharacter(
            serverName: sibling.serverName,
            characterName: sibling.characterName,
            serverCharacterId: characterRef.id,
          ),
        );
      }
      transaction.set(
        _firestore
            .collection('playerGameAccounts')
            .doc('${playerId}_${accountRef.id}'),
        {
          'schemaVersion': 1,
          'playerId': playerId,
          'gameAccountId': accountRef.id,
          'status': 'active',
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
      if (previousOwner is String && previousOwner != playerId) {
        transaction.set(
          _firestore
              .collection('playerGameAccounts')
              .doc('${previousOwner}_${accountRef.id}'),
          {
            'schemaVersion': 1,
            'playerId': previousOwner,
            'gameAccountId': accountRef.id,
            'status': 'ownershipLost',
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      }
      return GameAccountVerificationResult(
        status: 'verified',
        serverGameAccountId: accountRef.id,
        serverCharacters: serverCharacters,
      );
    });
  }

  String _identityKey(String serverName, String characterName) =>
      characterIdentityKey(serverName, characterName);
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
