import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_account_view_model.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_read_repository.dart';
import 'package:lost_party/features/recruitment_list/data/membership_readers.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_own_card_info.dart';
import 'cycle_archive_test.dart' as archive;
import 'membership_readers_test.dart' as readers;
import '../account/backend_read/member_cycles_test.dart' as cycles;

Map<String, dynamic> wire() {
  final content = archive.row(archive.explicit);
  content['target_participation_state'] = 'participating';
  content['room']['target_state'] = 'open';
  final room = content['room'];
  final entry =
      readers.sample('current_unknown_generation_page')['data']['items'][0]
          as Map<String, dynamic>;
  entry['target'].addAll({
    'room_id': room['room_id'],
    'title': room['title'],
    'room_revision': room['revision'],
    'target_cycle_key': cycles.next,
    'room_cycle_id': room['room_cycle_id'],
    'target_generation': room['target_generation'],
    'target_revision': room['target_revision'],
    'target_state': 'open',
    'generation_state': 'open',
    'leadership': room['leadership'],
  });
  entry['viewer'].addAll({
    'membership_id': content['membership_id'],
    'cycle_member_id': content['cycle_member_id'],
    'cycle_member_state': 'participating',
    'role': 'member',
    'mode': 'participant',
    'record_locator': null,
  });
  entry['recovery'].addAll({'state': 'none', 'reason': null});
  entry['content'] = content;
  return entry;
}

CycleOwnRow row(Map<String, dynamic> entry) => CycleOwnRow.profile(
  MembershipProjection(entry, cycles.next, entry: true),
  cycles.next,
);

void main() {
  test(
    'only exact current CM/T active assignments supply names; repeats deduplicate',
    () {
      final entry = wire();
      final assignments = entry['content']['assignments'] as List;
      final id = assignments.first['character_id'] as String;
      assignments.add({
        ...assignments.first,
        'character_id': 'wrong-cycle',
        'target_cycle_key': cycles.current,
      });
      assignments.add({
        ...assignments.first,
        'character_id': 'wrong-member',
        'cycle_member_id': 'other',
      });
      assignments.add({
        ...assignments.first,
        'character_id': 'ended',
        'state': 'cancelled',
      });
      assignments.add({
        ...assignments.first,
        'character_id': 'wrong-item',
        'item_id': 'other',
      });
      final info = CycleOwnCardInfo.fromRow(row(entry), {
        id: '참가 캐릭터',
        'representative': '대표',
      }, null)!;
      expect(info.characters, ['참가 캐릭터']);
      expect(info.raids.length, entry['content']['room']['items'].length);
    },
  );
  test('missing cache name is a failure label, not a user action', () {
    final info = CycleOwnCardInfo.fromRow(row(wire()), {}, null)!;
    expect(info.characters, ['캐릭터명 확인 실패']);
  });
  test('party size, not occupancy, determines leader/member labels', () {
    for (final capacity in [4, 8]) {
      for (final leader in [false, true]) {
        final entry = wire();
        entry['content']['room']['app_capacity'] = capacity;
        entry['content']['room']['app_member_count'] = 1;
        entry['viewer']['role'] = leader ? 'leader' : 'member';
        expect(
          CycleOwnCardInfo.fromRow(row(entry), {}, null)!.role,
          capacity == 4 ? (leader ? '파티장' : '파티원') : (leader ? '공대장' : '공대원'),
        );
      }
    }
  });
  test(
    'record and unknown recovery rows cannot acquire current account names',
    () {
      for (final name in [
        'ended_records_page',
        'current_unknown_generation_page',
      ]) {
        final entry =
            readers.sample(name)['data']['items'][0] as Map<String, dynamic>;
        final r = CycleOwnRow.profile(
          MembershipProjection(entry, cycles.current, entry: true),
          cycles.current,
        );
        expect(CycleOwnCardInfo.fromRow(r, {'anything': '현재 캐릭터'}, null), null);
      }
    },
  );
  test('name index isolates environment/member and observation identity', () {
    final scope = StorageScope(
      baseUrl: 'https://example.test',
      userId: '00000000-0000-4000-8000-000000000001',
    );
    final other = StorageScope(
      baseUrl: 'https://other.test',
      userId: scope.userId,
    );
    final otherMember = StorageScope(
      baseUrl: scope.environment,
      userId: '00000000-0000-4000-8000-000000000002',
    );
    const id = '00000000-0000-4000-8000-000000000003',
        account = '00000000-0000-4000-8000-000000000004';
    MemberCharacterState character(
      StorageScope s,
      String name, {
      String observationId = id,
    }) => MemberCharacterState(
      ScopedCharacterRef(s, accountId: account, characterId: id),
      CacheCharacterObservation(
        characterId: observationId,
        accountId: account,
        serverName: '서버',
        characterName: name,
        lifecycleState: null,
        lifecycleRevision: null,
        usable: null,
        blockedReason: null,
      ),
    );
    expect(
      scopedParticipationNames([
        character(scope, '내 캐릭터'),
        character(other, '다른 환경'),
        character(otherMember, '다른 회원'),
      ], scope),
      {id: '내 캐릭터'},
    );
    expect(
      scopedParticipationNames([
        character(scope, '불일치', observationId: account),
      ], scope),
      isEmpty,
    );
  });
}
