import '../entities/group_create_command.dart';
import '../entities/group_create_result.dart';

abstract interface class GroupCreateRepository {
  Future<GroupCreateResult> create(GroupCreateCommand command);
}
