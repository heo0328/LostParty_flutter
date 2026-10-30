import 'dart:convert';
import 'beta/beta_contract.dart';
import 'beta/beta_read.dart';
import 'beta/beta_creation_gateway.dart';
import 'beta/recruitment_command.dart';

import '../../account/data/member_raid_client.dart';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/server_account_read_repository.dart';
import '../../account/domain/server_registration_api.dart';
import '../../account/domain/services/account_detail_access.dart';
import '../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../domain/backend_recruitment.dart';
import '../../account/domain/member_cycle_models.dart';
import 'cycle_read_repository.dart';
import 'application_display.dart';

class BackendRecruitmentRepository
    implements
        CycleRecruitmentGateway,
        RecruitmentAvailabilityGateway,
        BetaCreationGateway,
        ApplicationDisplayGateway {
  BackendRecruitmentRepository({
    required this.api,
    this.includeGroupState = false,
    required this.accounts,
    required this.raids,
    this.twoCycleEnabled = false,
    this.preferredRoles,
    this.contractMode = RecruitmentContractMode.legacy,
  });
  final bool includeGroupState;
  final BackendRegistrationApi api;
  final RecruitmentContractMode contractMode;
  @override
  bool get betaContractActive =>
      contractMode == RecruitmentContractMode.betaWire2;
  @override
  RecruitmentCommand prepareBetaCreation(
    RecruitmentDraft draft,
    RecruitmentCreationContext context,
    String title,
    String key,
    DateTime createdAt,
  ) => BetaCreationReader.prepare(draft, context, title, key, createdAt);
  @override
  Future<ApplicationDisplayDetail> applicationDisplayDetail(
    String room,
    String target, {
    bool includeCoordinationWait = false,
  }) =>
      ApplicationDisplayReader(
        api,
        contractMode: contractMode,
        includeGroupState: includeGroupState,
      ).applicationDisplayDetail(
        room,
        target,
        includeCoordinationWait: includeCoordinationWait,
      );
  final ServerAccountReadRepository accounts;
  final MemberRaidClient raids;
  final Future<Map<String, String>> Function()? preferredRoles;
  @override
  final bool twoCycleEnabled;
  @override
  Future<MemberCycles> cycles() => raids.cycles();

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
  Future<Set<String>> unavailableRaids(
    String character,
    List<String> targets,
    RaidCatalog catalog,
  ) async {
    final scope = accountReadScope(accounts.session);
    final summary = await raids.summary([character], targets);
    requireAccountReadScope(accounts.session, scope);
    roleCheck(
      summary.targets.length == targets.length &&
          summary.targets.containsAll(targets),
    );
    if (summary.catalogVersion != catalog.catalogVersion) {
      throw const AccountReadException('CATALOG_VERSION_CONFLICT');
    }
    final expected = {
      for (final t in targets)
        for (final raid in catalog.raids) '$t:${raid.raidId}',
    };
    final unavailable = <String>{};
    for (final entry in summary.entries) {
      roleCheck(
        entry.characterId == character &&
            expected.remove('${entry.cycleKey}:${entry.raidId}'),
      );
      if (entry.manual || entry.party || entry.participating) {
        unavailable.add(entry.raidId);
      }
    }
    roleCheck(expected.isEmpty);
    return Set.unmodifiable(unavailable);
  }

  @override
  Future<List<RecruitmentCharacter>> characters() async {
    final scope = accountReadScope(accounts.session);
    final preferences =
        await preferredRoles?.call() ?? const <String, String>{};
    requireAccountReadScope(accounts.session, scope);
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
            preferredRole: preferences[c.characterId],
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
        if (betaContractActive) return BetaCreationReader(api).context(draft);
        roleId(draft.characterId);
        final result = (await api.request(
          twoCycleEnabled
              ? '/v2/me/raid-room-creation-context'
              : '/v1/me/raid-room-creation-context',
          query: {
            if (twoCycleEnabled) ...{
              'target_cycle_key': raidCycleKey(draft.targetCycleKey),
              'continuation_enabled': draft.continueTogether,
            },
            'character_id': draft.characterId,
            'selected_role': draft.role,
            'items': jsonEncode(draft.items.map((i) => i.choice).toList()),
            'group_id': ?draft.groupId,
          },
        ))!;
        if (!twoCycleEnabled) {
          return RecruitmentCreationContext.fromJson(result, draft);
        }
        roleShape(result, 'scope data');
        CycleReadScope(roleMap(result['scope']), draft.targetCycleKey!);
        roleCheck(
          roleMap(result['scope'])['current_cycle_key'] ==
              roleMap(result['data'])['expected_cycle_key'],
        );
        return RecruitmentCreationContext.fromCycleJson(
          roleMap(result['data']),
          draft,
        );
      });

  @override
  Future<RecruitmentCreationAck> create(
    String key,
    Map<String, dynamic> body,
  ) => _decode(() async {
    roleId(key);
    final result = (await api.request(
      twoCycleEnabled ? '/v2/raid-rooms' : '/v1/raid-rooms',
      method: 'POST',
      body: body,
      idempotencyKey: key,
      expectedStatus: 201,
    ))!;
    if (!twoCycleEnabled) return RecruitmentCreationAck.fromJson(result, key);
    roleShape(result, 'scope data');
    final target = raidCycleKey(body['target_cycle_key']);
    final scope = roleMap(result['scope']);
    CycleReadScope(scope, target);
    final ack = RecruitmentCreationAck.fromCycleJson(
      roleMap(result['data']),
      key,
      body,
    );
    final created = ack.created!.singleWhere(
      (v) => v['target_cycle_key'] == target,
    );
    roleCheck(
      created['room_cycle_id'] == scope['room_cycle_id'] &&
          created['generation'] == scope['target_generation'] &&
          created['target_revision'] == scope['target_revision'],
    );
    return ack;
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

  @override
  Future<List<String>> roomIdsFor(String target) => _decode(() async {
    final ids = <String>{}, cursors = <String>{};
    String? cursor;
    for (var n = 0; n < 100; n++) {
      final j = (await api.request(
        '/v2/me/raid-room-memberships',
        query: {
          'target_cycle_key': target,
          'state': 'current',
          'limit': 20,
          'cursor': ?cursor,
        },
      ))!;
      final page = CycleOwnPage(j, target, false);
      ids.addAll(page.rows.where((r) => r.canView).map((r) => r.roomId));
      cursor = page.cursor;
      if (cursor == null) return ids.toList();
      roleCheck(cursors.add(cursor));
    }
    throw const FormatException('Pagination limit');
  });

  @override
  Future<BackendRecruitmentDetail> cycleDetail(String id, String target) =>
      _decode(() async {
        roleId(id);
        raidCycleKey(target);
        final result = await readRecruitment(
          api: api,
          mode: contractMode,
          includeGroupState: includeGroupState,
          path: '/v2/raid-rooms/$id/detail',
          query: {'target_cycle_key': target},
          parse: (j) => parseCycleDetail(j, id, target),
        );
        return result.value..betaData = betaDisplayData(result.metadata);
      });

  /// Parses an existing full envelope, including one nested in a reader profile.
  static BackendRecruitmentDetail parseCycleDetail(
    Map<String, dynamic> j,
    String id,
    String target,
  ) {
    roleShape(j, 'scope data');
    final scope = roleMap(j['scope']), data = roleMap(j['data']);
    CycleReadScope(scope, target);
    roleShape(
      data,
      'room settings members_revision members my_membership plan_revision permissions access leadership my_target_role formation_slots formation_history unplaced_assignments',
    );
    final card = CycleRoomCard(roleMap(data['room']), target);
    roleCheck(
      card.id == id &&
          card.wire['room_cycle_id'] == scope['room_cycle_id'] &&
          card.wire['target_generation'] == scope['target_generation'] &&
          card.wire['target_revision'] == scope['target_revision'],
    );
    final members = raidList(data['members'])
        .map((raw) {
          final m = roleMap(raw);
          roleShape(
            m,
            'membership_id revision group_member joined_at character assignments comparison build is_me status status_reason target_role cycle_member_id cycle_member_revision joined_order target_state',
          );
          roleCheck({'leader', 'member', 'none'}.contains(m['target_role']));
          roleCheck(
            {
              'participating',
              'completed',
              'stopped',
              'review_required',
            }.contains(m['target_state']),
          );
          if (m['cycle_member_id'] != null) roleId(m['cycle_member_id']);
          if (m['cycle_member_revision'] != null) {
            rolePositive(m['cycle_member_revision']);
          }
          // Persistent membership is not a confirmed target participant.
          if (m['target_role'] == 'none') return null;
          roleCheck(m['cycle_member_id'] != null);
          if (m['target_role'] == 'leader') {
            roleCheck(
              m['cycle_member_id'] ==
                      roleMap(
                        card.wire['leadership'],
                      )['leader_cycle_member_id'] &&
                  m['membership_id'] ==
                      roleMap(card.wire['leadership'])['leader_membership_id'],
            );
          }
          final order = m['joined_order'];
          roleCheck(
            order is String &&
                RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(order) &&
                BigInt.parse(order) <= BigInt.parse('9223372036854775807'),
          );
          for (final raw in raidList(m['assignments'])) {
            final a = roleMap(raw);
            roleShape(
              a,
              'assignment_id item_id round_id state party_no slot_no',
            );
            roleId(a['assignment_id']);
            roleId(a['item_id']);
            roleId(a['round_id']);
            roleCheck(
              card.items.any(
                    (i) =>
                        i['item_id'] == a['item_id'] &&
                        i['round_id'] == a['round_id'],
                  ) &&
                  {1, 2}.contains(a['party_no']) &&
                  {1, 2, 3, 4}.contains(a['slot_no']),
            );
          }
          return <String, dynamic>{
            for (final k
                in 'membership_id revision group_member joined_at character assignments comparison build is_me status status_reason'
                    .split(' '))
              k: m[k],
            'room_role': m['target_role'],
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
    roleCheck(
      members.map((m) => m['membership_id']).toSet().length == members.length,
    );
    final leadership = roleMap(data['leadership']);
    roleShape(
      leadership,
      'leader_cycle_member_id leadership_revision leader_membership_id',
    );
    roleCheck(
      leadership.keys.every(
            (k) => leadership[k] == roleMap(card.wire['leadership'])[k],
          ) &&
          data['my_target_role'] == card.wire['my_target_role'],
    );
    final value = BackendRecruitmentDetail.fromJson({
      'room': {...card.wire, 'cycle_key': target},
      for (final k
          in 'settings members_revision my_membership plan_revision permissions access'
              .split(' '))
        k: data[k],
      'members': members,
    }, id);
    value.targetKey = target;
    value.cycleMemberIds = Map.unmodifiable({
      for (final raw in raidList(data['members']))
        if (roleMap(raw)['cycle_member_id'] != null &&
            {
              'participating',
              'review_required',
            }.contains(roleMap(raw)['target_state']))
          roleMap(raw)['membership_id'] as String:
              roleMap(raw)['cycle_member_id'] as String,
    });
    final slotKeys = <String>{}, assignmentKeys = <String>{};
    value.formation = raidList(data['formation_slots']).map((raw) {
      final f = roleMap(raw);
      roleShape(
        f,
        'target_cycle_key round_id party_no slot_no assignment_id status is_leader',
      );
      roleCheck(
        f['target_cycle_key'] == target &&
            {1, 2}.contains(f['party_no']) &&
            {1, 2, 3, 4}.contains(f['slot_no']),
      );
      roleId(f['round_id']);
      roleCheck(
        card.items.any((i) => i['round_id'] == f['round_id']) &&
            {
              'empty',
              'participating',
              'completed',
              'review_required',
            }.contains(f['status']),
      );
      roleCheck(
        slotKeys.add('${f['round_id']}/${f['party_no']}/${f['slot_no']}'),
      );
      if (f['assignment_id'] != null) {
        roleCheck(assignmentKeys.add(f['assignment_id'] as String));
        roleCheck(
          members.any(
            (m) => (m['assignments'] as List).any(
              (a) =>
                  a['assignment_id'] == f['assignment_id'] &&
                  a['round_id'] == f['round_id'] &&
                  a['party_no'] == f['party_no'] &&
                  a['slot_no'] == f['slot_no'],
            ),
          ),
        );
      }
      if (f['assignment_id'] != null) roleId(f['assignment_id']);
      raidBool(f['is_leader']);
      return Map<String, dynamic>.unmodifiable(f);
    }).toList();
    return value;
  }
}
