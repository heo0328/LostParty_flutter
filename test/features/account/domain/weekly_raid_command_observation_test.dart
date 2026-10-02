import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_claim_command.dart';

void main() {
  test(
    'orphan cleanup preserves replaced records and permits only absent-pair retry',
    () {
      final state = <String, dynamic>{
        'revision': 7,
        'cycleKey': 'old-week',
        'recruitmentId': 'old-room',
        'updatedAt': 100,
      };
      final assignment = <String, dynamic>{...state};
      final observed = WeeklyRaidCommandObservation(
        playerId: 'p',
        characterId: 'c',
        raidId: 'r',
        cycleKey: 'new-week',
        ownershipRevision: 3,
        state: state,
        assignment: assignment,
        claim: null,
      );
      bool matches(
        Map<String, dynamic>? s,
        Map<String, dynamic>? a, {
        int generation = 3,
      }) => observed.matchesCleanup(
        playerId: 'p',
        characterId: 'c',
        raidId: 'r',
        ownershipRevision: generation,
        state: s,
        assignment: a,
      );
      expect(matches(state, assignment), isTrue);
      expect(
        matches({...state, 'recruitmentId': 'new-room'}, assignment),
        isFalse,
      );
      expect(matches(state, {...assignment, 'updatedAt': 200}), isFalse);
      expect(matches(state, assignment, generation: 5), isFalse);
      expect(matches(null, assignment), isFalse);
      expect(matches(state, null), isFalse);
      expect(matches(null, null), isTrue);
      expect(matches(null, null, generation: 5), isFalse);
      expect(
        observed.matchesCleanup(
          playerId: 'other',
          characterId: 'c',
          raidId: 'r',
          ownershipRevision: 3,
          state: null,
          assignment: null,
        ),
        isFalse,
      );
    },
  );
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
