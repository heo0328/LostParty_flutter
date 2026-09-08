import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/save_activity_characters_command.dart';

ActivityCharactersSaveException mapActivityCharactersFirebaseException(
  FirebaseException error,
) {
  assert(() {
    // ignore: avoid_print
    print(
      'ActivityCharacters FirebaseException: ${error.code} ${error.message}',
    );
    return true;
  }());
  return ActivityCharactersSaveException(
    _failureFor(error.code),
    _messageFor(error.code),
  );
}

ActivityCharactersSaveFailure _failureFor(String code) {
  return switch (code) {
    'unauthenticated' => ActivityCharactersSaveFailure.unauthenticated,
    'permission-denied' => ActivityCharactersSaveFailure.permissionDenied,
    'unavailable' ||
    'deadline-exceeded' ||
    'aborted' => ActivityCharactersSaveFailure.unavailable,
    _ => ActivityCharactersSaveFailure.unavailable,
  };
}

String _messageFor(String code) {
  return switch (code) {
    'unauthenticated' => '로그인한 사용자만 활동 캐릭터를 저장할 수 있습니다.',
    'permission-denied' =>
      '캐릭터 활동 설정을 저장할 권한이 없습니다. 최신 Firestore Rules가 배포됐는지 확인해 주세요.',
    'unavailable' ||
    'deadline-exceeded' ||
    'aborted' => '서버에 연결하지 못했습니다. 네트워크를 확인한 뒤 다시 시도해 주세요.',
    _ => '캐릭터 설정을 서버에 반영하지 못했습니다. ($code)',
  };
}
