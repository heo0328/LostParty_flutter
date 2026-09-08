import 'package:flutter/material.dart';

const serverAccountMismatchMessage =
    '기기에 저장된 계정 정보와 서버 인증 정보가 일치하지 않습니다. '
    '앱을 재설치하거나 앱 데이터를 삭제한 뒤 게임 계정을 다시 인증해 주세요.';

Future<void> showServerAccountMismatchAlert(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('계정 정보를 확인해 주세요'),
    content: const Text(serverAccountMismatchMessage),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('확인'),
      ),
    ],
  ),
);
