import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/raid_catalog/data/datasources/asset_raid_catalog_data_source.dart';
import 'package:lost_party/shared/raid_catalog/data/repositories/raid_catalog_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and validates the bundled raid catalog sample', () async {
    final repository = RaidCatalogRepositoryImpl(
      dataSource: AssetRaidCatalogDataSource(),
    );

    final catalog = await repository.loadCatalog();
    final raid = catalog.raids.single;

    expect(catalog.catalogVersion, '2026.08.20');
    expect(raid.raidId, 'sample_raid');
    expect(raid.partySize, 8);
    expect(raid.gateCount, 2);
    expect(raid.difficulties.map((value) => value.difficultyId), [
      'normal',
      'hard',
    ]);
    expect(raid.difficulties.last.isActive, isFalse);
  });

  test('rejects a catalog that fails domain validation', () async {
    final repository = RaidCatalogRepositoryImpl(
      dataSource: AssetRaidCatalogDataSource(
        assetBundle: _StringAssetBundle(
          _validCatalogJson.replaceFirst('"partySize": 8', '"partySize": 0'),
        ),
      ),
    );

    await expectLater(
      repository.loadCatalog(),
      throwsA(
        isA<InvalidRaidCatalogException>().having(
          (error) => error.issues.map((issue) => issue.code),
          'issue codes',
          contains('invalid_party_size'),
        ),
      ),
    );
  });

  test('rejects an invalid JSON field type while mapping', () async {
    final dataSource = AssetRaidCatalogDataSource(
      assetBundle: _StringAssetBundle(
        _validCatalogJson.replaceFirst('"isActive": true', '"isActive": 1'),
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
    return ByteData.sublistView(Uint8List.fromList(value.codeUnits));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => value;
}

const _validCatalogJson = '''
{
  "schemaVersion": 1,
  "catalogVersion": "2026.08.20",
  "updatedAt": "2026-08-20T00:00:00Z",
  "raids": [{
    "raidId": "sample_raid",
    "name": "샘플 레이드",
    "partySize": 8,
    "gateCount": 2,
    "isActive": true,
    "difficulties": [{
      "difficultyId": "normal",
      "name": "노말",
      "displayOrder": 1,
      "minItemLevel": 1700,
      "rewardGold": 30000,
      "isActive": true
    }]
  }]
}
''';
