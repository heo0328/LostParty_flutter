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
        validation.status == PartyGemValidationStatus.foreignClass ||
        validation.status == PartyGemValidationStatus.error;
    final label = switch (validation.status) {
      PartyGemValidationStatus.error => _v2ErrorLabel(validation),
      PartyGemValidationStatus.foreignClass =>
        '보석 확인 요망 · 타 직업 보석 ${validation.foreignClassGemCount}개',
      PartyGemValidationStatus.sameClassTargetUnverified => null,
      PartyGemValidationStatus.unavailable => null,
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

  static String _v2ErrorLabel(PartyGemValidationSnapshot validation) {
    final labels = <String>[];
    final count = validation.equippedGemCount;
    if (count != null && count < 11) labels.add('보석 부족 $count/11');
    if (validation.foreignClassGemCount > 0) {
      labels.add('타 직업 보석 ${validation.foreignClassGemCount}개');
    }
    if (validation.unmatchedSkillGemCount > 0) {
      labels.add('스킬 불일치 보석 ${validation.unmatchedSkillGemCount}개');
    }
    return labels.isEmpty ? '보석 오류' : labels.join(' · ');
  }
}
