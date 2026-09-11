import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

import '../../domain/entities/group_request_character.dart';
import '../../domain/repositories/group_character_search_repository.dart';
import '../../domain/repositories/group_read_repository.dart';

/// 계약 §6·§12.6. `status == active`와 정확한 `characterName` 등식 query만 쓴다.
/// 전체 스캔·prefix 검색은 하지 않고 결과 수도 페이지 크기로 제한한다.
class FirestoreGroupCharacterSearchRepository
    implements GroupCharacterSearchRepository {
  const FirestoreGroupCharacterSearchRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<List<GroupRequestCharacter>> searchActiveCharactersByExactName(
    String characterName, {
    int limit = groupCharacterSearchPageSize,
  }) async {
    final exactName = characterName.trim();
    if (exactName.isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('characters')
          .where('status', isEqualTo: 'active')
          .where('characterName', isEqualTo: exactName)
          .limit(limit)
          .get();
      return snapshot.docs
          .map(_toCandidate)
          .whereType<GroupRequestCharacter>()
          .toList(growable: false);
    } catch (error) {
      throw _mapCharacterSearchError(error);
    }
  }

  @override
  Future<List<GroupRequestCharacter>> loadActiveCharactersForPlayer(
    String ownerPlayerId, {
    int limit = groupCharacterSearchPageSize,
  }) async {
    if (ownerPlayerId.trim().isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('characters')
          .where('status', isEqualTo: 'active')
          .where('ownerPlayerId', isEqualTo: ownerPlayerId)
          .limit(limit)
          .get();
      final characters = snapshot.docs
          .map(_toCandidate)
          .whereType<GroupRequestCharacter>()
          .toList(growable: true)
        ..sort((left, right) {
          final leftLevel = left.itemLevel ?? 0;
          final rightLevel = right.itemLevel ?? 0;
          return rightLevel.compareTo(leftLevel);
        });
      return characters;
    } catch (error) {
      throw _mapCharacterSearchError(error);
    }
  }

  GroupRequestCharacter? _toCandidate(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return mapGroupRequestCharacter(
      characterId: document.id,
      data: document.data(),
    );
  }
}

/// Character 문서 맵에서 초대·활동 목록용 Snapshot을 만든다.
GroupRequestCharacter? mapGroupRequestCharacter({
  required String characterId,
  required Map<String, dynamic> data,
}) {
  final ownerPlayerId = data['ownerPlayerId'];
  final name = data['characterName'];
  final serverName = data['serverName'];
  final className = data['characterClassName'];
  if (ownerPlayerId is! String ||
      ownerPlayerId.isEmpty ||
      name is! String ||
      name.isEmpty ||
      serverName is! String ||
      serverName.isEmpty ||
      className is! String ||
      className.isEmpty) {
    return null;
  }
  return GroupRequestCharacter(
    characterId: characterId,
    ownerPlayerId: ownerPlayerId,
    characterName: name,
    serverName: serverName,
    characterClassName: className,
    itemLevel: parseCharacterItemLevel(data['itemAvgLevel']),
    combatPower: parseCharacterItemLevel(data['combatPower']),
    buildIntegritySnapshot: BuildIntegritySnapshot.tryFromFields(
      data['buildIntegritySnapshot'],
      parseDate: _parseIntegrityCheckedAt,
    ),
  );
}

DateTime? _parseIntegrityCheckedAt(Object? value) {
  return switch (value) {
    Timestamp timestamp => timestamp.toDate().toUtc(),
    DateTime dateTime => dateTime.toUtc(),
    String text => DateTime.tryParse(text)?.toUtc(),
    _ => null,
  };
}

/// 서버 Character의 `itemAvgLevel`은 천 단위 구분 기호가 있는 문자열일 수 있다.
double? parseCharacterItemLevel(Object? value) => value is num
    ? value.toDouble()
    : value is String
    ? double.tryParse(value.replaceAll(',', '').trim())
    : null;

GroupReadException _mapCharacterSearchError(Object error) {
  if (error is GroupReadException) return error;
  if (error is FirebaseException) {
    return GroupReadException(switch (error.code) {
      'permission-denied' => GroupReadFailureType.permissionDenied,
      'unavailable' ||
      'deadline-exceeded' ||
      'aborted' ||
      'failed-precondition' =>
        GroupReadFailureType.unavailable,
      _ => GroupReadFailureType.unknown,
    });
  }
  return const GroupReadException(GroupReadFailureType.unknown);
}
