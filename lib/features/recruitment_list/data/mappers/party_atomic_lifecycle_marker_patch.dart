import '../../domain/entities/party_atomic_command.dart';

const Map<String, Object?> _clearedLifecycleMarker = {
  'commandTargets': <Map<String, Object?>>[],
  'lastCommandId': null,
  'lastCommandType': null,
  'lastCommandActorPlayerId': null,
  'lastCommandAt': null,
};

/// Returns the marker fields that a validated non-lifecycle aggregate command
/// must consume after a lifecycle command such as `advanceCycle`.
///
/// The immutable lifecycle event remains in `partyEvents`; these fields are
/// only the latest-command envelope on the recruitment document.
Map<String, Object?> lifecycleMarkerConsumptionPatch(
  PartyCommandAggregate aggregate,
) {
  return switch (aggregate.lastCommandType) {
    PartyAtomicCommandType.complete ||
    PartyAtomicCommandType.advanceCycle ||
    PartyAtomicCommandType.incompleteEnd ||
    PartyAtomicCommandType.disband => _clearedLifecycleMarker,
    _ => const <String, Object?>{},
  };
}
