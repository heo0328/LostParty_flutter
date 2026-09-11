import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

import 'group_member.dart';

/// 그룹원 카드 표시용 Snapshot. membership 주체는 Player이며 캐릭터 필드는 표시값이다.
class GroupMemberDisplayLoadResult {
  const GroupMemberDisplayLoadResult({
    required this.members,
    this.syncFailed = false,
  });

  final List<GroupMemberDisplay> members;
  final bool syncFailed;
}

class GroupMemberDisplay {
  const GroupMemberDisplay({
    required this.member,
    required this.characterName,
    required this.className,
    this.itemLevel,
    this.combatPower,
    this.gemValidation,
  });

  final GroupMember member;
  final String characterName;
  final String className;
  final double? itemLevel;
  final double? combatPower;
  final PartyGemValidationSnapshot? gemValidation;

  bool get isLeader => member.isLeader;
}
