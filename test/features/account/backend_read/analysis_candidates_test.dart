import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/analysis_candidates.dart';
import 'package:lost_party/features/account/data/account_bootstrap.dart';
import 'package:lost_party/features/account/domain/scoped_startup_refresh.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/shared/backend/server_analysis_wire.dart';
import 'account_bootstrap_test.dart' as fixtures;

Map<String, dynamic> projection(Map<String, dynamic> reg) => {
  'policy_version': 'analysis-candidates-1',
  'policy_revision': 1,
  'baseline': 'observed',
  'registration_id': reg['registration_id'],
  'game_account_id': reg['game_account_id'],
  'ownership_revision': reg['ownership_revision'],
  'settings_version': reg['settings']['settings_version'],
  'complete': true,
  'candidates': <dynamic>[],
};

void main() {
  test(
    'selected low-level plus discovery deduplicates without changing activity and preserves exclusions',
    () {
      final b = AccountBootstrap.fromJson(
        fixtures.example(),
      ).registrations.single;
      const newId = '22222222-2222-4222-8222-222222222222';
      final c = b.characters.items.first;
      CacheCharacterObservation observation(
        String id,
        String name,
        String level,
      ) => CacheCharacterObservation(
        characterId: id,
        accountId: b.snapshot.accountId!,
        serverName: c.serverName,
        characterName: name,
        lifecycleState: c.lifecycleState,
        lifecycleRevision: c.lifecycleRevision,
        usable: c.usable,
        blockedReason: c.blockedReason,
        profile: {
          ...c.wire,
          'character_id': id,
          'character_name': name,
          'item_level': level,
        },
      );
      final roster = CacheRosterSnapshot(b.snapshot, [
        observation(c.characterId!, c.characterName, '1600'),
        observation(newId, 'new', '1700'),
      ]);
      final scope = StorageScope(
        baseUrl: 'https://example.test',
        userId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      final selected = projectScopedRefreshTargets(scope, [
        roster,
      ], niceGroupEnabled: true);
      final value = projection(
        fixtures.registration(fixtures.example())['registration'],
      );
      value['candidates'] = [
        for (final id in [c.characterId!, newId])
          {
            'candidate_id': id,
            'character_id': id,
            'generation': 1,
            'reason': 'first_threshold',
            'state': 'pending',
            'eligibility': 'eligible',
            'next_attempt_at': null,
            'last_error': null,
            'unresolved_command': null,
            'completed_at': null,
            'completed_command_id': null,
          },
      ];
      var result = mergeAnalysisCandidateTargets(
        scope,
        [roster],
        selected,
        [AnalysisCandidates(value)],
      );
      expect(result.map((t) => t.ref.characterId).toSet(), {
        c.characterId!,
        newId,
      });
      expect(result, hasLength(2));
      expect(roster.registration.settings.activityIds, [c.characterId!]);
      value['candidates'][1]['eligibility'] = 'nice_group_disabled';
      result = mergeAnalysisCandidateTargets(
        scope,
        [roster],
        selected,
        [AnalysisCandidates(value)],
      );
      expect(
        result.singleWhere((t) => t.ref.characterId == newId).exclusion,
        'NICE_GROUP_OFF',
      );
      value['candidates'][1]['state'] = 'succeeded';
      result = mergeAnalysisCandidateTargets(
        scope,
        [roster],
        selected,
        [AnalysisCandidates(value)],
      );
      expect(result.single.ref.characterId, c.characterId);
    },
  );
  test(
    'published request/response examples pass the embedded strict contract',
    () {
      final json =
          jsonDecode(
                File(
                  'test/fixtures/analysis_candidates/analysis-candidates-1.examples.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final outcome in json['outcomes'] as List) {
        ServerAnalysisWire.definition('AnalysisRequest', outcome['request']);
        ServerAnalysisWire.definition('AnalysisResponse', outcome['response']);
      }
      final retry = json['manual_retry_excluded_or_nice_off'];
      ServerAnalysisWire.definition('AnalysisRequest', retry['body']);
      ServerAnalysisWire.definition('AnalysisResponse', retry['response']);
      ServerAnalysisWire.definition(
        'AnalysisRequest',
        json['reconcile']['body'],
      );
    },
  );
  test(
    'bootstrap opt-in is explicit and binds candidate scope to the roster',
    () {
      final value = fixtures.example();
      final row = fixtures.registration(value);
      row['analysis_candidates'] = projection(row['registration']);
      expect(
        AccountBootstrap.fromJson(
          value,
          includeCandidates: true,
        ).registrations.single.candidates!.items,
        isEmpty,
      );
      expect(() => AccountBootstrap.fromJson(value), throwsFormatException);
      row['analysis_candidates']['ownership_revision']++;
      expect(
        () => AccountBootstrap.fromJson(value, includeCandidates: true),
        throwsFormatException,
      );
    },
  );
  test('candidate projection cannot hide truncation or duplicate a target', () {
    final value = projection(
      fixtures.registration(fixtures.example())['registration'],
    );
    value['complete'] = false;
    expect(() => AnalysisCandidates(value), throwsFormatException);
    value['complete'] = true;
    value['candidates'] = [
      for (var i = 0; i < 2; i++)
        {
          'candidate_id': '33333333-3333-4333-8333-333333333333',
          'character_id': '22222222-2222-4222-8222-222222222222',
          'generation': 1,
          'reason': 'first_threshold',
          'state': 'blocked',
          'eligibility': 'explicitly_excluded',
          'next_attempt_at': null,
          'last_error': null,
          'unresolved_command': null,
          'completed_at': null,
          'completed_command_id': null,
        },
    ];
    expect(() => AnalysisCandidates(value), throwsFormatException);
  });
}
