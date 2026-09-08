import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:lost_party/shared/game_catalog/data/mappers/game_catalog_mapper.dart';

import 'src/lost_ark_gem_probe.dart';

const _tokenEnvironmentKey = 'LOST_ARK_API_TOKEN';
const _catalogPath = 'assets/game_catalog/game_catalog.v1.json';
const _baseUrl = 'https://developer-lostark.game.onstove.com';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 || arguments.single.trim().isEmpty) {
    stderr.writeln('사용법: dart run tool/lost_ark_gem_probe.dart "캐릭터명"');
    exitCode = 64;
    return;
  }
  final token = Platform.environment[_tokenEnvironmentKey]?.trim();
  if (token == null || token.isEmpty) {
    stderr.writeln('$_tokenEnvironmentKey 환경 변수가 없습니다. 토큰은 명령 인자로 전달하지 마세요.');
    exitCode = 78;
    return;
  }

  try {
    final catalogJson = jsonDecode(await File(_catalogPath).readAsString());
    final catalog = const GameCatalogMapper().fromJson(
      Map<String, dynamic>.from(catalogJson as Map),
    );
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
      ),
    );
    final characterName = arguments.single.trim();
    final response = await dio.get<Object?>(
      '/armories/characters/${Uri.encodeComponent(characterName)}',
      options: Options(
        headers: {
          Headers.acceptHeader: Headers.jsonContentType,
          'Authorization': 'bearer $token',
        },
      ),
    );
    if (response.data is! Map) {
      throw const FormatException('캐릭터 상세 응답이 JSON 객체가 아닙니다.');
    }
    final report = buildLostArkGemProbeReport(
      Map<String, dynamic>.from(response.data! as Map),
      catalog,
    );
    _printReport(report);
  } on DioException catch (error) {
    stderr.writeln(
      'Lost Ark API 요청 실패: HTTP ${error.response?.statusCode ?? '-'}',
    );
    exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('진단 실패: $error');
    exitCode = 1;
  }
}

void _printReport(LostArkGemProbeReport report) {
  stdout.writeln('캐릭터: ${report.characterName}');
  stdout.writeln('직업: ${report.characterClassName}');
  stdout.writeln('카탈로그: ${report.catalogVersion}');
  stdout.writeln('Build 판정: ${report.detectionStatus}');
  stdout.writeln(
    '계열: ${report.branchDisplayName ?? '미확인'} '
    '(${report.branchId ?? '-'}, 역할 ${report.detectedRole ?? '미확인'})',
  );
  stdout.writeln('');
  stdout.writeln('[깨달음 1·4티어]');
  if (report.enlightenmentNodes.isEmpty) {
    stdout.writeln('  확인된 노드 없음');
  }
  for (final node in report.enlightenmentNodes) {
    stdout.writeln('  ${node.tier}티어 ${node.name} Lv.${node.level}');
  }
  stdout.writeln('');
  stdout.writeln('[질서 아크그리드]');
  if (report.arkGridCores.isEmpty) {
    stdout.writeln('  확인된 질서 코어 없음');
  }
  for (final core in report.arkGridCores) {
    final minimum = core.slot == LostArkGridCoreSlot.star
        ? '필수 판정 제외'
        : core.meetsRequiredMinimum
        ? '14P 충족'
        : '14P 미충족';
    stdout.writeln(
      '  ${core.slot.name}: ${core.coreName} / ${core.grade} ${core.point}P '
      '($minimum)',
    );
  }
  stdout.writeln(
    '  기본 조건: 해 ${report.hasValidOrderSun ? '충족' : '미충족'}, '
    '달 ${report.hasValidOrderMoon ? '충족' : '미충족'}',
  );
  stdout.writeln('');
  stdout.writeln('[아크그리드 활성 조건]');
  if (report.arkGridConditions.isEmpty) {
    stdout.writeln('  확인된 조건 없음');
  }
  for (final condition in report.arkGridConditions) {
    stdout.writeln(
      '  ${condition.coreName}: '
      '${condition.isSatisfied ? '충족' : '미충족'}',
    );
    stdout.writeln('    ${condition.conditionText}');
    if (condition.missingPassiveNames.isNotEmpty) {
      stdout.writeln('    누락: ${condition.missingPassiveNames.join(', ')}');
    }
  }
  stdout.writeln('');
  stdout.writeln(
    '[API 스킬 ${report.armorySkillNames.length}개] '
    '${report.armorySkillNames.join(', ')}',
  );
  stdout.writeln('');
  stdout.writeln('보석 수: ${report.gems.length}');
  for (final gem in report.gems) {
    final tooltipClasses = gem.tooltipClassNames.isEmpty
        ? '미확인'
        : gem.tooltipClassNames.join(', ');
    final classMatch = switch (gem.tooltipClassMatchesCharacter) {
      true => '일치',
      false => '불일치',
      null => '판정 보류',
    };
    stdout.writeln('');
    stdout.writeln('[슬롯 ${gem.slot}] Lv.${gem.level} ${gem.targetName}');
    stdout.writeln('  Tooltip 직업: $tooltipClasses ($classMatch)');
    stdout.writeln('  현재 앱 분류: ${gem.currentCategory}');
    for (final warning in gem.currentWarnings) {
      stdout.writeln('  경고: $warning');
    }
  }
}
