import '../../domain/entities/raid_catalog.dart';

class RaidCatalogMapper {
  const RaidCatalogMapper();

  RaidCatalog fromJson(Map<String, dynamic> json) {
    return RaidCatalog(
      schemaVersion: _integer(json, 'schemaVersion'),
      catalogVersion: _string(json, 'catalogVersion'),
      updatedAt: DateTime.parse(_string(json, 'updatedAt')),
      raids: _mapList(json, 'raids', _raidFromJson),
    );
  }

  RaidDefinition _raidFromJson(Map<String, dynamic> json) {
    return RaidDefinition(
      raidId: _string(json, 'raidId'),
      officialName: _string(json, 'officialName'),
      displayName: _string(json, 'displayName'),
      aliases: _stringList(json, 'aliases'),
      partySize: _integer(json, 'partySize'),
      partyCount: _integer(json, 'partyCount'),
      requiredSupportCount: _integer(json, 'requiredSupportCount'),
      maxDealerCountPerClass: _integer(json, 'maxDealerCountPerClass'),
      gateCount: _integer(json, 'gateCount'),
      isActive: _boolean(json, 'isActive'),
      difficulties: _mapList(json, 'difficulties', _difficultyFromJson),
    );
  }

  RaidDifficultyDefinition _difficultyFromJson(Map<String, dynamic> json) {
    return RaidDifficultyDefinition(
      difficultyId: _string(json, 'difficultyId'),
      name: _string(json, 'name'),
      displayAlias: _string(json, 'displayAlias'),
      displayOrder: _integer(json, 'displayOrder'),
      minItemLevel: _integer(json, 'minItemLevel'),
      clearGold: _integer(json, 'clearGold'),
      boundGold: _integer(json, 'boundGold'),
      isActive: _boolean(json, 'isActive'),
    );
  }

  bool _boolean(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('$key must be a boolean.');
    return value;
  }

  int _integer(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  List<String> _stringList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('$key must be a string list.');
    }
    return value.cast<String>();
  }

  List<T> _mapList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) mapper,
  ) {
    final value = json[key];
    if (value is! List || value.any((item) => item is! Map)) {
      throw FormatException('$key must be an object list.');
    }
    return value
        .cast<Map>()
        .map((item) => mapper(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}
