import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/ownership_command_store.dart';
import 'package:lost_party/features/account/domain/ownership_command.dart';
import 'package:lost_party/features/account/presentation/viewmodels/ownership_dispute_controller.dart';
import 'package:lost_party/features/account/presentation/viewmodels/ownership_verification_view_model.dart';
import '../../../support/server_account_read_fakes.dart' show ReadSessionFake;
import 'ownership_dispute_client_test.dart' show JournalFake, OwnershipApiFake;
import 'ownership_dispute_fixtures.dart';
import 'server_character_lifecycle_client_test.dart' as lifecycle;

void main() {
  late ReadSessionFake session;
  late OwnershipApiFake api;
  late OwnershipDisputeController controller;
  late OwnershipVerificationViewModel model;
  late Map<String, dynamic> preview, roster;
  Future<Map<String, dynamic>?> reply() async {
    final call = api.calls.last;
    if (call.path.endsWith('/preview')) return preview;
    if (call.path.endsWith('/characters')) return roster;
    if (call.path == OwnershipCommand.proofsPath && call.method == 'GET') {
      return pageJson([]);
    }
    if (call.path == OwnershipCommand.disputesPath) {
      return pageJson([disputeJson(role: 'owner')]);
    }
    if (call.path.startsWith(OwnershipCommand.disputesPath) &&
        call.method == 'GET') {
      return disputeJson(role: 'owner');
    }
    return proofJson(defense: call.path.endsWith('/defenses'));
  }

  setUp(() async {
    session = ReadSessionFake()..userId = ownerId;
    api = OwnershipApiFake()..respond = reply;
    preview = previewJson();
    roster = {
      ...lifecycle.roster(),
      'registration_id': regId,
      'items': [
        {...lifecycle.item(id: charId), 'item_level': '1500.00'},
      ],
    };
    controller = OwnershipDisputeController(
      api: api,
      session: session,
      baseUrl: 'https://example.test',
      commands: OwnershipCommandStore(JournalFake()),
      now: () => clockNow,
    );
    await controller.refresh();
    model = OwnershipVerificationViewModel(controller);
  });
  tearDown(() {
    model.dispose();
    controller.dispose();
    session.dispose();
  });
  test(
    'preview is read-only and self ownership cannot start a claim',
    () async {
      preview['ownership_context'] = {
        ...contextJson(),
        'relation': 'self',
        'notice_code': null,
        'can_start_claim': false,
        'blocked_reason': 'ALREADY_VERIFIED',
      };
      await model.inspect('Hero');
      await model.startClaim();
      expect(model.failure?.code, 'CURRENT_READ_REQUIRED');
      expect(api.calls.where((c) => c.key != null), isEmpty);
    },
  );
  test(
    'other owner preview never starts a dispute; explicit start creates one immutable command',
    () async {
      await model.inspect('Hero');
      expect(api.calls.where((c) => c.key != null), isEmpty);
      await model.startClaim();
      final posts = api.calls.where((c) => c.key != null).toList();
      expect(posts, hasLength(1));
      expect(posts.single.body, {
        'source': 'direct_input',
        'character_name': 'Hero',
      });
      expect(controller.selectedProofId, proofId);
    },
  );
  test('clearing a changed selection prevents using old preview', () async {
    await model.inspect('Hero');
    model.clearPreview();
    await model.startClaim();
    expect(model.failure?.code, 'CURRENT_READ_REQUIRED');
    expect(api.calls.where((c) => c.key != null), isEmpty);
  });
  test(
    'late preview after member change never populates the new member form',
    () async {
      final delayed = Completer<Map<String, dynamic>?>();
      api.respond = () => delayed.future;
      final future = model.inspect('Hero');
    session.userId = '22222222-2222-4222-8222-222222222222';
    session.change(authenticated: true);
      delayed.complete(preview);
      await future;
      expect(model.preview, isNull);
      expect(model.failure, isNull);
    },
  );
  test(
    'double tap while preview is pending shares no second request',
    () async {
      final delayed = Completer<Map<String, dynamic>?>();
      api.respond = () => delayed.future;
      final before = api.calls.length;
      final first = model.inspect('Hero');
      await model.inspect('Other');
      delayed.complete(preview);
      await first;
      expect(api.calls.length - before, 1);
    },
  );
  test(
    'defense selection includes low level inactive usable character, without auto write',
    () async {
      await model.prepareDefense(disputeId);
      expect(model.failure, isNull);
      expect(model.defenseCharacters.single.characterId, charId);
      expect(model.defenseCharacter, isNull);
      expect(api.calls.where((c) => c.key != null), isEmpty);
      model.chooseDefense(charId);
      await model.startDefense();
      final write = api.calls.singleWhere((c) => c.path.endsWith('/defenses'));
      expect((write.body!['selection'] as Map)['character_id'], charId);
      expect((write.body!['selection'] as Map)['expected_roster_revision'], 2);
    },
  );
  test('unusable character cannot become defense selection', () async {
    roster['items'] = [
      {
        ...lifecycle.item(id: charId),
        'usable': false,
        'lifecycle_state': 'suspect',
        'blocked_reason': 'CHARACTER_UNUSABLE',
      },
    ];
    await model.prepareDefense(disputeId);
    model.chooseDefense(charId);
    await model.startDefense();
    expect(model.defenseCharacters, isEmpty);
    expect(model.failure?.code, 'CURRENT_READ_REQUIRED');
    expect(api.calls.where((c) => c.key != null), isEmpty);
  });
  test(
    'partial inconsistent paginated defense roster never exposes candidates',
    () async {
      var page = 0;
      api.respond = () async {
        if (!api.calls.last.path.endsWith('/characters')) return reply();
        page++;
        return {
          ...roster,
          'next_cursor': page == 1 ? 'next' : null,
          'roster_revision': page == 1 ? 2 : 3,
        };
      };
      await model.prepareDefense(disputeId);
      expect(model.failure?.code, 'CURSOR_STALE');
      expect(model.defenseCharacters, isEmpty);
    },
  );
  test(
    'session change during defense roster fetch discards candidate revisions',
    () async {
      final delayed = Completer<Map<String, dynamic>?>();
      final entered = Completer<void>();
      api.respond = () async {
        if (!api.calls.last.path.endsWith('/characters')) return reply();
        entered.complete();
        return delayed.future;
      };
      final future = model.prepareDefense(disputeId);
      await entered.future;
      session.change(authenticated: false);
      delayed.complete(roster);
      await future;
      expect(model.defenseRoster, isNull);
      expect(model.defenseCharacters, isEmpty);
    },
  );
}
