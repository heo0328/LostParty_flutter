import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/scoped_startup_refresh.dart';
import 'package:lost_party/features/account/domain/services/nice_group_policy.dart';
import 'package:lost_party/features/account/presentation/viewmodels/scoped_startup_refresh_controller.dart';
import 'package:lost_party/shared/lost_ark_api/client/api_cooldown.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_exception.dart';

import '../../../support/server_account_read_fakes.dart';
import 'scoped_role_sync_test.dart' as fixtures show catalog;

const member = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const account = '44444444-4444-4444-8444-444444444444';
const account2 = '55555555-5555-4555-8555-555555555555';
const registration2 = '66666666-6666-4666-8666-666666666666';

CacheCharacterObservation character(
  String id, {
  String accountId = account,
  String className = '버서커',
  String level = '1700',
  String state = 'active',
}) => CacheCharacterObservation(
  characterId: id,
  accountId: accountId,
  serverName: 'sample-server',
  characterName: id == characterId ? 'sample' : 'second',
  lifecycleState: state,
  lifecycleRevision: 1,
  usable: state == 'active',
  blockedReason: state == 'active' ? null : 'CHARACTER_UNUSABLE',
  profile: {'class_name': className, 'item_level': level},
);
CacheRosterSnapshot roster(
  List<CacheCharacterObservation> chars, {
  List<String>? active,
  String accountId = account,
  String registration = registrationId,
}) => CacheRosterSnapshot(
  CacheRegistrationSnapshot(
    registrationId: registration,
    accountId: accountId,
    version: 1,
    isMain: accountId == account,
    label: 'sample',
    ownershipStatus: 'owned',
    ownershipRevision: 1,
    rosterRevision: 1,
    settings: CacheSettings(
      version: 1,
      state: 'configured',
      activityIds: active ?? chars.map((c) => c.characterId).toList(),
      representativeId: null,
    ),
    fetchedAt: DateTime.utc(2026),
    sourceContract: 'tests',
  ),
  chars,
);

class FakeSource extends ChangeNotifier implements ScopedStartupRefreshSource {
  FakeSource() {
    cooldown = ApiCooldown(now: () => clock);
  }
  DateTime clock = DateTime.utc(2026, 10, 16);
  @override
  final ReadSessionFake session = ReadSessionFake()..userId = member;
  @override
  late final ApiCooldown cooldown;
  @override
  Listenable get changes => this;
  @override
  StorageScope? get scope => session.isAuthenticated
      ? StorageScope(
          baseUrl: 'https://example.test/api',
          userId: session.userId!,
        )
      : null;
  @override
  int? keyVersion = 1;
  @override
  int? settingsVersion = 1;
  bool nice = true;
  List<CacheRosterSnapshot> rosters = [
    roster([character(characterId), character(secondCharacterId)]),
  ];
  int preparations = 0, uploads = 0;
  final List<String> details = [];
  Object? barrierError;
  Future<void> Function()? waitPrepare;
  Future<void> Function()? onUpload;
  Future<ScopedRefreshItem> Function(
    ScopedRefreshBatch,
    ScopedRefreshTarget,
    void Function(),
    void Function(ScopedRefreshItem),
  )?
  onRefresh;
  void changed() => notifyListeners();
  @override
  void requireCurrent(ScopedRefreshBatch batch) {
    requireAccountReadScope(session, batch.session);
    if (scope != batch.scope || keyVersion != batch.keyVersion) {
      throw const AccountReadException('KEY_CHANGED');
    }
  }

  @override
  Future<ScopedRefreshBatch> prepare() async {
    preparations++;
    if (waitPrepare != null) await waitPrepare!();
    if (barrierError != null) throw barrierError!;
    if (scope == null) throw const AccountReadException('LOGIN_REQUIRED');
    if (settingsVersion == null) {
      throw const AccountReadException('SETTINGS_NOT_READY');
    }
    if (keyVersion == null) throw const AccountReadException('KEY_NOT_READY');
    return ScopedRefreshBatch(
      scope: scope!,
      session: accountReadScope(session),
      keyVersion: keyVersion!,
      settingsVersion: settingsVersion!,
      niceGroupEnabled: nice,
      catalog: fixtures.catalog(),
      targets: projectScopedRefreshTargets(
        scope!,
        rosters,
        niceGroupEnabled: nice,
      ),
    );
  }

  @override
  Future<ScopedRefreshItem> refresh(
    ScopedRefreshBatch batch,
    ScopedRefreshTarget target,
    void Function() guard,
    void Function(ScopedRefreshItem) onLocalSaved,
  ) async {
    requireCurrent(batch);
    guard();
    details.add(target.ref.characterId);
    if (onRefresh != null) {
      return onRefresh!(batch, target, guard, onLocalSaved);
    }
    final saved = ScopedRefreshItem(
      target,
      ScopedRefreshStatus.saved,
      role: CharacterBuildRole.dealer,
    );
    onLocalSaved(saved);
    return saved;
  }

  @override
  Future<ScopedRefreshItem> retryUpload(
    ScopedRefreshItem saved,
    void Function() guard,
  ) async {
    guard();
    uploads++;
    await onUpload?.call();
    guard();
    return ScopedRefreshItem(
      saved.target,
      ScopedRefreshStatus.saved,
      role: saved.role,
      warning: saved.warning,
    );
  }

  @override
  void dispose() {
    cooldown.dispose();
    session.dispose();
    super.dispose();
  }
}

Future<void> settle(ScopedStartupRefreshController c) async {
  await c.startIfReady();
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late FakeSource source;
  late ScopedStartupRefreshController c;
  setUp(() {
    source = FakeSource();
    c = ScopedStartupRefreshController(source);
  });
  tearDown(() {
    c.dispose();
    source.dispose();
  });
  test('automatic display gate also protects a later member login', () async {
    c.dispose();
    var displayed = false;
    c = ScopedStartupRefreshController(
      source,
      canStartAutomatically: () => displayed,
    );
    c.initialize();
    await settle(c);
    expect(source.preparations, 0);
    displayed = true;
    source.changed();
    await settle(c);
    expect(c.savedCount, 2);
    displayed = false;
    source.session.change(authenticated: true, user: other);
    await settle(c);
    expect(source.details, hasLength(2));
    expect(c.consumed, isFalse);
    displayed = true;
    source.changed();
    await settle(c);
    expect(c.savedCount, 2);
    expect(source.details, hasLength(4));
  });
  test(
    'two workers refill an available slot and await the final worker',
    () async {
      final ids = [characterId, secondCharacterId, registration2, other];
      source.rosters = [roster(ids.map(character).toList())];
      final release = {for (final id in ids) id: Completer<void>()};
      final entered = {for (final id in ids) id: Completer<void>()};
      var active = 0, maximum = 0;
      source.onRefresh = (b, t, g, saved) async {
        active++;
        if (active > maximum) maximum = active;
        entered[t.ref.characterId]!.complete();
        try {
          await release[t.ref.characterId]!.future;
          g();
          final result = ScopedRefreshItem(t, ScopedRefreshStatus.saved);
          saved(result);
          return result;
        } finally {
          active--;
        }
      };
      c.initialize();
      final flight = c.startIfReady();
      await Future.wait([entered[ids[0]]!.future, entered[ids[1]]!.future]);
      expect(source.details, ids.take(2));
      release[ids[1]]!.complete();
      await entered[ids[2]]!.future;
      expect(c.savedCount, 1);
      expect(active, 2);
      release[ids[2]]!.complete();
      await entered[ids[3]]!.future;
      release[ids[3]]!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(c.isBusy, isTrue);
      release[ids[0]]!.complete();
      await flight;
      expect(maximum, 2);
      expect(source.details.toSet(), ids.toSet());
      expect(source.details, hasLength(4));
      expect(c.processedCount, 4);
      expect(c.savedCount, 4);
      expect(c.isBusy, isFalse);
    },
  );
  test(
    '429 stops unstarted work but retains a valid in-flight peer save',
    () async {
      source.rosters = [
        roster([
          character(characterId),
          character(secondCharacterId),
          character(registration2),
        ]),
      ];
      final entered = Completer<void>(),
          limited = Completer<void>(),
          peer = Completer<void>();
      source.onRefresh = (b, t, g, saved) async {
        if (t.ref.characterId == characterId) {
          await limited.future;
          throw LostArkApiException(type: LostArkApiErrorType.rateLimited);
        }
        entered.complete();
        await peer.future;
        g();
        final result = ScopedRefreshItem(t, ScopedRefreshStatus.saved);
        saved(result);
        return result;
      };
      c.initialize();
      final flight = c.startIfReady();
      await entered.future;
      limited.complete();
      await Future<void>.delayed(Duration.zero);
      expect(source.cooldown.active, isTrue);
      expect(source.details, hasLength(2));
      expect(c.isBusy, isTrue);
      peer.complete();
      await flight;
      expect(source.details, hasLength(2));
      expect(c.savedCount, 1);
      expect(c.incompleteCount, 2);
      expect(c.items.last.status, ScopedRefreshStatus.interrupted);
      expect(c.failure, 'RATE_LIMITED');
    },
  );
  test(
    'construct is IO-free; initialization and reentrant starts share one operation',
    () async {
      expect(source.preparations, 0);
      var notified = false;
      c.addListener(() {
        if (!notified) {
          notified = true;
          unawaited(c.startIfReady());
        }
      });
      c.initialize();
      final first = c.startIfReady(), second = c.startIfReady();
      expect(identical(first, second), isTrue);
      await first;
      expect(source.preparations, 1);
      expect(c.savedCount, 2);
      await c.startIfReady();
      source.changed();
      await settle(c);
      expect(source.preparations, 1);
    },
  );
  for (final code in [
    'SETTINGS_NOT_READY',
    'KEY_NOT_READY',
    'ROSTER_FAILED',
    'CATALOG_FAILED',
  ]) {
    test(
      'barrier $code does not consume member once or fetch armory',
      () async {
        source.barrierError = AccountReadException(code);
        c.initialize();
        await settle(c);
        expect(c.phase, ScopedRefreshPhase.blocked);
        expect(c.consumed, isFalse);
        expect(source.details, isEmpty);
        source.barrierError = null;
        source.changed();
        await settle(c);
        expect(c.savedCount, 2);
        expect(c.consumed, isTrue);
      },
    );
  }
  test(
    'guest remains private and never consumes an authenticated member run',
    () async {
      source.session.change(authenticated: false);
      c.initialize();
      await settle(c);
      expect(c.consumed, isFalse);
      expect(c.items, isEmpty);
      source.session.change(authenticated: true, user: member);
      await settle(c);
      expect(c.savedCount, 2);
    },
  );
  test('zero targets completes once without repeatedly preparing', () async {
    source.rosters = [];
    c.initialize();
    await settle(c);
    expect(c.consumed, isTrue);
    expect(c.totalCount, 0);
    source.changed();
    await settle(c);
    expect(source.preparations, 1);
  });
  test(
    'activation includes below-1700 and full set, independent of representative or display count',
    () async {
      source.rosters = [
        roster([
          character(characterId, level: '1600'),
          character(secondCharacterId),
        ]),
      ];
      c.initialize();
      await settle(c);
      expect(source.details, [characterId, secondCharacterId]);
    },
  );
  test(
    'NiceGroup OFF classifies full rosters including inactive rows across accounts',
    () async {
      source.nice = false;
      source.rosters = [
        roster([character(characterId)]),
        roster(
          [character(secondCharacterId, accountId: account2)],
          accountId: account2,
          registration: registration2,
          active: [],
        ),
      ];
      c.initialize();
      await settle(c);
      expect(c.excludedCount, 1);
      expect(c.items.single.code, 'NICE_GROUP_OFF');
      expect(source.details, isEmpty);
      source.nice = true;
      source.settingsVersion = 2;
      source.changed();
      await settle(c);
      expect(source.details, isEmpty);
    },
  );
  test(
    'suspect active selection is excluded and not used to classify a valid same-class row',
    () async {
      source.nice = false;
      source.rosters = [
        roster([
          character(characterId),
          character(secondCharacterId, state: 'suspect'),
        ]),
      ];
      c.initialize();
      await settle(c);
      expect(source.details, [characterId]);
      expect(c.excludedCount, 1);
      expect(c.savedCount, 1);
    },
  );
  test(
    'existing NiceGroup candidate threshold and normalization remain shared policy',
    () {
      final result = const NiceGroupPolicy().evaluateCandidates([
        const NiceGroupCandidate('BARD', 1700),
        const NiceGroupCandidate(' bard ', 1750),
        const NiceGroupCandidate('dealer', 1600),
        const NiceGroupCandidate('dealer', 1800),
      ]);
      expect(result.containsClass(' Bard '), isTrue);
      expect(result.containsClass('dealer'), isFalse);
    },
  );
  test(
    'duplicate canonical IDs and selected IDs absent from full roster fail preparation',
    () {
      final scope = source.scope!;
      expect(
        () => projectScopedRefreshTargets(scope, [
          roster([character(characterId)]),
          roster(
            [character(characterId, accountId: account2)],
            accountId: account2,
            registration: registration2,
          ),
        ], niceGroupEnabled: true),
        throwsA(isA<ScopedCacheException>()),
      );
      expect(
        () => projectScopedRefreshTargets(scope, [
          roster([character(characterId)], active: [secondCharacterId]),
        ], niceGroupEnabled: true),
        throwsA(isA<ScopedCacheException>()),
      );
    },
  );
  test(
    'settings change during execution preserves starting snapshot and only retry re-evaluates policy',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      bool fail = true;
      source.onRefresh = (batch, t, guard, saved) async {
        if (t.ref.characterId == characterId) {
          if (!entered.isCompleted) entered.complete();
          await release.future;
          guard();
        }
        if (t.ref.characterId == secondCharacterId && fail) {
          throw const FormatException();
        }
        final item = ScopedRefreshItem(
          t,
          ScopedRefreshStatus.saved,
          role: CharacterBuildRole.dealer,
        );
        saved(item);
        return item;
      };
      c.initialize();
      final flight = c.startIfReady();
      await entered.future;
      source.nice = false;
      source.settingsVersion = 2;
      source.changed();
      expect(c.settingsChanged, isTrue);
      release.complete();
      await flight;
      expect(c.savedCount, 1);
      expect(c.incompleteCount, 1);
      expect(source.details, hasLength(2));
      fail = false;
      await c.retryIncomplete();
      expect(c.savedCount, 1);
      expect(c.excludedCount, 1);
      expect(source.details, hasLength(2));
    },
  );
  test(
    'retry includes only original unfinished IDs, never prior success or new active character',
    () async {
      bool fail = true;
      source.onRefresh = (b, t, g, s) async {
        if (t.ref.characterId == secondCharacterId && fail) {
          throw const FormatException();
        }
        final item = ScopedRefreshItem(
          t,
          ScopedRefreshStatus.saved,
          role: CharacterBuildRole.dealer,
        );
        s(item);
        return item;
      };
      c.initialize();
      await settle(c);
      expect(c.savedCount, 1);
      expect(c.incompleteCount, 1);
      source.rosters = [
        roster([
          character(characterId),
          character(secondCharacterId),
          character(registration2),
        ]),
      ];
      fail = false;
      await c.retryIncomplete();
      expect(source.details, [
        characterId,
        secondCharacterId,
        secondCharacterId,
      ]);
      expect(c.savedCount, 2);
      expect(c.totalCount, 2);
    },
  );
  test(
    'retry removes no-longer-active target instead of restoring its old row',
    () async {
      source.onRefresh = (b, t, g, s) async => throw const FormatException();
      c.initialize();
      await settle(c);
      source.rosters = [];
      await c.retryIncomplete();
      expect(c.excludedCount, 2);
      expect(c.incompleteCount, 0);
      expect(source.details, hasLength(2));
    },
  );
  test(
    'key change interrupts remaining and rejects delayed old detail write',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      int committed = 0;
      source.onRefresh = (b, t, g, s) async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        g();
        committed++;
        return ScopedRefreshItem(t, ScopedRefreshStatus.saved);
      };
      c.initialize();
      final flight = c.startIfReady();
      await entered.future;
      source.keyVersion = 2;
      source.changed();
      release.complete();
      await flight;
      expect(committed, 0);
      expect(c.incompleteCount, 2);
      expect(c.consumed, isTrue);
      source.onRefresh = null;
      await c.startIfReady();
      expect(source.details, hasLength(2));
      await c.retryIncomplete();
      expect(c.savedCount, 2);
    },
  );
  test(
    'logout/new member clears visible data, returning member does not automatically repeat',
    () async {
      c.initialize();
      await settle(c);
      expect(c.savedCount, 2);
      source.session.change(authenticated: false);
      expect(c.items, isEmpty);
      await settle(c);
      source.session.change(authenticated: true, user: other);
      await settle(c);
      expect(c.savedCount, 2);
      expect(source.details, hasLength(4));
      source.session.change(authenticated: true, user: member);
      await settle(c);
      expect(c.savedCount, 2);
      expect(source.details, hasLength(4));
    },
  );
  test(
    'same-member new session interrupts the old task and requires explicit retry',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      source.onRefresh = (b, t, g, s) async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        g();
        return ScopedRefreshItem(t, ScopedRefreshStatus.saved);
      };
      c.initialize();
      final flight = c.startIfReady();
      await entered.future;
      source.session.change(authenticated: true, user: member);
      release.complete();
      await flight;
      expect(c.incompleteCount, 2);
      expect(source.details, hasLength(2));
      source.onRefresh = null;
      await c.retryIncomplete();
      expect(c.savedCount, 2);
    },
  );
  test(
    'completed local save is preserved if key changes before upload completes',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      source.onRefresh = (b, t, g, s) async {
        final item = ScopedRefreshItem(
          t,
          ScopedRefreshStatus.saved,
          role: CharacterBuildRole.dealer,
          warning: true,
          serverPending: true,
        );
        if (t.ref.characterId == characterId) s(item);
        if (!entered.isCompleted) entered.complete();
        await release.future;
        g();
        if (t.ref.characterId != characterId) s(item);
        return item;
      };
      c.initialize();
      final flight = c.startIfReady();
      await entered.future;
      source.keyVersion = null;
      source.changed();
      release.complete();
      await flight;
      expect(c.savedCount, 1);
      expect(c.warningCount, 1);
      expect(c.pendingServerCount, 1);
      expect(c.incompleteCount, 1);
      source.onUpload = () async {
        source.settingsVersion = 2;
        source.changed();
      };
      await c.retryServerSaved();
      expect(source.uploads, 1);
      expect(c.pendingServerCount, 0);
      expect(source.details, hasLength(2));
    },
  );
  test(
    'commit receipt delivered just after cancellation still records a legitimate completed local save',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      source.onRefresh = (b, t, g, s) async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        final item = ScopedRefreshItem(
          t,
          ScopedRefreshStatus.saved,
          role: CharacterBuildRole.dealer,
          serverPending: true,
        );
        if (t.ref.characterId != characterId) g();
        s(item);
        g();
        return item;
      };
      c.initialize();
      final flight = c.startIfReady();
      await entered.future;
      source.session.change(authenticated: false);
      release.complete();
      await flight;
      expect(c.items, isEmpty);
      source.session.change(authenticated: true, user: member);
      await settle(c);
      expect(c.savedCount, 1);
      expect(c.incompleteCount, 1);
    },
  );
  test(
    'provider 429 stops queue, fixed deadline expiry never makes an automatic request',
    () async {
      bool limited = true;
      source.onRefresh = (b, t, g, s) async {
        if (limited) {
          throw LostArkApiException(
            type: LostArkApiErrorType.rateLimited,
            retryAt: source.clock.add(const Duration(seconds: 10)),
          );
        }
        final item = ScopedRefreshItem(t, ScopedRefreshStatus.saved);
        s(item);
        return item;
      };
      c.initialize();
      await settle(c);
      expect(c.incompleteCount, 2);
      expect(c.canRetry, isFalse);
      expect(source.details, hasLength(2));
      await c.retryIncomplete();
      expect(source.details, hasLength(2));
      source.clock = source.clock.add(const Duration(seconds: 10));
      source.cooldown.observe(source.cooldown.until!);
      await Future<void>.delayed(Duration.zero);
      expect(source.details, hasLength(2));
      expect(c.canRetry, isTrue);
      limited = false;
      await c.retryIncomplete();
      expect(c.savedCount, 2);
    },
  );
  test(
    'cooldown before first attempt blocks preparation without consuming once',
    () async {
      source.cooldown.observe(source.clock.add(const Duration(seconds: 10)));
      c.initialize();
      await settle(c);
      expect(c.consumed, isFalse);
      expect(source.preparations, 0);
      source.clock = source.clock.add(const Duration(seconds: 10));
      source.cooldown.observe(source.cooldown.until!);
      await Future<void>.delayed(Duration.zero);
      expect(source.preparations, 0);
      await c.startIfReady();
      expect(c.savedCount, 2);
    },
  );
  test(
    'dispose during delayed response prevents any later guarded commit or notifications',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      int writes = 0;
      source.onRefresh = (b, t, g, s) async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        g();
        writes++;
        return ScopedRefreshItem(t, ScopedRefreshStatus.saved);
      };
      c.initialize();
      final flight = c.startIfReady();
      await entered.future;
      c.dispose();
      release.complete();
      await flight;
      expect(writes, 0);
    },
  );
}
