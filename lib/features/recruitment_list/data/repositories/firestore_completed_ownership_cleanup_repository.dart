import '../mappers/party_raid_listing_document.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/completed_ownership_cleanup.dart';
import 'party_character_ownership_reader.dart';
import 'completed_cleanup_journal.dart';

class FirestoreCompletedOwnershipCleanupRepository
    implements CompletedOwnershipCleanupRepository {
  const FirestoreCompletedOwnershipCleanupRepository({
    required this.firestore,
    required this.auth,
    this.journal = const CompletedCleanupJournal(),
  });
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final CompletedCleanupJournal journal;

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
    if (ti < 0 || ai < 0) {
      throw StateError('기존 참가자만 참가 자격을 확인할 수 있습니다.');
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
    final leaderTarget = targetId == room['leaderPlayerId'];
    final lastMember = leaderTarget && slots.length == 1;
    var kind = lastMember
        ? CompletedCleanupKind.disband
        : leaderTarget
        ? CompletedCleanupKind.leader
        : CompletedCleanupKind.participant;
    int? leaderIndex, leaderRevision, successorIndex;
    String? successorId, successorName, successorClass;
    Object? successorUpdatedAt;
    if (actorId != targetId || (leaderTarget && !lastMember)) {
      final actor = slots[ai];
      final current = await _authority(
        tx,
        actorId,
        actor['characterId'] as String,
      );
      if (current.classifyParticipation(actor) !=
          GameAccountOwnershipCondition.current) {
        throw StateError('요청자의 현재 참가 자격을 확인할 수 없습니다.');
      }
    }
    if (!leaderTarget &&
        actorId != targetId &&
        actorId != room['leaderPlayerId']) {
      kind = CompletedCleanupKind.peer;
      leaderIndex = slots.indexWhere(
        (s) => s['playerId'] == room['leaderPlayerId'],
      );
      if (leaderIndex < 0) throw StateError('공대장 정보를 확인할 수 없습니다.');
      final leader = slots[leaderIndex];
      final leaderAuthority = await _authority(
        tx,
        leader['playerId'] as String,
        leader['characterId'] as String,
      );
      if (!CompletedOwnershipCleanup.isStale(
        leaderAuthority,
        leader.containsKey('ownershipRevision')
            ? leader['ownershipRevision']
            : 0,
      )) {
        throw StateError('공대장 자격이 유지되거나 확인되지 않아 다른 참가자를 정리할 수 없습니다.');
      }
      leaderRevision = leaderAuthority.revision;
    }
    if (leaderTarget && !lastMember) {
      successorIndex = ti == 0 ? 1 : 0;
      final successor = slots[successorIndex];
      successorId = successor['playerId'] as String;
      final successorAuthority = await _authority(
        tx,
        successorId,
        successor['characterId'] as String,
      );
      if (successorAuthority.classifyParticipation(successor) !=
          GameAccountOwnershipCondition.current) {
        throw StateError(
          '첫 후임의 참가 자격을 확인할 수 없습니다. 앞순번의 무효 참가자를 먼저 확인·정리해 주세요.',
        );
      }
      final nextMember = (await tx.get(
        firestore
            .collection('recruitments')
            .doc(roomId)
            .collection('members')
            .doc(successorId),
      )).data();
      if (nextMember == null ||
          nextMember['playerId'] != successorId ||
          nextMember['characterId'] != successor['characterId'] ||
          successorAuthority.classifyParticipation(nextMember) !=
              GameAccountOwnershipCondition.current ||
          nextMember['characterNameSnapshot'] is! String ||
          nextMember['classNameSnapshot'] is! String) {
        throw StateError('후임 참가 기록을 확인할 수 없습니다.');
      }
      successorName = nextMember['characterNameSnapshot'] as String;
      successorClass = nextMember['classNameSnapshot'] as String;
      successorUpdatedAt = nextMember['updatedAt'];
    }
    final observation = CompletedOwnershipCleanup(
      targetName: member['characterNameSnapshot'] as String?,
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
      kind: kind,
      leaderIndex: leaderIndex,
      observedLeaderRevision: leaderRevision,
      successorIndex: successorIndex,
      successorId: successorId,
      successorName: successorName,
      successorClass: successorClass,
      successorUpdatedAt: successorUpdatedAt,
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
  Future<List<CompletedOwnershipCleanup>> pending(String actorId) =>
      journal.pending(actorId);

  @override
  Future<void> forget(CompletedOwnershipCleanup observation) =>
      journal.remove(observation);

  @override
  Future<void> retry(CompletedOwnershipCleanup observation) async {
    final actor = await firestore.runTransaction(_actor);
    if (actor != observation.actorId) throw StateError('사용자가 변경되었습니다.');
    // A removed member may no longer read the room, but keeps event audience access.
    Map<String, dynamic>? receipt;
    try {
      receipt =
          (await firestore
                  .collection('partyEvents')
                  .doc(observation.eventId)
                  .get(const GetOptions(source: Source.server)))
              .data();
    } on FirebaseException catch (error) {
      // A non-existent event can be denied by resource-based read rules.
      // This is not success: retry the original, fully validated transaction.
      if (error.code != 'permission-denied') rethrow;
    }
    if (receipt != null) {
      if (!observation.matchesReceipt(receipt)) {
        throw StateError('저장된 요청과 처리 결과가 다릅니다. 다시 확인해 주세요.');
      }
      await journal.remove(observation);
      return;
    }
    await execute(observation);
  }

  @override
  Future<void> execute(CompletedOwnershipCleanup observation) =>
      journal.run(observation, () => _execute(observation));

  Future<void> _execute(
    CompletedOwnershipCleanup observation,
  ) => firestore.runTransaction((tx) async {
    final actor = await _actor(tx);
    if (actor != observation.actorId) {
      throw StateError('사용자가 변경되었습니다. 다시 확인해 주세요.');
    }
    final ref = firestore.collection('recruitments').doc(observation.roomId);
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
        latest.actorIndex != observation.actorIndex ||
        latest.kind != observation.kind ||
        latest.leaderIndex != observation.leaderIndex ||
        latest.observedLeaderRevision != observation.observedLeaderRevision ||
        latest.successorId != observation.successorId ||
        latest.successorIndex != observation.successorIndex ||
        latest.successorUpdatedAt != observation.successorUpdatedAt ||
        latest.successorName != observation.successorName ||
        latest.successorClass != observation.successorClass) {
      throw StateError('확인한 참가 정보가 변경되었습니다. 다시 확인해 주세요.');
    }
    final now = FieldValue.serverTimestamp();
    final patch = observation.patch(room, now);
    if (observation.kind == CompletedCleanupKind.disband) {
      final groupId = room['groupId'];
      if (groupId is String && groupId.isNotEmpty) {
        final groupRef = firestore.collection('groups').doc(groupId);
        final group = (await tx.get(groupRef)).data();
        final count = group?['activeRecruitmentCount'];
        final revision = group?['revision'];
        if (count is! int || count < 1 || revision is! int) {
          throw StateError('그룹 모집 정보를 확인할 수 없습니다.');
        }
        patch['groupActiveRecruitmentCountAfter'] = count - 1;
        tx.update(groupRef, {
          'activeRecruitmentCount': count - 1,
          'lastRecruitmentId': observation.roomId,
          'revision': revision + 1,
          'updatedAt': now,
        });
        tx.delete(groupRef.collection('raidListings').doc(observation.roomId));
      }
      tx.update(ref, patch);
      tx.set(
        firestore.collection('partyEvents').doc(observation.eventId),
        observation.event(room, now),
      );
      return;
    }
    tx.update(ref, patch);
    tx.delete(ref.collection('members').doc(observation.targetId));
    if (observation.kind == CompletedCleanupKind.leader) {
      tx.update(ref.collection('members').doc(observation.successorId), {
        'canApproveApplications': true,
        'updatedAt': now,
      });
    }
    if (room['visibility'] == 'group') {
      tx.set(
        firestore
            .collection('groups')
            .doc(room['groupId'] as String)
            .collection('raidListings')
            .doc(observation.roomId),
        partyRaidListingDocument(
          currentRecruitment: room,
          recruitmentPatch: patch,
        ),
      );
    }
    tx.set(
      firestore.collection('partyEvents').doc(observation.eventId),
      observation.event(room, now),
    );
  });
}
