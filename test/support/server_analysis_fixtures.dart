import 'package:lost_party/features/account/data/character_analysis_client.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';

const analysisStamp = '2026-10-16T00:00:00Z';
Map<String, dynamic> analysisDetail({
  String role = 'dealer',
  String catalog = 'tests-v1',
}) => {
  'detection': {
    'status': 'detected',
    'catalog_version': catalog,
    'class_id': 'example',
    'branch_id': 'example',
    'branch_display_name': '예시 계열',
    'detected_role': role,
    'matched_tier1_node': '예시 노드',
    'matched_related_nodes': <String>[],
  },
  'rune_count': 8,
  'equipped_gem_count': 11,
  'gem_effects_source_available': true,
  'gems': [
    for (var i = 0; i < 11; i++)
      {
        'slot': i,
        'level': 10,
        'target': '예시 스킬',
        'descriptions': <String>[],
        'category': 'normal',
        'validation_status': 'verified',
      },
  ],
  'ark_grid_core_points': <Object>[],
  'ark_grid_conditions': <Object>[],
  'ark_grid_minimum': {
    'order_sun_point': 14,
    'order_moon_point': 14,
    'required_point': 14,
  },
  'notices': <Object>[],
};
Map<String, dynamic> serverAnalysisHead({
  int version = 2,
  String? power = '12345.67',
  String role = 'dealer',
  String integrity = 'clean',
  int lifecycle = 1,
}) => {
  'version': version,
  'saved_at': analysisStamp,
  'summary': {
    'source': 'server_analysis',
    'analysis_rules_version': 'lostparty-server-role-analysis-v1',
    'analyzed_at': analysisStamp,
    'combat_power': power,
    'item_level': '1700.00',
    'combat_power_observed_at': power == null ? null : analysisStamp,
    'item_level_observed_at': analysisStamp,
    'integrity_status': integrity,
    'catalog_version': 'tests-v1',
    'issues': [
      if (integrity == 'error') {'code': 'GEM_SLOT_COUNT', 'severity': 'error'},
    ],
    'observed_lifecycle_revision': lifecycle,
  },
  'detail': analysisDetail(role: role),
};
Map<String, dynamic> emptyAnalysisHead() => {
  'version': 1,
  'summary': null,
  'saved_at': null,
  'detail': null,
};

class MemoryAnalysisJournal implements AnalysisJournal {
  final values = <StorageScope, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(StorageScope scope) async => values[scope];
  @override
  Future<void> write(StorageScope scope, String value) async {
    if (failWrite) throw StateError('storage failed');
    values[scope] = value;
  }
}
