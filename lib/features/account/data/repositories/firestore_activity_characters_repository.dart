import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/owned_activity_character.dart';
import '../../domain/entities/save_activity_characters_command.dart';
import '../../domain/repositories/activity_characters_repository.dart';
import '../dtos/character_activity_document_dto.dart';
import '../mappers/character_activity_write_plan.dart';

class FirestoreActivityCharactersRepository
    implements ActivityCharactersRepository {
  FirestoreActivityCharactersRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<ActivityCharacters> load({required String playerId}) async {
    if (playerId.trim().isEmpty) {
      throw const ActivityCharactersSaveException(
        ActivityCharactersSaveFailure.unauthenticated,
        '로그인한 사용자만 활동 캐릭터를 조회할 수 있습니다.',
      );
    }
    final snapshot = await _activityRef(playerId).get();
    if (!snapshot.exists) {
      return ActivityCharacters(playerId: playerId, characterIds: const {});
    }
    final dto = CharacterActivityDocumentDto.fromMap(snapshot.data()!);
    if (dto.schemaVersion != CharacterActivityWritePlan.schemaVersion ||
        dto.playerId != playerId) {
      throw const FormatException('Invalid character activity document.');
    }
    return ActivityCharacters(
      playerId: playerId,
      characterIds: dto.activityCharacterIds.toSet(),
    );
  }

  @override
  Future<ActivityCharacters> save(SaveActivityCharactersCommand command) {
    return _firestore.runTransaction((transaction) async {
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
      transaction.set(_activityRef(playerId), plan.document);
      return ActivityCharacters(
        playerId: playerId,
        characterIds: plan.activityCharacterIds.toSet(),
      );
    });
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
        ),
      );
    }
    return characters;
  }

  DocumentReference<Map<String, dynamic>> _activityRef(String playerId) {
    return _firestore
        .collection('players')
        .doc(playerId)
        .collection('characterActivity')
        .doc(CharacterActivityWritePlan.documentId);
  }
}
