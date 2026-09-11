import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

import '../../domain/repositories/character_minimum_display_sync_gateway.dart';

class FirestoreCharacterMinimumDisplaySyncGateway
    implements CharacterMinimumDisplaySyncGateway {
  const FirestoreCharacterMinimumDisplaySyncGateway({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<bool> syncMinimumDisplay(CharacterMinimumDisplayPatch patch) async {
    if (!patch.hasValues) return false;
    final serverCharacterId = patch.serverCharacterId.trim();
    if (serverCharacterId.isEmpty || serverCharacterId.contains('/')) {
      throw ArgumentError('Invalid character id.');
    }
    if (patch.itemLevel != null &&
        (!patch.itemLevel!.isFinite || patch.itemLevel! < 0)) {
      throw ArgumentError('Invalid item level.');
    }
    if (patch.combatPower != null &&
        (!patch.combatPower!.isFinite || patch.combatPower! < 0)) {
      throw ArgumentError('Invalid combat power.');
    }

    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Signed-in user required.');
    }

    return _firestore.runTransaction<bool>((transaction) async {
      final binding = await transaction.get(
        _firestore.collection('authBindings').doc(uid),
      );
      final playerId = binding.data()?['playerId'];
      if (binding.data()?['status'] != 'active' ||
          playerId is! String ||
          playerId.isEmpty) {
        throw StateError('Active player binding required.');
      }
      final player = await transaction.get(
        _firestore.collection('players').doc(playerId),
      );
      if (player.data()?['status'] != 'active') {
        throw StateError('Active player required.');
      }
      final ref = _firestore.collection('characters').doc(serverCharacterId);
      final character = await transaction.get(ref);
      final data = character.data();
      final accountId = data?['gameAccountId'];
      if (data?['status'] != 'active' ||
          data?['ownerPlayerId'] != playerId ||
          accountId is! String ||
          accountId.isEmpty) {
        throw StateError('Active character ownership required.');
      }
      final ownership = await transaction.get(
        _firestore
            .collection('playerGameAccounts')
            .doc('${playerId}_$accountId'),
      );
      if (ownership.data()?['status'] != 'active') {
        throw StateError('Active account ownership required.');
      }

      final updates = <String, Object?>{};
      final itemLevel = patch.itemLevel;
      if (itemLevel != null &&
          !_sameItemLevel(data?['itemAvgLevel'], itemLevel)) {
        updates['itemAvgLevel'] = _formatItemAvgLevel(itemLevel);
      }
      final combatPower = patch.combatPower;
      if (combatPower != null && data?['combatPower'] != combatPower) {
        updates['combatPower'] = combatPower;
      }
      final integrityUpdate = _integrityUpdate(
        existingRaw: data?['buildIntegritySnapshot'],
        next: patch.buildIntegritySnapshot,
      );
      if (integrityUpdate != null) {
        updates['buildIntegritySnapshot'] = integrityUpdate;
      }
      if (updates.isEmpty) return false;
      updates['updatedAt'] = FieldValue.serverTimestamp();
      transaction.update(ref, updates);
      return true;
    });
  }

  static Map<String, Object?>? _integrityUpdate({
    required Object? existingRaw,
    required BuildIntegritySnapshot? next,
  }) {
    if (next == null) {
      return null;
    }
    try {
      final existing = BuildIntegritySnapshot.tryFromFields(
        existingRaw,
        parseDate: _parseDate,
      );
      if (existing != null &&
          existing.checkedAt.isAfter(next.checkedAt)) {
        return null;
      }
      if (existing != null && existing.hasSameValues(next)) {
        return null;
      }
      final fields = next.toFields();
      fields['checkedAt'] = Timestamp.fromDate(next.checkedAt.toUtc());
      return fields;
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDate(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.toDate().toUtc(),
      DateTime dateTime => dateTime.toUtc(),
      String text => DateTime.tryParse(text)?.toUtc(),
      _ => null,
    };
  }

  static bool _sameItemLevel(Object? existing, double next) {
    final parsed = switch (existing) {
      num value => value.toDouble(),
      String value => double.tryParse(value.replaceAll(',', '').trim()),
      _ => null,
    };
    if (parsed == null) return false;
    return (parsed - next).abs() < 0.005;
  }

  static String _formatItemAvgLevel(double value) {
    final fixed = value.toStringAsFixed(2);
    if (fixed.endsWith('.00')) {
      return fixed.substring(0, fixed.length - 3);
    }
    if (fixed.endsWith('0')) {
      return fixed.substring(0, fixed.length - 1);
    }
    return fixed;
  }
}
