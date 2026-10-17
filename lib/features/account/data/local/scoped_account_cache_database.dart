import 'package:drift/drift.dart';

part 'scoped_account_cache_database.g.dart';

class CacheScopes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get environment => text()();
  TextColumn get userId => text()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get snapshotSequence => integer().withDefault(const Constant(0))();
  @override
  List<Set<Column>> get uniqueKeys => [
    {environment, userId},
  ];
  @override
  List<String> get customConstraints => [
    'CHECK (local_version >= 1 AND snapshot_sequence >= 0)',
  ];
}

class CachedAccountHeads extends Table {
  IntColumn get scopeId =>
      integer().references(CacheScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get accountId => text()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get snapshotSequence => integer().withDefault(const Constant(0))();
  BoolColumn get complete => boolean().withDefault(const Constant(false))();
  IntColumn get ownershipRevisionFloor => integer().nullable()();
  IntColumn get rosterRevisionFloor =>
      integer().withDefault(const Constant(0))();
  IntColumn get settingsOwnershipRevision => integer().nullable()();
  IntColumn get settingsVersionFloor =>
      integer().withDefault(const Constant(0))();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {scopeId, accountId};
  @override
  List<String> get customConstraints => [
    'CHECK (local_version >= 1 AND snapshot_sequence >= 0)',
    'CHECK (complete = 0 OR snapshot_sequence > 0)',
    'CHECK ((ownership_revision_floor IS NULL OR ownership_revision_floor > 0) AND roster_revision_floor >= 0 AND settings_version_floor >= 0)',
  ];
}

class CachedRegistrations extends Table {
  IntColumn get scopeId =>
      integer().references(CacheScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get registrationId => text()();
  TextColumn get accountId => text().nullable()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get seenSequence => integer()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {scopeId, registrationId};
  @override
  List<String> get customConstraints => [
    'CHECK (local_version >= 1 AND seen_sequence > 0)',
    'FOREIGN KEY (scope_id, account_id) REFERENCES cached_account_heads(scope_id, account_id) ON DELETE RESTRICT',
  ];
}

class CachedCharacters extends Table {
  IntColumn get scopeId =>
      integer().references(CacheScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get characterId => text()();
  TextColumn get accountId => text()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get seenSequence => integer()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {scopeId, characterId};
  @override
  List<String> get customConstraints => [
    'CHECK (local_version >= 1 AND seen_sequence > 0)',
    'FOREIGN KEY (scope_id, account_id) REFERENCES cached_account_heads(scope_id, account_id) ON DELETE RESTRICT',
  ];
}

class ScopedRoleRecords extends Table {
  IntColumn get scopeId => integer()();
  TextColumn get characterId => text()();
  TextColumn get accountId => text()();
  IntColumn get ownershipRevision => integer()();
  TextColumn get role => text()();
  IntColumn get rowVersion => integer()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {scopeId, characterId, ownershipRevision, role};
  @override
  List<String> get customConstraints => [
    'CHECK (ownership_revision > 0 AND row_version > 0)',
    "CHECK (role IN ('dealer', 'support'))",
    'FOREIGN KEY (scope_id, account_id, character_id) REFERENCES cached_characters(scope_id, account_id, character_id) ON DELETE RESTRICT',
  ];
}

@DataClassName('RoleOutboxRow')
class ScopedRoleCommands extends Table {
  IntColumn get scopeId => integer()();
  TextColumn get commandId => text()();
  TextColumn get characterId => text()();
  IntColumn get ownershipRevision => integer()();
  TextColumn get role => text()();
  TextColumn get payload => text()();
  DateTimeColumn get firstSentAt => dateTime().nullable()();
  DateTimeColumn get retryAt => dateTime().nullable()();
  TextColumn get state => text()();
  TextColumn get errorCode => text().nullable()();
  @override
  Set<Column> get primaryKey => {scopeId, commandId};
  @override
  List<Set<Column>> get uniqueKeys => [
    {scopeId, characterId, ownershipRevision, role},
  ];
  @override
  List<String> get customConstraints => [
    "CHECK (state IN ('ready','retry','conflict','review','blocked'))",
    'FOREIGN KEY (scope_id, character_id, ownership_revision, role) REFERENCES scoped_role_records(scope_id, character_id, ownership_revision, role) ON DELETE RESTRICT',
  ];
}

class ScopedSettingRecords extends Table {
  IntColumn get scopeId => integer()();
  TextColumn get kind => text()();
  TextColumn get targetId => text()();
  TextColumn get accountId => text()();
  TextColumn get characterId => text().nullable()();
  IntColumn get ownershipRevision => integer()();
  IntColumn get rowVersion => integer()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {scopeId, kind, targetId, ownershipRevision};
  @override
  List<String> get customConstraints => [
    'CHECK (ownership_revision > 0 AND row_version > 0)',
    "CHECK ((kind = 'preferences' AND character_id IS NOT NULL AND target_id = character_id) OR (kind = 'presentation' AND character_id IS NULL AND target_id = account_id))",
    'FOREIGN KEY (scope_id, account_id) REFERENCES cached_account_heads(scope_id, account_id) ON DELETE RESTRICT',
    'FOREIGN KEY (scope_id, account_id, character_id) REFERENCES cached_characters(scope_id, account_id, character_id) ON DELETE RESTRICT',
  ];
}

@DataClassName('SettingOutboxRow')
class ScopedSettingCommands extends Table {
  IntColumn get scopeId => integer()();
  TextColumn get commandId => text()();
  TextColumn get kind => text()();
  TextColumn get targetId => text()();
  IntColumn get ownershipRevision => integer()();
  TextColumn get registrationId => text()();
  TextColumn get payload => text()();
  DateTimeColumn get firstSentAt => dateTime().nullable()();
  DateTimeColumn get retryAt => dateTime().nullable()();
  TextColumn get state => text()();
  TextColumn get errorCode => text().nullable()();
  @override
  Set<Column> get primaryKey => {scopeId, commandId};
  @override
  List<Set<Column>> get uniqueKeys => [
    {scopeId, kind, targetId, ownershipRevision},
  ];
  @override
  List<String> get customConstraints => [
    "CHECK (state IN ('ready','retry','conflict','review','blocked'))",
    'FOREIGN KEY (scope_id, kind, target_id, ownership_revision) REFERENCES scoped_setting_records(scope_id, kind, target_id, ownership_revision) ON DELETE RESTRICT',
    'FOREIGN KEY (scope_id, registration_id) REFERENCES cached_registrations(scope_id, registration_id) ON DELETE RESTRICT',
  ];
}

/// Separate scoped DB. Never migrates or opens the legacy AccountDatabase.
@DriftDatabase(
  tables: [
    CacheScopes,
    CachedAccountHeads,
    CachedRegistrations,
    CachedCharacters,
    ScopedRoleRecords,
    ScopedRoleCommands,
    ScopedSettingRecords,
    ScopedSettingCommands,
  ],
)
class ScopedAccountCacheDatabase extends _$ScopedAccountCacheDatabase {
  ScopedAccountCacheDatabase(super.executor);
  @override
  int get schemaVersion => 3;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _roleIdentityIndex();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _roleIdentityIndex();
        await m.createTable(scopedRoleRecords);
        await m.createTable(scopedRoleCommands);
      }
      if (from < 3) {
        await m.createTable(scopedSettingRecords);
        await m.createTable(scopedSettingCommands);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _roleIdentityIndex() => customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS cached_characters_role_identity ON cached_characters(scope_id, account_id, character_id)',
  );
}
