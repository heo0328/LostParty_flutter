import '../entities/group_create_command.dart';
import '../entities/group_create_result.dart';
import 'group_name_normalizer.dart';

class GroupCreateCommandValidator {
  const GroupCreateCommandValidator({
    this.normalizer = const GroupNameNormalizer(),
  });

  final GroupNameNormalizer normalizer;

  GroupCreateFailure? validate(GroupCreateCommand command) {
    if (_invalidDocumentId(command.representativeCharacterId) ||
        normalizer.displayName(command.representativeCharacterName).isEmpty ||
        normalizer.displayName(command.representativeServerName).isEmpty) {
      return GroupCreateFailure.invalidCharacter;
    }
    if (!command.usesDefaultName &&
        !normalizer.isValidDisplayName(command.name!)) {
      return GroupCreateFailure.invalidRequest;
    }
    return null;
  }

  bool _invalidDocumentId(String value) =>
      value.trim().isEmpty || value.contains('/');
}
