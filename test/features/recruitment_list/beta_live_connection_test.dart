import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/backend_app.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_interaction_api.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as old;
import 'cycle_interaction_test.dart' as f;
import 'cycle_recruitment_test.dart' as cycles;
import 'membership_actions_test.dart' as membership;

void main() {
  test(
    'ordinary BackendApp selects the implemented beta creation/read path',
    () {
      expect(
        const BackendApp().recruitmentContractMode,
        RecruitmentContractMode.betaWire2,
      );
    },
  );

  test(
    'existing leave/disband menu and ACK use beta profile without changing command',
    () async {
      final api = old.Api();
      final raw = membership.fixture('eight-members-two-targets-context');
      final result = membership.fixture('eight-members-two-targets-result');
      final room = raw['data']['room_id'] as String;
      final target = raw['scope']['view_cycle_key'] as String;
      final repo = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: RecruitmentContractMode.betaWire2,
      );
      api.respond = (_, query) async => raw;
      final context = await repo.membershipContext(room, target);
      final preview = context.select(result['data']['action']);
      api.respond = (_, query) async => result;
      final ack = await repo.writeMembershipAction(
        preview,
        result['data']['command_id'],
        preview.body(),
      );
      expect(ack.affected, preview.affected);
      expect(
        api.requests.every(
          (r) => r['query']['contract_profile'] == BetaContract.profile,
        ),
        isTrue,
      );
      expect(api.requests.last['body'], preview.body());
    },
  );

  test(
    'invalid body fails before HTTP and malformed ACK cannot become success',
    () async {
      final api = old.Api();
      final bridge = BetaInteractionApi(api);
      await expectLater(
        bridge.request(
          '/v2/raid-rooms/${old.roomId}/join',
          method: 'POST',
          body: {},
          idempotencyKey: characterId,
        ),
        throwsFormatException,
      );
      expect(api.requests, isEmpty);
      api.respond = (_, query) async => {'scope': {}, 'data': {}};
      await expectLater(
        bridge.request(
          '/v2/raid-rooms/${old.roomId}/admission-context',
          query: {
            'target_cycle_key': f.n,
            'character_id': characterId,
            'selected_role': 'dealer',
            'intent': 'join',
            'include_session_display': 'true',
          },
        ),
        throwsFormatException,
      );
      expect(api.requests, hasLength(1));
    },
  );

  for (final intent in ['join', 'apply', 'change_character']) {
    test('$intent sends unchanged body/key on repeated requests', () async {
      final api = old.Api();
      final repo = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: RecruitmentContractMode.betaWire2,
      );
      api.respond = (_, query) async {
        final wire = f.admissionWire(f.n, intent: intent);
        wire['data']['beta_schedule'] = null;
        return wire;
      };
      final preview = await repo.admission(
        old.roomId,
        f.n,
        characterId,
        'dealer',
        intent,
      );
      final body = preview.body({});
      if (intent == 'change_character') {
        body['assignments'] = [
          {'assignment_id': old.itemId, 'expected_revision': 1},
        ];
        body['expected_cycle_member_revision'] = 1;
      }
      api.requests.clear();
      api.respond = (_, query) async => cycles.envelope(
        f.n,
        intent == 'apply'
            ? {
                'command_id': characterId,
                'room_id': old.roomId,
                'application_id': old.membershipId,
                'revision': 2,
                'state': 'pending',
                'executed_at': cycles.nowStamp,
                'target_cycle_key': f.n,
              }
            : {
                'command_id': characterId,
                'room_id': old.roomId,
                'outcome': 'applied',
                'executed_at': cycles.nowStamp,
                'target_cycle_key': f.n,
                'revisions': [
                  {'resource': 'room', 'id': old.roomId, 'revision': 2},
                ],
              },
        created: true,
      );
      for (var i = 0; i < 2; i++) {
        await repo.write(
          '/v2/raid-rooms/${old.roomId}/${intent == 'apply'
              ? 'applications'
              : intent == 'join'
              ? 'join'
              : 'character-changes'}',
          characterId,
          body,
          room: old.roomId,
          target: f.n,
          applicationAck: intent == 'apply',
          status: intent == 'apply' ? 201 : 200,
          expectedScope: preview.scope,
        );
      }
      expect(api.requests, hasLength(2));
      for (final request in api.requests) {
        expect(request['body'], same(body));
        expect(request['key'], characterId);
        expect(request['query'], {
          'contract_profile': BetaContract.profile,
          'group_policy_version': BetaContract.groupPolicyVersion,
        });
        expect(
          (request['body'] as Map).containsKey('application_memo'),
          isFalse,
        );
      }
    });
  }

  for (final intent in ['join', 'apply', 'change_character']) {
    test(
      'real repository $intent reads beta context through existing parser',
      () async {
        final api = old.Api();
        api.respond = (path, query) async {
          final wire = f.admissionWire(f.n, intent: intent);
          wire['data']['beta_schedule'] = null;
          return wire;
        };
        final repo = CycleInteractionRepository(
          api: api,
          recruitment: cycles.CycleGateway(),
          contractMode: RecruitmentContractMode.betaWire2,
        );
        final preview = await repo.admission(
          old.roomId,
          f.n,
          characterId,
          'dealer',
          intent,
        );
        expect(preview.target, f.n);
        expect(preview.permission.allowed, isTrue);
        expect(
          api.requests.single['query']['contract_profile'],
          BetaContract.profile,
        );
        expect(api.requests.single['query']['target_cycle_key'], f.n);
        expect(api.requests.single['query']['include_session_display'], 'true');
      },
    );
  }

  test(
    'unknown contract operation cannot silently use an old request',
    () async {
      final api = old.Api();
      await expectLater(
        BetaInteractionApi(api).request('/v2/unknown'),
        throwsFormatException,
      );
      expect(api.requests, isEmpty);
    },
  );

  test(
    'non-recruitment personal availability keeps its original request',
    () async {
      final api = old.Api();
      api.respond = (_, query) async => {'unchanged': true};
      expect(
        await BetaInteractionApi(api).request('/v1/me/play-availability'),
        {'unchanged': true},
      );
      expect(api.requests.single['query'], isNull);
    },
  );
}
