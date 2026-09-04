import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/game_catalog/data/datasources/asset_game_catalog_data_source.dart';
import 'package:lost_party/shared/game_catalog/data/repositories/game_catalog_repository_impl.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and validates the four support-hybrid class catalog', () async {
    final repository = GameCatalogRepositoryImpl(
      dataSource: AssetGameCatalogDataSource(),
    );

    final catalog = await repository.loadCatalog();
    expect(catalog.classes, hasLength(4));
    final bard = catalog.classes.singleWhere(
      (definition) => definition.classId == 'bard',
    );

    expect(bard.apiClassName, '바드');
    expect(bard.aliases, contains('BARD'));
    expect(bard.defaultRole, GameCatalogRole.support);
    expect(bard.enlightenmentBranches.map((branch) => branch.tier1NodeName), [
      '완벽한 화음',
      '진실된 용맹',
    ]);
    expect(bard.specialSkills.map((skill) => skill.name), [
      '용맹의 세레나데',
      '구원의 세레나데',
    ]);
    expect(
      bard.specialSkills.every(
        (skill) => skill.category == ClassSpecialSkillCategory.identity,
      ),
      isTrue,
    );
    expect(bard.gemSkillTargets.single.name, '세레나데 스킬');
    expect(bard.gemSkillTargets.single.relatedSpecialSkillIds, [
      'serenade_of_courage',
      'serenade_of_salvation',
    ]);
    expect(bard.arkGridPresets, isEmpty);
    expect(
      catalog.classes.map((definition) => definition.apiClassName),
      containsAll(['바드', '홀리나이트', '발키리', '도화가']),
    );
    expect(
      catalog.classes.every(
        (definition) =>
            definition.supportedRoles.contains(GameCatalogRole.dealer) &&
            definition.supportedRoles.contains(GameCatalogRole.support) &&
            definition.enlightenmentBranches.length == 2,
      ),
      isTrue,
    );
  });

  test('rejects a catalog that fails domain validation', () async {
    final repository = GameCatalogRepositoryImpl(
      dataSource: AssetGameCatalogDataSource(
        assetBundle: _StringAssetBundle(
          _validCatalogJson.replaceFirst(
            '"schemaVersion": 1',
            '"schemaVersion": 0',
          ),
        ),
      ),
    );

    await expectLater(
      repository.loadCatalog(),
      throwsA(
        isA<InvalidGameCatalogException>().having(
          (error) => error.issues.map((issue) => issue.code),
          'issue codes',
          contains('invalid_schema_version'),
        ),
      ),
    );
  });

  test('rejects an unsupported role while mapping JSON', () async {
    final dataSource = AssetGameCatalogDataSource(
      assetBundle: _StringAssetBundle(
        _validCatalogJson.replaceFirst(
          '"defaultRole": "support"',
          '"defaultRole": "tank"',
        ),
      ),
    );

    await expectLater(dataSource.loadCatalog(), throwsFormatException);
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.value);

  final String value;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(value.codeUnits);
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => value;
}

const _validCatalogJson = '''
{
  "schemaVersion": 1,
  "catalogVersion": "2026.08.20",
  "updatedAt": "2026-08-20T00:00:00Z",
  "classes": [{
    "classId": "bard",
    "apiClassName": "바드",
    "aliases": ["BARD"],
    "supportedRoles": ["dealer", "support"],
    "defaultRole": "support",
    "enlightenmentBranches": [
      {
        "branchId": "perfect_harmony",
        "tier1NodeName": "완벽한 화음",
        "displayName": "바드",
        "aliases": [],
        "inferredRole": "support",
        "relatedPassiveNodes": ["세레나데 코드"]
      },
      {
        "branchId": "true_courage",
        "tier1NodeName": "진실된 용맹",
        "displayName": "딜바드",
        "aliases": [],
        "inferredRole": "dealer",
        "relatedPassiveNodes": ["템페스트 필드"]
      }
    ],
    "specialSkills": [
      {
        "skillId": "serenade_of_courage",
        "name": "용맹의 세레나데",
        "aliases": ["용맹"],
        "category": "identity",
        "relatedBranchIds": ["perfect_harmony", "true_courage"]
      },
      {
        "skillId": "serenade_of_salvation",
        "name": "구원의 세레나데",
        "aliases": ["절구"],
        "category": "identity",
        "relatedBranchIds": ["perfect_harmony", "true_courage"]
      }
    ],
    "gemSkillTargets": [
      {
        "targetId": "serenade_support_effect",
        "name": "세레나데 스킬",
        "aliases": [],
        "relatedSpecialSkillIds": [
          "serenade_of_courage",
          "serenade_of_salvation"
        ]
      }
    ],
    "arkGridPresets": []
  }]
}
''';
