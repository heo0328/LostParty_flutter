import 'dart:convert';

import '../../account/data/member_raid_client.dart';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/server_account_read_repository.dart';
import '../../account/domain/server_registration_api.dart';
import '../../account/domain/services/account_detail_access.dart';
import '../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../domain/backend_recruitment.dart';

class BackendRecruitmentRepository implements RecruitmentGateway {
  BackendRecruitmentRepository({
    required this.api,
    required this.accounts,
    required this.raids,
  });
  final BackendRegistrationApi api;
  final ServerAccountReadRepository accounts;
  final MemberRaidClient raids;

  Future<T> _decode<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  @override
  Future<RaidCatalog> catalog() => raids.catalog();

  @override
  Future<List<RecruitmentCharacter>> characters() async {
    final scope = accountReadScope(accounts.session);
    final registrations = await accounts.loadRegistrations();
    final values = <RecruitmentCharacter>[];
    for (final r in registrations) {
      if (!hasAccountDetailAccess(
        ownershipStatus: r.ownershipStatus,
        accountId: r.gameAccountId,
        ownershipRevision: r.ownershipRevision,
      )) {
        continue;
      }
      final roster = await accounts.loadCharacters(r.registrationId);
      requireAccountReadScope(accounts.session, scope);
      if (roster.ownershipStatus != 'owned') continue;
      final active = roster.settings.activityCharacterIds.toSet();
      final ineligible = roster.settings.ineligibleCharacterIds.toSet();
      final chars = roster.characters
          .where(
            (c) =>
                c.characterId != null &&
                c.eligible &&
                c.rosterStatus == 'confirmed' &&
                active.contains(c.characterId) &&
                !ineligible.contains(c.characterId),
          )
          .toList();
      chars.sort(
        (a, b) => (double.tryParse(b.itemLevel ?? '') ?? -1).compareTo(
          double.tryParse(a.itemLevel ?? '') ?? -1,
        ),
      );
      for (final c in chars) {
        values.add(
          RecruitmentCharacter(
            id: c.characterId!,
            registrationId: r.registrationId,
            name: c.characterName,
            className: c.className,
            itemLevel: c.itemLevel,
            accountLabel: r.label.isEmpty
                ? (r.isMain ? '본계정' : '부계정')
                : r.label,
            representative:
                c.characterId == roster.settings.representativeCharacterId,
          ),
        );
      }
    }
    return List.unmodifiable(values);
  }

  Future<List<Map<String, dynamic>>> _pages(
    String path, {
    Map<String, dynamic> query = const {},
  }) => _decode(() async {
    final scope = accountReadScope(accounts.session);
    final values = <Map<String, dynamic>>[], cursors = <String>{};
    String? cursor;
    // These are transport bounds, never an artificial UI membership limit.
    for (var n = 0; n < 100; n++) {
      final page = (await api.request(
        path,
        query: {...query, 'limit': 50, 'cursor': ?cursor},
      ))!;
      requireAccountReadScope(accounts.session, scope);
      final rows = raidList(page['items']);
      values.addAll(rows.map(roleMap));
      final next = page['next_cursor'];
      if (next == null) return values;
      roleCheck(
        next is String &&
            next.isNotEmpty &&
            next.length <= 2048 &&
            rows.isNotEmpty,
      );
      roleCheck(cursors.add(next as String));
      cursor = next;
    }
    throw const FormatException('Pagination limit');
  });

  @override
  Future<List<RecruitmentGroupChoice>> groups() async =>
      (await _pages('/v1/me/groups'))
          .map((row) {
            final g = roleMap(row['group']);
            return RecruitmentGroupChoice(
              roleId(g['group_id']),
              raidText(g['name']),
            );
          })
          .toList(growable: false);

  @override
  Future<RecruitmentCreationContext> context(RecruitmentDraft draft) =>
      _decode(() async {
        roleId(draft.characterId);
        final result = (await api.request(
          '/v1/me/raid-room-creation-context',
          query: {
            'character_id': draft.characterId,
            'selected_role': draft.role,
            'items': jsonEncode(draft.items.map((i) => i.choice).toList()),
            'group_id': ?draft.groupId,
          },
        ))!;
        return RecruitmentCreationContext.fromJson(result, draft);
      });

  @override
  Future<RecruitmentCreationAck> create(
    String key,
    Map<String, dynamic> body,
  ) => _decode(() async {
    roleId(key);
    final result = (await api.request(
      '/v1/raid-rooms',
      method: 'POST',
      body: body,
      idempotencyKey: key,
      expectedStatus: 201,
    ))!;
    return RecruitmentCreationAck.fromJson(result, key);
  });

  @override
  Future<BackendRecruitmentDetail> detail(String id) => _decode(() async {
    roleId(id);
    return BackendRecruitmentDetail.fromJson(
      (await api.request('/v1/raid-rooms/$id/detail'))!,
      id,
    );
  });

  @override
  Future<List<String>> currentRoomIds() async => (await _pages(
    '/v1/me/raid-room-memberships',
    query: {'state': 'current'},
  )).map((r) => roleId(r['room_id'])).toList(growable: false);
}
