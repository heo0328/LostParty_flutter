import 'package:flutter/material.dart';

import '../../../account/domain/entities/character_auto_refresh_result.dart';

Future<bool> confirmGroupCharacterRefresh(
  BuildContext context,
  CharacterAutoRefreshResult? result, {
  required int characterId,
  required int generation,
}) async {
  if (result == null) return true;
  if (!context.mounted ||
      !result.matchesSelection(
        selectedCharacterId: characterId,
        currentGeneration: generation,
      )) {
    return false;
  }
  if (result.expectedRoleChanged) {
    _message(context, '새 세팅의 역할이 선호 역할과 달라 다시 선택해야 합니다.');
    return false;
  }
  if (result.status == CharacterAutoRefreshStatus.blocked) {
    _message(context, result.message ?? '캐릭터 정보를 갱신하지 못했습니다.');
    return false;
  }
  if (!result.requiresConfirmation) return true;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('최근 저장 정보로 계속할까요?'),
          content: Text(
            result.lastSuccessfulAt == null
                ? '현재 정보를 갱신하지 못했습니다. 저장된 정보로 계속할 수 있습니다.'
                : '현재 정보를 갱신하지 못했습니다. ${result.lastSuccessfulAt!.toLocal()}에 저장된 정보로 계속할 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('계속'),
            ),
          ],
        ),
      ) ==
      true;
}

void _message(BuildContext context, String value) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
}
