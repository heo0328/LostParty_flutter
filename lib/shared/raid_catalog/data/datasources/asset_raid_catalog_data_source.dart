import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/raid_catalog.dart';
import '../mappers/raid_catalog_mapper.dart';

class AssetRaidCatalogDataSource {
  AssetRaidCatalogDataSource({
    AssetBundle? assetBundle,
    this.assetPath = defaultAssetPath,
    RaidCatalogMapper mapper = const RaidCatalogMapper(),
  }) : _assetBundle = assetBundle ?? rootBundle,
       _mapper = mapper;

  static const defaultAssetPath = 'assets/raid_catalog/raid_catalog.v1.json';

  final AssetBundle _assetBundle;
  final String assetPath;
  final RaidCatalogMapper _mapper;

  Future<RaidCatalog> loadCatalog() async {
    final source = await _assetBundle.loadString(assetPath);
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Raid catalog root must be an object.');
    }
    return _mapper.fromJson(Map<String, dynamic>.from(decoded));
  }
}
