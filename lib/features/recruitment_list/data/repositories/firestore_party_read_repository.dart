import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/party_read_models.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/entities/recruitment_application.dart';
import '../../domain/repositories/party_read_repository.dart';
import '../dto/party_read_document_dto.dart';
import '../mappers/party_read_document_mapper.dart';

/// 목록이 비어 있으면 캐시에서 서버로 바뀌는 변화가 메타데이터뿐이라
/// `includeMetadataChanges` 없이는 오프라인 표시가 갱신되지 않는다.
class FirestorePartyReadRepository implements PartyReadRepository {
  FirestorePartyReadRepository({required FirebaseFirestore firestore})
    : _firestore = firestore,
      _mapper = PartyReadDocumentMapper(
        toDateTime: (value) => switch (value) {
          Timestamp timestamp => timestamp.toDate(),
          DateTime dateTime => dateTime,
          _ => throw const FormatException('Expected Firestore Timestamp.'),
        },
      );

  final FirebaseFirestore _firestore;
  final PartyReadDocumentMapper _mapper;

  @override
  Stream<PartyReadSnapshot<PublicRecruitmentSummary>>
  watchPublicRecruitments({required String cycleKey}) {
    return _firestore
        .collection('recruitments')
        .where('schemaVersion', isEqualTo: 1)
        .where('visibility', isEqualTo: 'public')
        .where('status', isEqualTo: 'active')
        .where('manualRecruitmentEnabled', isEqualTo: true)
        .where('hasAvailableSlot', isEqualTo: true)
        .where('targetCycleKey', isEqualTo: cycleKey)
        .orderBy('updatedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => PartyReadSnapshot(
            items: snapshot.docs
                .map(_document)
                .map(_mapper.toPublicRecruitment)
                .toList(growable: false),
            isFromCache: snapshot.metadata.isFromCache,
          ),
        )
        .transform(_errorTransformer());
  }

  @override
  Stream<PartyReadSnapshot<ActiveRaidSummary>> watchActiveRaids({
    required String playerId,
  }) {
    final owned = _firestore
        .collection('recruitments')
        .where('schemaVersion', isEqualTo: 1)
        .where('leaderPlayerId', isEqualTo: playerId)
        .where('status', isEqualTo: 'active')
        .snapshots(includeMetadataChanges: true);
    final joined = _firestore
        .collection('recruitments')
        .where('schemaVersion', isEqualTo: 1)
        .where('memberPlayerIds', arrayContains: playerId)
        .where('status', isEqualTo: 'active')
        .snapshots(includeMetadataChanges: true);

    return _combineActiveQueries(
      owned,
      joined,
      playerId,
    ).transform(_errorTransformer());
  }

  @override
  Stream<PartyReadSnapshot<PartyApplicationSummary>> watchApplications({
    required String playerId,
    required String cycleKey,
  }) {
    return _firestore
        .collectionGroup('applications')
        .where('schemaVersion', isEqualTo: 1)
        .where('applicantPlayerId', isEqualTo: playerId)
        .where('cycleKey', isEqualTo: cycleKey)
        .orderBy('updatedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => PartyReadSnapshot(
            items: snapshot.docs
                .map(_document)
                .map(_mapper.toApplication)
                .where(
                  (application) =>
                      application.status !=
                      RecruitmentApplicationStatus.approved,
                )
                .toList(growable: false),
            isFromCache: snapshot.metadata.isFromCache,
          ),
        )
        .transform(_errorTransformer());
  }

  @override
  Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>> watchRecruitment(
    String recruitmentId,
  ) {
    return _firestore
        .collection('recruitments')
        .doc(recruitmentId)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => PartyReadDetailSnapshot(
            item: snapshot.exists
                ? _mapper.toPublicRecruitment(_document(snapshot))
                : null,
            isFromCache: snapshot.metadata.isFromCache,
          ),
        )
        .transform(_errorTransformer());
  }

  Stream<PartyReadSnapshot<ActiveRaidSummary>> _combineActiveQueries(
    Stream<QuerySnapshot<Map<String, dynamic>>> owned,
    Stream<QuerySnapshot<Map<String, dynamic>>> joined,
    String playerId,
  ) {
    late StreamController<PartyReadSnapshot<ActiveRaidSummary>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ownedSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? joinedSubscription;
    QuerySnapshot<Map<String, dynamic>>? latestOwned;
    QuerySnapshot<Map<String, dynamic>>? latestJoined;

    void emit() {
      final ownedSnapshot = latestOwned;
      final joinedSnapshot = latestJoined;
      if (ownedSnapshot == null || joinedSnapshot == null) return;

      try {
        final byId = <String, ActiveRaidSummary>{};
        for (final document in [...ownedSnapshot.docs, ...joinedSnapshot.docs]) {
          byId[document.id] = _mapper.toActiveRaid(
            _document(document),
            currentPlayerId: playerId,
          );
        }
        final items = byId.values.toList(growable: false)
          ..sort(_compareActiveRaids);
        controller.add(
          PartyReadSnapshot(
            items: items,
            isFromCache:
                ownedSnapshot.metadata.isFromCache ||
                joinedSnapshot.metadata.isFromCache,
          ),
        );
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<PartyReadSnapshot<ActiveRaidSummary>>(
      onListen: () {
        ownedSubscription = owned.listen(
          (snapshot) {
            latestOwned = snapshot;
            emit();
          },
          onError: controller.addError,
        );
        joinedSubscription = joined.listen(
          (snapshot) {
            latestJoined = snapshot;
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await ownedSubscription?.cancel();
        await joinedSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  PartyReadDocumentDto _document(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => PartyReadDocumentDto(
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

PartyReadException _mapError(Object error) {
  if (error is PartyReadContractException) {
    return const PartyReadException(PartyReadFailureType.contract);
  }
  if (error is FirebaseException) {
    return PartyReadException(
      switch (error.code) {
        'permission-denied' => PartyReadFailureType.permissionDenied,
        'unavailable' => PartyReadFailureType.unavailable,
        _ => PartyReadFailureType.unknown,
      },
    );
  }
  return const PartyReadException(PartyReadFailureType.unknown);
}

int _compareActiveRaids(ActiveRaidSummary left, ActiveRaidSummary right) {
  final leftStart = left.raidStartAt;
  final rightStart = right.raidStartAt;
  if (leftStart != null && rightStart != null) {
    final byStart = leftStart.compareTo(rightStart);
    if (byStart != 0) return byStart;
  } else if (leftStart != null) {
    return -1;
  } else if (rightStart != null) {
    return 1;
  }
  final byUpdated = right.updatedAt.compareTo(left.updatedAt);
  return byUpdated != 0 ? byUpdated : left.id.compareTo(right.id);
}
