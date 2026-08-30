import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/domain/entities/group_create_command.dart';
import 'package:lost_party/features/group/domain/entities/group_create_result.dart';
import 'package:lost_party/features/group/domain/services/group_create_command_validator.dart';

void main() {
  const validator = GroupCreateCommandValidator();

  GroupCreateCommand command({
    String characterId = 'character-1',
    String characterName = '검증된캐릭터',
    String serverName = '루페온',
    String? name,
  }) => GroupCreateCommand(
    representativeCharacterId: characterId,
    representativeCharacterName: characterName,
    representativeServerName: serverName,
    name: name,
  );

  test('그룹명 미입력은 기본값을 사용하므로 통과한다', () {
    expect(validator.validate(command()), isNull);
    expect(validator.validate(command(name: '   ')), isNull);
    expect(command(name: '   ').usesDefaultName, isTrue);
  });

  test('직접 입력한 그룹명 1~20자는 통과한다', () {
    expect(validator.validate(command(name: '로파길드')), isNull);
    expect(validator.validate(command(name: 'a' * 20)), isNull);
  });

  test('20자 초과와 제어문자 그룹명은 invalidRequest로 거절한다', () {
    expect(
      validator.validate(command(name: 'a' * 21)),
      GroupCreateFailure.invalidRequest,
    );
    expect(
      validator.validate(command(name: '앞\n뒤')),
      GroupCreateFailure.invalidRequest,
    );
  });

  test('대표 Character 문서 ID가 없거나 경로 문자를 담으면 거절한다', () {
    expect(
      validator.validate(command(characterId: '  ')),
      GroupCreateFailure.invalidCharacter,
    );
    expect(
      validator.validate(command(characterId: 'characters/abc')),
      GroupCreateFailure.invalidCharacter,
    );
  });

  test('대표 Character 표시 Snapshot이 비면 거절한다', () {
    expect(
      validator.validate(command(characterName: '   ')),
      GroupCreateFailure.invalidCharacter,
    );
    expect(
      validator.validate(command(serverName: '')),
      GroupCreateFailure.invalidCharacter,
    );
  });

  test('Character 검증 실패를 이름 검증보다 먼저 반환한다', () {
    expect(
      validator.validate(command(characterId: '', name: 'a' * 21)),
      GroupCreateFailure.invalidCharacter,
    );
  });
}
