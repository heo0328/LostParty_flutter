import 'dart:convert';

import 'package:lost_party/features/account/data/mappers/character_build_analysis_mapper.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';

class LostArkGemProbeReport {
  const LostArkGemProbeReport({
    required this.characterName,
    required this.characterClassName,
    required this.catalogVersion,
    required this.gems,
  });

  final String characterName;
  final String characterClassName;
  final String catalogVersion;
  final List<LostArkGemProbeFinding> gems;
}

class LostArkGemProbeFinding {
  const LostArkGemProbeFinding({
    required this.slot,
    required this.level,
    required this.targetName,
    required this.tooltipClassNames,
    required this.tooltipClassMatchesCharacter,
    required this.currentCategory,
    required this.currentWarnings,
  });

  final int slot;
  final int level;
  final String targetName;
  final List<String> tooltipClassNames;
  final bool? tooltipClassMatchesCharacter;
  final String currentCategory;
  final List<String> currentWarnings;
}

LostArkGemProbeReport buildLostArkGemProbeReport(
  Map<String, dynamic> response,
  GameCatalog catalog,
) {
  final profile = _asMap(response['ArmoryProfile']);
  final characterName = profile?['CharacterName'] as String? ?? '(이름 미확인)';
  final characterClassName =
      profile?['CharacterClassName'] as String? ?? '(직업 미확인)';
  final analysis = const CharacterBuildAnalysisMapper().fromJson(
    response,
    catalog: catalog,
  );
  final armoryGem = _asMap(response['ArmoryGem']);
  final gemsBySlot = <int, Map<String, dynamic>>{};
  for (final gem in _asMapList(armoryGem?['Gems'])) {
    final slot = gem['Slot'];
    if (slot is int) {
      gemsBySlot[slot] = gem;
    }
  }
  final effectsMap = _asMap(armoryGem?['Effects']);
  final effectsBySlot = <int, Map<String, dynamic>>{};
  for (final effect in _asMapList(effectsMap?['Skills'])) {
    final slot = effect['GemSlot'];
    if (slot is int) {
      effectsBySlot[slot] = effect;
    }
  }

  final knownClassNames = <String, String>{};
  for (final definition in catalog.classes) {
    for (final name in [definition.apiClassName, ...definition.aliases]) {
      knownClassNames[_normalize(name)] = definition.apiClassName;
    }
  }

  final findings = <LostArkGemProbeFinding>[];
  for (final effect in analysis.gemEffects) {
    final sourceGem = gemsBySlot[effect.gemSlot];
    final sourceEffect = effectsBySlot[effect.gemSlot];
    final tooltipClassNames = extractGemTooltipClassNames(
      [
        sourceGem?['Tooltip'],
        sourceEffect?['Tooltip'],
        sourceEffect?['Description'],
      ],
      knownClassNames,
    );
    final normalizedCharacterClass = _normalize(characterClassName);
    final matches = tooltipClassNames.isEmpty
        ? null
        : tooltipClassNames.any(
            (name) => _normalize(name) == normalizedCharacterClass,
          );
    final warningCode = 'unknown_gem_skill_${effect.gemSlot}';
    findings.add(
      LostArkGemProbeFinding(
        slot: effect.gemSlot,
        level: effect.gemLevel,
        targetName: effect.skillName,
        tooltipClassNames: tooltipClassNames,
        tooltipClassMatchesCharacter: matches,
        currentCategory: effect.category.name,
        currentWarnings: analysis.notices
            .where(
              (notice) =>
                  notice.code == warningCode ||
                  notice.code == 'unmapped_gem_${effect.gemSlot}',
            )
            .map((notice) => notice.message)
            .toList(growable: false),
      ),
    );
  }
  findings.sort((left, right) => left.slot.compareTo(right.slot));

  return LostArkGemProbeReport(
    characterName: characterName,
    characterClassName: characterClassName,
    catalogVersion: catalog.catalogVersion,
    gems: findings,
  );
}

List<String> extractGemTooltipClassNames(
  Iterable<Object?> tooltipValues,
  Map<String, String> knownClassNames,
) {
  final result = <String>{};
  for (final tooltip in tooltipValues) {
    for (final text in _tooltipStrings(tooltip)) {
      final plainText = _stripMarkup(text);
      for (final match in RegExp(r'\[([^\[\]]+)\]').allMatches(plainText)) {
        final candidate = match.group(1)?.trim();
        if (candidate == null) {
          continue;
        }
        final canonical = knownClassNames[_normalize(candidate)];
        if (canonical != null) {
          result.add(canonical);
        }
      }
    }
  }
  return result.toList(growable: false)..sort();
}

Iterable<String> _tooltipStrings(Object? value) sync* {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map || decoded is List) {
        yield* _tooltipStrings(decoded);
        return;
      }
    } on FormatException {
      // Plain tooltip text is expected for some API fields.
    }
    yield trimmed;
    return;
  }
  if (value is Map) {
    for (final child in value.values) {
      yield* _tooltipStrings(child);
    }
    return;
  }
  if (value is Iterable) {
    for (final child in value) {
      yield* _tooltipStrings(child);
    }
  }
}

String _stripMarkup(String value) => value
    .replaceAll(RegExp(r'<[^>]*>', caseSensitive: false), '')
    .replaceAll('&nbsp;', ' ')
    .trim();

String _normalize(String value) => value.trim().toLowerCase();

Map<String, dynamic>? _asMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map(Map<String, dynamic>.from)
      .toList(growable: false);
}
