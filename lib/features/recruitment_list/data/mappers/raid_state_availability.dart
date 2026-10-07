import 'package:cloud_firestore/cloud_firestore.dart';

/// An authenticated availability record contains no participation or completion.
/// This parser classifies stored data; ownership is checked separately.
class RaidStateAvailability {
  const RaidStateAvailability._();

  static const guardFields = {
    'guardSchemaVersion',
    'guardRecruitmentId',
    'guardRoomRevision',
    'guardCycleKey',
    'guardCycleStartedAt',
    'guardCycleEndsAt',
    'guardSlotIndex',
    'guardCheckedAt',
  };
  static const _fields = {
    'playerId',
    'characterId',
    'raidId',
    'ownershipRevision',
    ...guardFields,
  };

  static bool isStub(Map<String, dynamic>? data) {
    if (data == null ||
        data.length != _fields.length ||
        !data.keys.toSet().containsAll(_fields)) {
      return false;
    }
    final start = data['guardCycleStartedAt'];
    final end = data['guardCycleEndsAt'];
    final index = data['guardSlotIndex'];
    final revision = data['guardRoomRevision'];
    final generation = data['ownershipRevision'];
    return data['guardSchemaVersion'] == 1 &&
        data['playerId'] is String &&
        (data['playerId'] as String).isNotEmpty &&
        data['characterId'] is String &&
        RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(data['characterId'] as String) &&
        data['raidId'] is String &&
        RegExp(r'^[a-z0-9_]+$').hasMatch(data['raidId'] as String) &&
        generation is int &&
        generation >= 0 &&
        revision is int &&
        revision >= 0 &&
        index is int &&
        index >= 0 &&
        index < 8 &&
        data['guardRecruitmentId'] is String &&
        (data['guardRecruitmentId'] as String).isNotEmpty &&
        data['guardCycleKey'] is String &&
        RegExp(
          r'^\d{4}-\d{2}-\d{2}$',
        ).hasMatch(data['guardCycleKey'] as String) &&
        start is Timestamp &&
        end is Timestamp &&
        end.toDate().difference(start.toDate()) == const Duration(days: 7) &&
        data['guardCheckedAt'] is Timestamp;
  }
}
