import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/activity_character_projection.dart';
import '../../domain/entities/owned_activity_character.dart';
import '../../domain/entities/save_activity_characters_command.dart';
import '../../domain/repositories/activity_characters_repository.dart';
import '../dtos/activity_character_projection_dto.dart';
import '../dtos/character_activity_document_dto.dart';
import '../mappers/activity_characters_firebase_mapper.dart';
import '../mappers/character_activity_write_plan.dart';

class FirestoreActivityCharactersRepository
    implements
        ActivityCharactersRepository,
        ActivityCharacterProjectionRepository {
  FirestoreActivityCharactersRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  // 각 쓰기는 Rules에서 binding, Character, GameAccount와 대표 활동 문서를
  // 확인한다. 여러 계정에서도 원자 작업당 문서 접근 20회보다 여유 있게 둔다.
  static const int _maxWritesPerAtomicOperation = 4;

  @override
  Future<ActivityCharacters> load({required String playerId}) async {
    if (playerId.trim().isEmpty) {
      throw const ActivityCharactersSaveException(
        ActivityCharactersSaveFailure.unauthenticated,
        '로그인한 사용자만 활동 캐릭터를 조회할 수 있습니다.',
      );
    }
    try {
      final snapshot = await _activityCollection(playerId).get();
      final characterIds = <String>{};
      for (final document in snapshot.docs) {
        final dto = CharacterActivityDocumentDto.fromMap(
          document.data(),
          documentId: document.id,
        );
        if (dto.schemaVersion != CharacterActivityWritePlan.schemaVersion ||
            dto.playerId != playerId) {
          throw const FormatException('Invalid character activity document.');
        }
        characterIds.add(dto.characterId);
      }
      return ActivityCharacters(playerId: playerId, characterIds: characterIds);
    } on ActivityCharactersSaveException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapActivityCharactersFirebaseException(error);
    }
  }

  @override
  Future<ActivityCharacters> save(SaveActivityCharactersCommand command) async {
    try {
      final preparation = await _firestore.runTransaction((transaction) async {
        final playerId = await _requirePlayerId(transaction);
        final ownedCharacters = await _loadOwnedCharacters(
          transaction,
          playerId: playerId,
          ownedCharacterIds: command.ownedCharacterIds,
        );
        final plan = CharacterActivityWritePlan.fromValidated(
          playerId: playerId,
          command: command,
          ownedCharacters: ownedCharacters,
          serverTimestamp: FieldValue.serverTimestamp(),
        );
        return _ActivitySavePreparation(
          plan: plan,
          representativeCharacterIds: {
            for (final character in ownedCharacters)
              if (character.isAccountRepresentative) character.characterId,
          },
        );
      });

      final plan = preparation.plan;
      final existingSnapshot = await _activityCollection(plan.playerId).get();
      final existingByCharacterId = {
        for (final document in existingSnapshot.docs)
          document.id: document.data(),
      };

      final documentsToWrite = plan.documentsByCharacterId.entries
          .where(
            (entry) => !_activityDocumentMatches(
              existingByCharacterId[entry.key],
              entry.value,
            ),
          )
          .toList();
      documentsToWrite.sort((left, right) {
        final leftRepresentative = preparation.representativeCharacterIds
            .contains(left.key);
        final rightRepresentative = preparation.representativeCharacterIds
            .contains(right.key);
        if (leftRepresentative != rightRepresentative) {
          return leftRepresentative ? -1 : 1;
        }
        return plan.activityCharacterIds
            .indexOf(left.key)
            .compareTo(plan.activityCharacterIds.indexOf(right.key));
      });

      for (final chunk in _chunks(documentsToWrite)) {
        await _firestore.runTransaction((transaction) async {
          for (final entry in chunk) {
            transaction.set(
              _activityRef(plan.playerId, entry.key),
              entry.value,
            );
          }
        });
      }

      final characterIdsToDelete = plan.characterIdsToRemove
          .where(existingByCharacterId.containsKey)
          .toList();
      for (final chunk in _chunks(characterIdsToDelete)) {
        await _firestore.runTransaction((transaction) async {
          final existing = <String>[];
          for (final characterId in chunk) {
            final snapshot = await transaction.get(
              _activityRef(plan.playerId, characterId),
            );
            if (snapshot.exists) {
              existing.add(characterId);
            }
          }
          for (final characterId in existing) {
            transaction.delete(_activityRef(plan.playerId, characterId));
          }
        });
      }

      return ActivityCharacters(
        playerId: plan.playerId,
        characterIds: plan.activityCharacterIds.toSet(),
      );
    } on ActivityCharactersSaveException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapActivityCharactersFirebaseException(error);
    }
  }

  bool _activityDocumentMatches(
    Map<String, dynamic>? existing,
    Map<String, Object?> target,
  ) {
    if (existing == null) return false;
    return existing['schemaVersion'] == target['schemaVersion'] &&
        existing['playerId'] == target['playerId'] &&
        existing['characterId'] == target['characterId'] &&
        existing['gameAccountId'] == target['gameAccountId'] &&
        existing['updatedAt'] is Timestamp;
  }

  Iterable<List<T>> _chunks<T>(List<T> values) sync* {
    for (
      var start = 0;
      start < values.length;
      start += _maxWritesPerAtomicOperation
    ) {
      final candidateEnd = start + _maxWritesPerAtomicOperation;
      final end = candidateEnd < values.length ? candidateEnd : values.length;
      yield values.sublist(start, end);
    }
  }

  @override
  Future<List<ActivityCharacterProjection>> loadProjections({
    required String playerId,
  }) async {
    if (playerId.trim().isEmpty) {
      throw const ActivityCharactersSaveException(
        ActivityCharactersSaveFailure.unauthenticated,
        '로그인한 사용자만 활동 캐릭터를 조회할 수 있습니다.',
      );
    }
    try {
      final snapshot = await _projectionCollection(playerId).get();
      final projections = <ActivityCharacterProjection>[];
      for (final document in snapshot.docs) {
        final dto = ActivityCharacterProjectionDto.fromMap(
          document.data(),
          documentId: document.id,
        );
        if (dto.schemaVersion !=
                CharacterActivityWritePlan.projectionSchemaVersion ||
            dto.playerId != playerId) {
          throw const FormatException(
            'Invalid activity character projection document.',
          );
        }
        projections.add(
          ActivityCharacterProjection(
            playerId: dto.playerId,
            characterId: dto.characterId,
            characterName: dto.characterName,
            serverName: dto.serverName,
            characterClassName: dto.characterClassName,
            displayOrder: dto.displayOrder,
            isRepresentative: dto.isRepresentative,
            itemLevel: dto.itemLevel,
            combatPower: dto.combatPower,
          ),
        );
      }
      projections.sort((left, right) {
        final byOrder = left.displayOrder.compareTo(right.displayOrder);
        if (byOrder != 0) return byOrder;
        return left.characterId.compareTo(right.characterId);
      });
      return projections;
    } on ActivityCharactersSaveException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapActivityCharactersFirebaseException(error);
    }
  }

  Future<String> _requirePlayerId(Transaction transaction) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const ActivityCharactersSaveException(
        ActivityCharactersSaveFailure.unauthenticated,
        '로그인한 사용자만 활동 캐릭터를 저장할 수 있습니다.',
      );
    }
    final binding = await transaction.get(
      _firestore.collection('authBindings').doc(uid),
    );
    final playerId = binding.data()?['playerId'];
    if (binding.data()?['status'] != 'active' ||
        playerId is! String ||
        playerId.isEmpty) {
      throw const ActivityCharactersSaveException(
        ActivityCharactersSaveFailure.unauthenticated,
        '로그인한 사용자만 활동 캐릭터를 저장할 수 있습니다.',
      );
    }
    final player = await transaction.get(
      _firestore.collection('players').doc(playerId),
    );
    if (player.data()?['status'] != 'active') {
      throw const ActivityCharactersSaveException(
        ActivityCharactersSaveFailure.unauthenticated,
        '로그인한 사용자만 활동 캐릭터를 저장할 수 있습니다.',
      );
    }
    return playerId;
  }

  Future<List<OwnedActivityCharacter>> _loadOwnedCharacters(
    Transaction transaction, {
    required String playerId,
    required Set<String> ownedCharacterIds,
  }) async {
    final characters = <OwnedActivityCharacter>[];
    final ownershipCache = <String, Map<String, dynamic>?>{};
    for (final characterId in ownedCharacterIds) {
      if (characterId.trim().isEmpty || characterId.contains('/')) {
        throw const ActivityCharactersSaveException(
          ActivityCharactersSaveFailure.invalidCharacterId,
          '활동 캐릭터 ID가 올바르지 않습니다.',
        );
      }
      final snapshot = await transaction.get(
        _firestore.collection('characters').doc(characterId),
      );
      final data = snapshot.data();
      final gameAccountId = data?['gameAccountId'];
      if (data == null || gameAccountId is! String || gameAccountId.isEmpty) {
        throw const ActivityCharactersSaveException(
          ActivityCharactersSaveFailure.notOwned,
          '현재 Player가 active 소유한 캐릭터만 선택할 수 있습니다.',
        );
      }
      if (!ownershipCache.containsKey(gameAccountId)) {
        ownershipCache[gameAccountId] = (await transaction.get(
          _firestore
              .collection('playerGameAccounts')
              .doc('${playerId}_$gameAccountId'),
        )).data();
      }
      final ownership = ownershipCache[gameAccountId];
      final representative = ownership?['representativeCharacterId'];
      characters.add(
        OwnedActivityCharacter(
          characterId: characterId,
          gameAccountId: gameAccountId,
          ownerPlayerId: data['ownerPlayerId'] as String? ?? '',
          status: data['status'] as String? ?? '',
          ownershipStatus: ownership?['status'] as String? ?? '',
          representativeCharacterId:
              representative is String && representative.isNotEmpty
              ? representative
              : null,
          characterName: data['characterName'] as String? ?? '',
          serverName: data['serverName'] as String? ?? '',
          characterClassName: data['characterClassName'] as String? ?? '',
          itemLevel: _optionalNumber(data['itemLevel'] ?? data['itemAvgLevel']),
          combatPower: _optionalNumber(data['combatPower']),
        ),
      );
    }
    return characters;
  }

  CollectionReference<Map<String, dynamic>> _activityCollection(
    String playerId,
  ) {
    return _firestore
        .collection('players')
        .doc(playerId)
        .collection('characterActivity');
  }

  CollectionReference<Map<String, dynamic>> _projectionCollection(
    String playerId,
  ) {
    return _firestore
        .collection('players')
        .doc(playerId)
        .collection('activityCharacterProjections');
  }

  DocumentReference<Map<String, dynamic>> _activityRef(
    String playerId,
    String characterId,
  ) {
    return _activityCollection(playerId).doc(characterId);
  }

  static double? _optionalNumber(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '').trim());
    }
    return null;
  }
}

class _ActivitySavePreparation {
  const _ActivitySavePreparation({
    required this.plan,
    required this.representativeCharacterIds,
  });

  final CharacterActivityWritePlan plan;
  final Set<String> representativeCharacterIds;
}
