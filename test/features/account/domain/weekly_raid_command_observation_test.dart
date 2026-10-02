import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_claim_command.dart';

void main() {
  final state = <String, dynamic>{
    'playerId': 'p',
    'characterId': 'c',
    'raidId': 'r',
    'ownershipRevision': 3,
    'revision': 1,
    'cycleKey': 'week',
    'status': 'completed',
    'source': 'manual',
    'recruitmentId': null,
    'completedAt': 100,
    'updatedAt': 100,
  };
  WeeklyRaidCommandObservation observe({
    Map<String, dynamic>? record,
    Map<String, dynamic>? claim,
    Map<String, Map<String, dynamic>> applications = const {},
  }) => WeeklyRaidCommandObservation(
    playerId: 'p',
    characterId: 'c',
    raidId: 'r',
    cycleKey: 'week',
    ownershipRevision: 3,
    state: record,
    claim: claim,
    assignment: null,
    applications: applications,
  );
  bool matches(
    WeeklyRaidCommandObservation observation,
    Map<String, dynamic>? record, {
    int generation = 3,
    String cycle = 'week',
    Map<String, dynamic>? claim,
    bool rollover = false,
  }) => observation.matches(
    playerId: 'p',
    characterId: 'c',
    raidId: 'r',
    cycleKey: cycle,
    ownershipRevision: generation,
    state: record,
    claim: claim,
    assignment: null,
    afterHistoricalDelete: rollover,
  );

  test(
    'delayed cancellation cannot erase recreated completion or reacquired ownership',
    () {
      final observation = observe(record: state);
      expect(matches(observation, Map.of(state)), isTrue);
      expect(
        matches(observation, {...state, 'updatedAt': 200, 'completedAt': 200}),
        isFalse,
      );
      expect(matches(observation, state, generation: 5), isFalse);
      expect(matches(observation, state, cycle: 'next-week'), isFalse);
      expect(matches(observation, null), isFalse);
    },
  );
  test(
    'confirmation does not authorize a newly joined room or changed claim',
    () {
      final observation = observe(record: state);
      expect(
        matches(observation, {
          ...state,
          'recruitmentId': 'new-room',
          'status': 'active',
        }),
        isFalse,
      );
      expect(matches(observation, state, claim: state), isFalse);
      expect(matches(observe(), state), isFalse);
    },
  );
  test(
    'historical deletion retry accepts absence only with unchanged authority and other records',
    () {
      final observation = observe(record: state);
      expect(matches(observation, null, rollover: true), isTrue);
      expect(matches(observation, state, rollover: true), isFalse);
      expect(
        matches(observation, null, rollover: true, generation: 5),
        isFalse,
      );
      expect(matches(observation, null, rollover: true, claim: state), isFalse);
    },
  );
  test(
    'pending cleanup preserves a reapplication and freezes observed versions',
    () {
      final application = <String, dynamic>{
        'applicantPlayerId': 'p',
        'characterId': 'c',
        'ownershipRevision': 3,
        'revision': 2,
        'status': 'pending',
        'updatedAt': 100,
      };
      final observation = observe(
        applications: {'room/applications/p': application},
      );
      expect(
        observation.matchesApplication('room/applications/p', application),
        isTrue,
      );
      expect(
        observation.matchesApplication('other/applications/p', application),
        isFalse,
      );
      application['revision'] = 4;
      expect(
        observation.matchesApplication('room/applications/p', application),
        isFalse,
      );
      expect(
        () => observation.applicationVersions.clear(),
        throwsUnsupportedError,
      );
    },
  );
}
