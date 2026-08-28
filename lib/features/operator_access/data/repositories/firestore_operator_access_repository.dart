import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/operator_user.dart';
import '../../domain/repositories/operator_access_repository.dart';

class FirestoreOperatorAccessRepository implements OperatorAccessRepository {
  FirestoreOperatorAccessRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _providedFirestore = firestore,
       _providedFirebaseAuth = firebaseAuth;

  final FirebaseFirestore? _providedFirestore;
  final FirebaseAuth? _providedFirebaseAuth;
  var _legacyPlayersPrepared = false;

  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;

  FirebaseAuth get _firebaseAuth =>
      _providedFirebaseAuth ?? FirebaseAuth.instance;

  @override
  Future<bool> isCurrentPlayerOperator() async {
    final playerId = await _currentPlayerId();
    if (playerId == null) return false;
    final assignment = await _firestore
        .collection('operatorAssignments')
        .doc(playerId)
        .get();
    return assignment.exists && assignment.data()?['status'] == 'active';
  }

  @override
  Future<List<OperatorUserSummary>> loadUsers({int limit = 50}) async {
    await _requireOperator();
    await _prepareLegacyPlayers();
    final players = await _firestore
        .collection('players')
        .orderBy('lastSeenAt')
        .limit(limit)
        .get();
    final playerIds = players.docs.map((document) => document.id).toList();
    final verifiedPlayerIds = await _verifiedPlayerIds(playerIds);
    return players.docs
        .map(
          (document) => _mapUser(
            document,
            hasVerifiedGameAccount: verifiedPlayerIds.contains(document.id),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<OperatorUserDetail?> loadUserDetail(String playerId) async {
    await _requireOperator();
    final player = await _firestore.collection('players').doc(playerId).get();
    if (!player.exists) return null;

    final ownerships = await _firestore
        .collection('playerGameAccounts')
        .where('playerId', isEqualTo: playerId)
        .get();
    final characters = await _firestore
        .collection('characters')
        .where('ownerPlayerId', isEqualTo: playerId)
        .get();
    final charactersByAccount = <String, List<OperatorCharacterSummary>>{};
    for (final character in characters.docs) {
      final data = character.data();
      final gameAccountId = data['gameAccountId'];
      if (gameAccountId is! String || gameAccountId.isEmpty) continue;
      charactersByAccount
          .putIfAbsent(gameAccountId, () => [])
          .add(
            OperatorCharacterSummary(
              characterId: character.id,
              characterName: _string(data['characterName']) ?? '이름 없음',
              serverName: _string(data['serverName']) ?? '서버 미확인',
              className: _string(data['characterClassName']) ?? '직업 미확인',
              status: _string(data['status']) ?? 'unknown',
            ),
          );
    }

    final accounts = <OperatorGameAccountSummary>[];
    for (final ownership in ownerships.docs) {
      final ownershipData = ownership.data();
      final gameAccountId = ownershipData['gameAccountId'];
      if (gameAccountId is! String || gameAccountId.isEmpty) continue;
      final account = await _firestore
          .collection('gameAccounts')
          .doc(gameAccountId)
          .get();
      final accountData = account.data();
      accounts.add(
        OperatorGameAccountSummary(
          gameAccountId: gameAccountId,
          status: _string(accountData?['status']) ?? 'unknown',
          ownershipStatus: _string(ownershipData['status']) ?? 'unknown',
          lookupCharacterName: _string(accountData?['lookupCharacterName']),
          characters: List.unmodifiable(
            charactersByAccount[gameAccountId] ?? const [],
          ),
        ),
      );
    }
    accounts.sort((left, right) {
      final leftName = left.lookupCharacterName ?? '';
      final rightName = right.lookupCharacterName ?? '';
      return leftName.compareTo(rightName);
    });

    return OperatorUserDetail(
      user: _mapUser(
        player,
        hasVerifiedGameAccount: ownerships.docs.any(
          (document) => document.data()['status'] == 'active',
        ),
      ),
      gameAccounts: List.unmodifiable(accounts),
    );
  }

  Future<void> _requireOperator() async {
    if (!await isCurrentPlayerOperator()) {
      throw StateError('Active operator assignment is required.');
    }
  }

  Future<String?> _currentPlayerId() async {
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null) return null;
    final binding = await _firestore
        .collection('authBindings')
        .doc(authUid)
        .get();
    final data = binding.data();
    final playerId = data?['playerId'];
    if (!binding.exists ||
        data?['status'] != 'active' ||
        playerId is! String ||
        playerId.isEmpty) {
      return null;
    }
    return playerId;
  }

  Future<void> _prepareLegacyPlayers() async {
    if (_legacyPlayersPrepared) return;
    final snapshot = await _firestore.collection('players').get();
    final missing = snapshot.docs
        .where((document) => !document.data().containsKey('lastSeenAt'))
        .toList(growable: false);
    for (var start = 0; start < missing.length; start += 450) {
      final batch = _firestore.batch();
      final end = (start + 450).clamp(0, missing.length);
      for (final document in missing.sublist(start, end)) {
        batch.update(document.reference, {'lastSeenAt': null});
      }
      await batch.commit();
    }
    _legacyPlayersPrepared = true;
  }

  Future<Set<String>> _verifiedPlayerIds(List<String> playerIds) async {
    final result = <String>{};
    for (var start = 0; start < playerIds.length; start += 30) {
      final end = (start + 30).clamp(0, playerIds.length);
      final ids = playerIds.sublist(start, end);
      if (ids.isEmpty) continue;
      final ownerships = await _firestore
          .collection('playerGameAccounts')
          .where('playerId', whereIn: ids)
          .where('status', isEqualTo: 'active')
          .get();
      result.addAll(
        ownerships.docs
            .map((document) => document.data()['playerId'])
            .whereType<String>(),
      );
    }
    return result;
  }

  OperatorUserSummary _mapUser(
    DocumentSnapshot<Map<String, dynamic>> document, {
    required bool hasVerifiedGameAccount,
  }) {
    final data = document.data() ?? const <String, dynamic>{};
    return OperatorUserSummary(
      playerId: document.id,
      status: _string(data['status']) ?? 'unknown',
      createdAt: _dateTime(data['createdAt']),
      lastSeenAt: _dateTime(data['lastSeenAt']),
      hasVerifiedGameAccount: hasVerifiedGameAccount,
      representativeCharacterName: null,
    );
  }

  DateTime? _dateTime(Object? value) =>
      value is Timestamp ? value.toDate() : null;

  String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;
}
