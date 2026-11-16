import '../../../support/server_analysis_fixtures.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/role_summary.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';

import '../../../support/server_account_read_fakes.dart';

const member = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const account = '44444444-4444-4444-8444-444444444444';
const profilePath = '/v2/me/characters/$characterId/personal-profile';
const putPath = '/v2/me/characters/$characterId/role-summaries/dealer';
Map<String, dynamic> emptyRole() => {
  'version': 1,
  'summary': null,
  'saved_at': null,
  'detail': null,
};
Map<String, dynamic> armory({
  String name = 'sample',
  String className = '버서커',
}) => {
  'ArmoryProfile': {
    'ServerName': 'sample-server',
    'CharacterName': name,
    'CharacterLevel': 70,
    'CharacterClassName': className,
    'ItemAvgLevel': '1,700.00',
    'CombatPower': '12,345.67',
  },
};
GameCatalog catalog() => GameCatalog(
  schemaVersion: 1,
  catalogVersion: 'tests-v1',
  updatedAt: DateTime.utc(2026),
  classes: const [
    GameClassDefinition(
      classId: 'berserker',
      apiClassName: '버서커',
      aliases: [],
      supportedRoles: {GameCatalogRole.dealer},
      defaultRole: GameCatalogRole.dealer,
      enlightenmentBranches: [],
      specialSkills: [],
      gemSkillTargets: [],
      arkGridPresets: [],
    ),
  ],
);
Map<String, dynamic> summaryJson() => {
  'source': 'server_analysis',
  'analysis_rules_version': 'tests-v1',
  'analyzed_at': serverTime,
  'combat_power': null,
  'item_level': null,
  'combat_power_observed_at': null,
  'item_level_observed_at': null,
  'integrity_status': 'unavailable',
  'catalog_version': null,
  'issues': <Object>[],
  'observed_lifecycle_revision': 1,
};

void main() {
  test('stored server head is structured and rejects old local source', () {
    final head = serverAnalysisHead();
    expect(StoredRoleSummary.fromJson(head).detail, isNotNull);
    head['summary']['source'] = 'flutter_analysis';
    expect(() => StoredRoleSummary.fromJson(head), throwsFormatException);
  });
  test('summary projection does not invent detailed data', () {
    final head = serverAnalysisHead()..remove('detail');
    expect(StoredRoleSummary.fromJson(head, summaryOnly: true).detail, isNull);
    expect(() => StoredRoleSummary.fromJson(head), throwsFormatException);
  });
}
