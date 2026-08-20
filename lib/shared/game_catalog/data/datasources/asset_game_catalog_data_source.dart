import 'dart:convert';

import 'package:flutter/services.dart';

import '../mappers/game_catalog_mapper.dart';
import '../../domain/entities/game_catalog.dart';

class AssetGameCatalogDataSource {
  AssetGameCatalogDataSource({
    AssetBundle? assetBundle,
    this.assetPath = defaultAssetPath,
    GameCatalogMapper mapper = const GameCatalogMapper(),
  }) : _assetBundle = assetBundle ?? rootBundle,
       _mapper = mapper;

  static const defaultAssetPath = 'assets/game_catalog/game_catalog.v1.json';

  final AssetBundle _assetBundle;
  final String assetPath;
  final GameCatalogMapper _mapper;

  Future<GameCatalog> loadCatalog() async {
    final source = await _assetBundle.loadString(assetPath);
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Game catalog root must be an object.');
    }
    return _mapper.fromJson(Map<String, dynamic>.from(decoded));
  }
}
