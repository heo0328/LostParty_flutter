import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/completed_ownership_cleanup.dart';
import 'party_character_ownership_reader.dart';

class FirestoreCompletedOwnershipCleanupRepository
    implements CompletedOwnershipCleanupRepository {
  const FirestoreCompletedOwnershipCleanupRepository({
    required this.firestore,
    required this.auth,
  });
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  Future<String> _actor(Transaction tx) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('로그인을 확인해 주세요.');
    final binding = (await tx.get(
      firestore.collection('authBindings').doc(uid),
    )).data();
    final actor = binding?['playerId'];
    if (binding?['status'] != 'active' || actor is! String || actor.isEmpty) {
      throw StateError('사용자 정보를 확인할 수 없습니다.');
    }
    return actor;
  }

  Future<GameAccountOwnershipSnapshot> _authority(
    Transaction tx,
    String player,
    String character,
  ) async {
    final data = (await tx.get(
      firestore.collection('characters').doc(character),
    )).data();
    return PartyCharacterOwnershipReader.read(
      transaction: tx,
      firestore: firestore,
      playerId: player,
      character: data,
    );
  }

  Future<CompletedOwnershipCleanup> _inspect(
    Transaction tx,
    String roomId,
    String targetId,
    String actorId,
    Map<String, dynamic> room,
    String eventId,
  ) async {
    final slots = List<Map<String, dynamic>>.from(room['partySlots'] as List);
    final ti = slots.indexWhere((s) => s['playerId'] == targetId);
    final ai = slots.indexWhere((s) => s['playerId'] == actorId);
    if (ti < 0 ||
        ai < 0 ||
        targetId == room['leaderPlayerId'] ||
        (actorId != targetId && actorId != room['leaderPlayerId'])) {
      throw StateError('본인 또는 현재 공대장만 일반 참가자를 확인할 수 있습니다.');
    }
    final target = slots[ti];
    final characterId = target['characterId'] as String;
    final member = (await tx.get(
      firestore
          .collection('recruitments')
          .doc(roomId)
          .collection('members')
          .doc(targetId),
    )).data();
    if (member == null ||
        member['playerId'] != targetId ||
        member['characterId'] != characterId ||
        (member.containsKey('ownershipRevision')
                ? member['ownershipRevision']
                : 0) !=
            (target.containsKey('ownershipRevision')
                ? target['ownershipRevision']
                : 0)) {
      throw StateError('참가 기록을 확인할 수 없습니다. 다시 조회해 주세요.');
    }
    final authority = await _authority(tx, targetId, characterId);
    if (!CompletedOwnershipCleanup.isStale(
      authority,
      target.containsKey('ownershipRevision') ? target['ownershipRevision'] : 0,
    )) {
      throw StateError('소유권 상실이 확인되지 않아 정리하지 않습니다.');
    }
    if (actorId != targetId) {
      final actor = slots[ai];
      final current = await _authority(
        tx,
        actorId,
        actor['characterId'] as String,
      );
      if (current.classifyParticipation(actor) !=
          GameAccountOwnershipCondition.current) {
        throw StateError('현재 공대장 참가 자격을 확인할 수 없습니다.');
      }
    }
    final observation = CompletedOwnershipCleanup(
      roomId: roomId,
      actorId: actorId,
      targetId: targetId,
      characterId: characterId,
      revision: room['revision'] as int,
      targetIndex: ti,
      actorIndex: ai,
      observedRevision: authority.revision!,
      memberUpdatedAt: member['updatedAt'],
      eventId: eventId,
    );
    observation.patch(
      room,
      FieldValue.serverTimestamp(),
    ); // Validate the supported transition before confirmation.
    return observation;
  }

  @override
  Future<CompletedOwnershipCleanup> inspect(String roomId, String targetId) =>
      firestore.runTransaction((tx) async {
        final actor = await _actor(tx);
        final room = (await tx.get(
          firestore.collection('recruitments').doc(roomId),
        )).data();
        if (room == null) throw StateError('모집을 찾을 수 없습니다.');
        return _inspect(
          tx,
          roomId,
          targetId,
          actor,
          room,
          firestore.collection('partyEvents').doc().id,
        );
      });

  @override
  Future<void> execute(CompletedOwnershipCleanup observation) =>
      firestore.runTransaction((tx) async {
        final actor = await _actor(tx);
        if (actor != observation.actorId) {
          throw StateError('사용자가 변경되었습니다. 다시 확인해 주세요.');
        }
        final ref = firestore
            .collection('recruitments')
            .doc(observation.roomId);
        final room = (await tx.get(ref)).data();
        if (room == null) throw StateError('모집을 찾을 수 없습니다.');
        if (room['revision'] != observation.revision) {
          final receipt = (await tx.get(
            firestore.collection('partyEvents').doc(observation.eventId),
          )).data();
          if (observation.matchesReceipt(receipt)) return;
          throw StateError('모집이 변경되었습니다. 다시 확인해 주세요.');
        }
        final latest = await _inspect(
          tx,
          observation.roomId,
          observation.targetId,
          actor,
          room,
          observation.eventId,
        );
        if (latest.characterId != observation.characterId ||
            latest.observedRevision != observation.observedRevision ||
            latest.memberUpdatedAt != observation.memberUpdatedAt ||
            latest.targetIndex != observation.targetIndex ||
            latest.actorIndex != observation.actorIndex) {
          throw StateError('확인한 참가 정보가 변경되었습니다. 다시 확인해 주세요.');
        }
        final now = FieldValue.serverTimestamp();
        final patch = observation.patch(room, now);
        tx.update(ref, patch);
        tx.delete(ref.collection('members').doc(observation.targetId));
        if (room['visibility'] == 'group') {
          tx.update(
            firestore
                .collection('groups')
                .doc(room['groupId'] as String)
                .collection('raidListings')
                .doc(observation.roomId),
            observation.listingPatch(patch),
          );
        }
        tx.set(
          firestore.collection('partyEvents').doc(observation.eventId),
          observation.event(room, now),
        );
      });
}
