import 'package:flutter/material.dart';

import 'party_gem_validation_snapshot.dart';

/// 파티·그룹 카드에 공통으로 쓰는 보석 검증 한 줄 표시.
class GemValidationLine extends StatelessWidget {
  const GemValidationLine({
    super.key,
    required this.validation,
    required this.keyName,
  });

  final PartyGemValidationSnapshot validation;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isForeign =
        validation.status == PartyGemValidationStatus.foreignClass;
    final label = switch (validation.status) {
      PartyGemValidationStatus.foreignClass =>
        '보석 확인 요망 · 타 직업 보석 ${validation.foreignClassGemCount}개',
      PartyGemValidationStatus.sameClassTargetUnverified =>
        '동일 직업 보석 · 대상 스킬 미확인 ${validation.unverifiedSameClassGemCount}개',
      PartyGemValidationStatus.unavailable => '보석 검증 정보 없음',
      PartyGemValidationStatus.verified => null,
    };
    if (label == null) return const SizedBox.shrink();
    final color = isForeign
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      key: ValueKey(keyName),
      children: [
        Icon(
          isForeign ? Icons.error_outline : Icons.info_outline,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
