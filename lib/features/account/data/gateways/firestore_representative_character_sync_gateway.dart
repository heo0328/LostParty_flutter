import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/representative_character_sync_gateway.dart';

class FirestoreRepresentativeCharacterSyncGateway
    implements RepresentativeCharacterSyncGateway {
  FirestoreRepresentativeCharacterSyncGateway({
    FirebaseFirestore? firestore,
    required this.playerId,
    DateTime Function()? clock,
  }) : _providedFirestore = firestore,
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore? _providedFirestore;
  final String playerId;
  final DateTime Function() _clock;

  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<RepresentativeCharacterSyncState> loadState({
    required String gameAccountId,
  }) async {
    final snapshot = await _ownershipReference(
      gameAccountId,
    ).get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    _requireActiveOwnership(data, gameAccountId);
    return _mapState(data!);
  }

  @override
  Future<RepresentativeCharacterSyncState> setRepresentative({
    required String gameAccountId,
    required String characterId,
  }) async {
    final now = _clock().toUtc();
    final ownershipReference = _ownershipReference(gameAccountId);
    return _firestore.runTransaction((transaction) async {
      final ownership = await transaction.get(ownershipReference);
      final ownershipData = ownership.data();
      _requireActiveOwnership(ownershipData, gameAccountId);

      final current = _string(ownershipData?['representativeCharacterId']);
      if (current == characterId) return _mapState(ownershipData!);
      final updatedAt = _dateTime(
        ownershipData?['representativeCharacterUpdatedAt'],
      );
      if (updatedAt != null &&
          updatedAt
              .add(RepresentativeCharacterSyncState.cooldown)
              .isAfter(now)) {
        throw const RepresentativeCharacterSyncException(
          '대표 캐릭터는 계정별로 5분에 한 번만 변경할 수 있습니다.',
        );
      }

      final character = await transaction.get(
        _firestore.collection('characters').doc(characterId),
      );
      final characterData = character.data();
      if (!character.exists ||
          characterData?['ownerPlayerId'] != playerId ||
          characterData?['gameAccountId'] != gameAccountId ||
          characterData?['status'] != 'active') {
        throw const RepresentativeCharacterSyncException(
          '같은 인증 계정의 활성 캐릭터만 대표로 지정할 수 있습니다.',
        );
      }

      transaction.update(ownershipReference, {
        'representativeCharacterId': characterId,
        'representativeCharacterUpdatedAt': FieldValue.serverTimestamp(),
      });
      return RepresentativeCharacterSyncState(
        representativeCharacterId: characterId,
        updatedAt: now,
      );
    });
  }

  DocumentReference<Map<String, dynamic>> _ownershipReference(
    String gameAccountId,
  ) => _firestore
      .collection('playerGameAccounts')
      .doc('${playerId}_$gameAccountId');

  void _requireActiveOwnership(
    Map<String, dynamic>? data,
    String gameAccountId,
  ) {
    if (data == null ||
        data['playerId'] != playerId ||
        data['gameAccountId'] != gameAccountId ||
        data['status'] != 'active') {
      throw const RepresentativeCharacterSyncException(
        '활성 인증 계정 정보를 확인할 수 없습니다.',
      );
    }
  }

  RepresentativeCharacterSyncState _mapState(Map<String, dynamic> data) {
    return RepresentativeCharacterSyncState(
      representativeCharacterId: _string(data['representativeCharacterId']),
      updatedAt: _dateTime(data['representativeCharacterUpdatedAt']),
    );
  }

  DateTime? _dateTime(Object? value) =>
      value is Timestamp ? value.toDate().toUtc() : null;

  String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;
}
