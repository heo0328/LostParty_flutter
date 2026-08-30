import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/group_blocked_player.dart';
import '../../domain/entities/group_join_relation.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_summary.dart';
import '../../domain/repositories/group_read_repository.dart';
import '../../domain/services/group_name_normalizer.dart';
import '../mappers/group_document_mapper.dart';

/// 계약 §8.2. 검색은 정규화 필드별 prefix query를 각각 실행하고 Group ID로 중복을
/// 제거한다. 전체 다운로드 후 클라이언트 필터링은 하지 않는다.
class FirestoreGroupReadRepository implements GroupReadRepository {
  FirestoreGroupReadRepository({
    required FirebaseFirestore firestore,
    GroupNameNormalizer normalizer = const GroupNameNormalizer(),
  }) : _firestore = firestore,
       _normalizer = normalizer,
       _mapper = GroupDocumentMapper(
         toDateTime: (value) => switch (value) {
           Timestamp timestamp => timestamp.toDate(),
           DateTime dateTime => dateTime,
           _ => throw const FormatException('Expected Firestore Timestamp.'),
         },
       );

  static const _prefixUpperBoundSuffix = '\uf8ff';

  final FirebaseFirestore _firestore;
  final GroupNameNormalizer _normalizer;
  final GroupDocumentMapper _mapper;

  @override
  Stream<GroupReadSnapshot<GroupRelation>> watchMyGroups(String playerId) {
    return _firestore
        .collection('players')
        .doc(playerId)
        .collection('groupRelations')
        .where('relation', isEqualTo: GroupRelationKind.member.name)
        .orderBy('updatedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => GroupReadSnapshot(
            items: snapshot.docs
                .map(_document)
                .map(_mapper.toRelation)
                .toList(growable: false),
            isFromCache: snapshot.metadata.isFromCache,
          ),
        )
        .transform(_errorTransformer());
  }

  @override
  Stream<GroupReadSnapshot<GroupRelation>> watchMyRequests(String playerId) {
    return _firestore
        .collection('players')
        .doc(playerId)
        .collection('groupRelations')
        .where(
          'relation',
          whereIn: [
            GroupRelationKind.invited.name,
            GroupRelationKind.applied.name,
          ],
        )
        .orderBy('updatedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => GroupReadSnapshot(
            items: snapshot.docs
                .map(_document)
                .map(_mapper.toRelation)
                .toList(growable: false),
            isFromCache: snapshot.metadata.isFromCache,
          ),
        )
        .transform(_errorTransformer());
  }

  @override
  Future<GroupRelation?> loadMyRelation({
    required String playerId,
    required String groupId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('players')
          .doc(playerId)
          .collection('groupRelations')
          .doc(groupId)
          .get();
      if (!snapshot.exists) return null;
      return _mapper.toRelation(_document(snapshot));
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<List<GroupJoinRelation>> loadGroupJoinRelations({
    required String groupId,
    required GroupJoinRelationKind kind,
    int limit = groupSearchPageSize,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('joinRelations')
          .where('kind', isEqualTo: kind.name)
          .where('status', isEqualTo: GroupRequestStatus.pending.name)
          .orderBy('createdAt')
          .limit(limit)
          .get();
      return snapshot.docs
          .map(_document)
          .map(_mapper.toJoinRelation)
          .toList(growable: false);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<GroupMember?> loadGroupMember({
    required String groupId,
    required String playerId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(playerId)
          .get();
      if (!snapshot.exists) return null;
      return _mapper.toMember(_document(snapshot));
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<List<GroupBlockedPlayer>> loadBlockedPlayers({
    required String groupId,
    int limit = groupSearchPageSize,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('blockedPlayers')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map(_document)
          .map(_mapper.toBlockedPlayer)
          .toList(growable: false);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<List<GroupPublicSummary>> searchGroups({
    required String query,
    int limit = groupSearchPageSize,
  }) async {
    final normalized = _normalizer.normalize(query);
    try {
      final snapshots = normalized.isEmpty
          ? [await _recentGroupsQuery(limit).get()]
          : await Future.wait([
              _prefixQuery('normalizedName', normalized, limit).get(),
              _prefixQuery(
                'normalizedRepresentativeCharacterName',
                normalized,
                limit,
              ).get(),
            ]);
      final byId = <String, GroupPublicSummary>{};
      for (final snapshot in snapshots) {
        for (final document in snapshot.docs) {
          byId[document.id] = _mapper.toPublicSummary(_document(document));
        }
      }
      final items = byId.values.toList(growable: false)
        ..sort(
          (left, right) => right.lastActivityAt.compareTo(left.lastActivityAt),
        );
      return items.take(limit).toList(growable: false);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<GroupPublicSummary?> loadGroup(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .get();
      if (!snapshot.exists) return null;
      return _mapper.toPublicSummary(_document(snapshot));
    } catch (error) {
      throw _mapError(error);
    }
  }

  Query<Map<String, dynamic>> _recentGroupsQuery(int limit) => _firestore
      .collection('groups')
      .where('status', isEqualTo: GroupStatus.active.name)
      .orderBy('lastActivityAt', descending: true)
      .orderBy(FieldPath.documentId, descending: true)
      .limit(limit);

  Query<Map<String, dynamic>> _prefixQuery(
    String field,
    String normalizedQuery,
    int limit,
  ) => _firestore
      .collection('groups')
      .where('status', isEqualTo: GroupStatus.active.name)
      .where(field, isGreaterThanOrEqualTo: normalizedQuery)
      .where(
        field,
        isLessThan: '$normalizedQuery$_prefixUpperBoundSuffix',
      )
      .orderBy(field)
      .orderBy(FieldPath.documentId)
      .limit(limit);

  GroupDocumentDto _document(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => GroupDocumentDto(
    id: snapshot.id,
    data: Map<String, Object?>.from(snapshot.data() ?? const {}),
  );

  StreamTransformer<T, T> _errorTransformer<T>() =>
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          sink.addError(_mapError(error), stackTrace);
        },
      );
}

GroupReadException _mapError(Object error) {
  if (error is GroupContractException) {
    return const GroupReadException(GroupReadFailureType.contract);
  }
  if (error is FirebaseException) {
    return GroupReadException(
      switch (error.code) {
        'permission-denied' => GroupReadFailureType.permissionDenied,
        'unavailable' ||
        'deadline-exceeded' ||
        'aborted' ||
        'failed-precondition' =>
          GroupReadFailureType.unavailable,
        _ => GroupReadFailureType.unknown,
      },
    );
  }
  return const GroupReadException(GroupReadFailureType.unknown);
}
