import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/active_raid_assignment_repository.dart';
import '../../domain/services/party_create_occupancy_gate.dart';
import 'party_character_ownership_reader.dart';
import 'party_raid_state_occupancy_inspector.dart';

class FirestoreActiveRaidAssignmentLookup
    implements ActiveRaidAssignmentLookup {
  const FirestoreActiveRaidAssignmentLookup({
    required FirebaseFirestore firestore,
    this.clock = DateTime.now,
  }) : _firestore = firestore;
  final FirebaseFirestore _firestore;
  final DateTime Function() clock;

  @override
  Future<bool> blocksCandidate({
    required String playerId,
    required String characterId,
    required String raidId,
    required String cycleKey,
  }) => _firestore.runTransaction((transaction) async {
    final character = await transaction.get(
      _firestore.collection('characters').doc(characterId),
    );
    final ownership = await PartyCharacterOwnershipReader.read(
      transaction: transaction,
      firestore: _firestore,
      playerId: playerId,
      character: character.data(),
    );
    if (ownership.condition != GameAccountOwnershipCondition.current) {
      throw const FormatException('Candidate ownership is not current.');
    }
    final occupancy = await PartyRaidStateOccupancyInspector.inspect(
      transaction: transaction,
      firestore: _firestore,
      playerId: playerId,
      characterId: characterId,
      raidId: raidId,
      requestedCycleKey: cycleKey,
      now: clock(),
      ownership: ownership,
    );
    return switch (occupancy.decision) {
      null ||
      ExistingRaidStateOccupancyDecision.historicalCompleted ||
      ExistingRaidStateOccupancyDecision.currentOrphanActive ||
      ExistingRaidStateOccupancyDecision.historicalOrphanActive => false,
      ExistingRaidStateOccupancyDecision.inconsistent =>
        throw const FormatException('Candidate occupancy is inconsistent.'),
      _ => true,
    };
  });
}
