// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scoped_account_cache_database.dart';

// ignore_for_file: type=lint
class $CacheScopesTable extends CacheScopes
    with TableInfo<$CacheScopesTable, CacheScope> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheScopesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _environmentMeta = const VerificationMeta(
    'environment',
  );
  @override
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
    'environment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localVersionMeta = const VerificationMeta(
    'localVersion',
  );
  @override
  late final GeneratedColumn<int> localVersion = GeneratedColumn<int>(
    'local_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _snapshotSequenceMeta = const VerificationMeta(
    'snapshotSequence',
  );
  @override
  late final GeneratedColumn<int> snapshotSequence = GeneratedColumn<int>(
    'snapshot_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    environment,
    userId,
    localVersion,
    snapshotSequence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_scopes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheScope> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('environment')) {
      context.handle(
        _environmentMeta,
        environment.isAcceptableOrUnknown(
          data['environment']!,
          _environmentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_environmentMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('local_version')) {
      context.handle(
        _localVersionMeta,
        localVersion.isAcceptableOrUnknown(
          data['local_version']!,
          _localVersionMeta,
        ),
      );
    }
    if (data.containsKey('snapshot_sequence')) {
      context.handle(
        _snapshotSequenceMeta,
        snapshotSequence.isAcceptableOrUnknown(
          data['snapshot_sequence']!,
          _snapshotSequenceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {environment, userId},
  ];
  @override
  CacheScope map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheScope(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      environment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}environment'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      localVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_version'],
      )!,
      snapshotSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snapshot_sequence'],
      )!,
    );
  }

  @override
  $CacheScopesTable createAlias(String alias) {
    return $CacheScopesTable(attachedDatabase, alias);
  }
}

class CacheScope extends DataClass implements Insertable<CacheScope> {
  final int id;
  final String environment;
  final String userId;
  final int localVersion;
  final int snapshotSequence;
  const CacheScope({
    required this.id,
    required this.environment,
    required this.userId,
    required this.localVersion,
    required this.snapshotSequence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['environment'] = Variable<String>(environment);
    map['user_id'] = Variable<String>(userId);
    map['local_version'] = Variable<int>(localVersion);
    map['snapshot_sequence'] = Variable<int>(snapshotSequence);
    return map;
  }

  CacheScopesCompanion toCompanion(bool nullToAbsent) {
    return CacheScopesCompanion(
      id: Value(id),
      environment: Value(environment),
      userId: Value(userId),
      localVersion: Value(localVersion),
      snapshotSequence: Value(snapshotSequence),
    );
  }

  factory CacheScope.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheScope(
      id: serializer.fromJson<int>(json['id']),
      environment: serializer.fromJson<String>(json['environment']),
      userId: serializer.fromJson<String>(json['userId']),
      localVersion: serializer.fromJson<int>(json['localVersion']),
      snapshotSequence: serializer.fromJson<int>(json['snapshotSequence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'environment': serializer.toJson<String>(environment),
      'userId': serializer.toJson<String>(userId),
      'localVersion': serializer.toJson<int>(localVersion),
      'snapshotSequence': serializer.toJson<int>(snapshotSequence),
    };
  }

  CacheScope copyWith({
    int? id,
    String? environment,
    String? userId,
    int? localVersion,
    int? snapshotSequence,
  }) => CacheScope(
    id: id ?? this.id,
    environment: environment ?? this.environment,
    userId: userId ?? this.userId,
    localVersion: localVersion ?? this.localVersion,
    snapshotSequence: snapshotSequence ?? this.snapshotSequence,
  );
  CacheScope copyWithCompanion(CacheScopesCompanion data) {
    return CacheScope(
      id: data.id.present ? data.id.value : this.id,
      environment: data.environment.present
          ? data.environment.value
          : this.environment,
      userId: data.userId.present ? data.userId.value : this.userId,
      localVersion: data.localVersion.present
          ? data.localVersion.value
          : this.localVersion,
      snapshotSequence: data.snapshotSequence.present
          ? data.snapshotSequence.value
          : this.snapshotSequence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheScope(')
          ..write('id: $id, ')
          ..write('environment: $environment, ')
          ..write('userId: $userId, ')
          ..write('localVersion: $localVersion, ')
          ..write('snapshotSequence: $snapshotSequence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, environment, userId, localVersion, snapshotSequence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheScope &&
          other.id == this.id &&
          other.environment == this.environment &&
          other.userId == this.userId &&
          other.localVersion == this.localVersion &&
          other.snapshotSequence == this.snapshotSequence);
}

class CacheScopesCompanion extends UpdateCompanion<CacheScope> {
  final Value<int> id;
  final Value<String> environment;
  final Value<String> userId;
  final Value<int> localVersion;
  final Value<int> snapshotSequence;
  const CacheScopesCompanion({
    this.id = const Value.absent(),
    this.environment = const Value.absent(),
    this.userId = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.snapshotSequence = const Value.absent(),
  });
  CacheScopesCompanion.insert({
    this.id = const Value.absent(),
    required String environment,
    required String userId,
    this.localVersion = const Value.absent(),
    this.snapshotSequence = const Value.absent(),
  }) : environment = Value(environment),
       userId = Value(userId);
  static Insertable<CacheScope> custom({
    Expression<int>? id,
    Expression<String>? environment,
    Expression<String>? userId,
    Expression<int>? localVersion,
    Expression<int>? snapshotSequence,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (environment != null) 'environment': environment,
      if (userId != null) 'user_id': userId,
      if (localVersion != null) 'local_version': localVersion,
      if (snapshotSequence != null) 'snapshot_sequence': snapshotSequence,
    });
  }

  CacheScopesCompanion copyWith({
    Value<int>? id,
    Value<String>? environment,
    Value<String>? userId,
    Value<int>? localVersion,
    Value<int>? snapshotSequence,
  }) {
    return CacheScopesCompanion(
      id: id ?? this.id,
      environment: environment ?? this.environment,
      userId: userId ?? this.userId,
      localVersion: localVersion ?? this.localVersion,
      snapshotSequence: snapshotSequence ?? this.snapshotSequence,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (localVersion.present) {
      map['local_version'] = Variable<int>(localVersion.value);
    }
    if (snapshotSequence.present) {
      map['snapshot_sequence'] = Variable<int>(snapshotSequence.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheScopesCompanion(')
          ..write('id: $id, ')
          ..write('environment: $environment, ')
          ..write('userId: $userId, ')
          ..write('localVersion: $localVersion, ')
          ..write('snapshotSequence: $snapshotSequence')
          ..write(')'))
        .toString();
  }
}

class $CachedAccountHeadsTable extends CachedAccountHeads
    with TableInfo<$CachedAccountHeadsTable, CachedAccountHead> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedAccountHeadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localVersionMeta = const VerificationMeta(
    'localVersion',
  );
  @override
  late final GeneratedColumn<int> localVersion = GeneratedColumn<int>(
    'local_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _snapshotSequenceMeta = const VerificationMeta(
    'snapshotSequence',
  );
  @override
  late final GeneratedColumn<int> snapshotSequence = GeneratedColumn<int>(
    'snapshot_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completeMeta = const VerificationMeta(
    'complete',
  );
  @override
  late final GeneratedColumn<bool> complete = GeneratedColumn<bool>(
    'complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("complete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ownershipRevisionFloorMeta =
      const VerificationMeta('ownershipRevisionFloor');
  @override
  late final GeneratedColumn<int> ownershipRevisionFloor = GeneratedColumn<int>(
    'ownership_revision_floor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rosterRevisionFloorMeta =
      const VerificationMeta('rosterRevisionFloor');
  @override
  late final GeneratedColumn<int> rosterRevisionFloor = GeneratedColumn<int>(
    'roster_revision_floor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _settingsOwnershipRevisionMeta =
      const VerificationMeta('settingsOwnershipRevision');
  @override
  late final GeneratedColumn<int> settingsOwnershipRevision =
      GeneratedColumn<int>(
        'settings_ownership_revision',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _settingsVersionFloorMeta =
      const VerificationMeta('settingsVersionFloor');
  @override
  late final GeneratedColumn<int> settingsVersionFloor = GeneratedColumn<int>(
    'settings_version_floor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    accountId,
    localVersion,
    snapshotSequence,
    complete,
    ownershipRevisionFloor,
    rosterRevisionFloor,
    settingsOwnershipRevision,
    settingsVersionFloor,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_account_heads';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedAccountHead> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('local_version')) {
      context.handle(
        _localVersionMeta,
        localVersion.isAcceptableOrUnknown(
          data['local_version']!,
          _localVersionMeta,
        ),
      );
    }
    if (data.containsKey('snapshot_sequence')) {
      context.handle(
        _snapshotSequenceMeta,
        snapshotSequence.isAcceptableOrUnknown(
          data['snapshot_sequence']!,
          _snapshotSequenceMeta,
        ),
      );
    }
    if (data.containsKey('complete')) {
      context.handle(
        _completeMeta,
        complete.isAcceptableOrUnknown(data['complete']!, _completeMeta),
      );
    }
    if (data.containsKey('ownership_revision_floor')) {
      context.handle(
        _ownershipRevisionFloorMeta,
        ownershipRevisionFloor.isAcceptableOrUnknown(
          data['ownership_revision_floor']!,
          _ownershipRevisionFloorMeta,
        ),
      );
    }
    if (data.containsKey('roster_revision_floor')) {
      context.handle(
        _rosterRevisionFloorMeta,
        rosterRevisionFloor.isAcceptableOrUnknown(
          data['roster_revision_floor']!,
          _rosterRevisionFloorMeta,
        ),
      );
    }
    if (data.containsKey('settings_ownership_revision')) {
      context.handle(
        _settingsOwnershipRevisionMeta,
        settingsOwnershipRevision.isAcceptableOrUnknown(
          data['settings_ownership_revision']!,
          _settingsOwnershipRevisionMeta,
        ),
      );
    }
    if (data.containsKey('settings_version_floor')) {
      context.handle(
        _settingsVersionFloorMeta,
        settingsVersionFloor.isAcceptableOrUnknown(
          data['settings_version_floor']!,
          _settingsVersionFloorMeta,
        ),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scopeId, accountId};
  @override
  CachedAccountHead map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedAccountHead(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      localVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_version'],
      )!,
      snapshotSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snapshot_sequence'],
      )!,
      complete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}complete'],
      )!,
      ownershipRevisionFloor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ownership_revision_floor'],
      ),
      rosterRevisionFloor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}roster_revision_floor'],
      )!,
      settingsOwnershipRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}settings_ownership_revision'],
      ),
      settingsVersionFloor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}settings_version_floor'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $CachedAccountHeadsTable createAlias(String alias) {
    return $CachedAccountHeadsTable(attachedDatabase, alias);
  }
}

class CachedAccountHead extends DataClass
    implements Insertable<CachedAccountHead> {
  final int scopeId;
  final String accountId;
  final int localVersion;
  final int snapshotSequence;
  final bool complete;
  final int? ownershipRevisionFloor;
  final int rosterRevisionFloor;
  final int? settingsOwnershipRevision;
  final int settingsVersionFloor;
  final String payload;
  const CachedAccountHead({
    required this.scopeId,
    required this.accountId,
    required this.localVersion,
    required this.snapshotSequence,
    required this.complete,
    this.ownershipRevisionFloor,
    required this.rosterRevisionFloor,
    this.settingsOwnershipRevision,
    required this.settingsVersionFloor,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['account_id'] = Variable<String>(accountId);
    map['local_version'] = Variable<int>(localVersion);
    map['snapshot_sequence'] = Variable<int>(snapshotSequence);
    map['complete'] = Variable<bool>(complete);
    if (!nullToAbsent || ownershipRevisionFloor != null) {
      map['ownership_revision_floor'] = Variable<int>(ownershipRevisionFloor);
    }
    map['roster_revision_floor'] = Variable<int>(rosterRevisionFloor);
    if (!nullToAbsent || settingsOwnershipRevision != null) {
      map['settings_ownership_revision'] = Variable<int>(
        settingsOwnershipRevision,
      );
    }
    map['settings_version_floor'] = Variable<int>(settingsVersionFloor);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  CachedAccountHeadsCompanion toCompanion(bool nullToAbsent) {
    return CachedAccountHeadsCompanion(
      scopeId: Value(scopeId),
      accountId: Value(accountId),
      localVersion: Value(localVersion),
      snapshotSequence: Value(snapshotSequence),
      complete: Value(complete),
      ownershipRevisionFloor: ownershipRevisionFloor == null && nullToAbsent
          ? const Value.absent()
          : Value(ownershipRevisionFloor),
      rosterRevisionFloor: Value(rosterRevisionFloor),
      settingsOwnershipRevision:
          settingsOwnershipRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(settingsOwnershipRevision),
      settingsVersionFloor: Value(settingsVersionFloor),
      payload: Value(payload),
    );
  }

  factory CachedAccountHead.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedAccountHead(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      localVersion: serializer.fromJson<int>(json['localVersion']),
      snapshotSequence: serializer.fromJson<int>(json['snapshotSequence']),
      complete: serializer.fromJson<bool>(json['complete']),
      ownershipRevisionFloor: serializer.fromJson<int?>(
        json['ownershipRevisionFloor'],
      ),
      rosterRevisionFloor: serializer.fromJson<int>(
        json['rosterRevisionFloor'],
      ),
      settingsOwnershipRevision: serializer.fromJson<int?>(
        json['settingsOwnershipRevision'],
      ),
      settingsVersionFloor: serializer.fromJson<int>(
        json['settingsVersionFloor'],
      ),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'accountId': serializer.toJson<String>(accountId),
      'localVersion': serializer.toJson<int>(localVersion),
      'snapshotSequence': serializer.toJson<int>(snapshotSequence),
      'complete': serializer.toJson<bool>(complete),
      'ownershipRevisionFloor': serializer.toJson<int?>(ownershipRevisionFloor),
      'rosterRevisionFloor': serializer.toJson<int>(rosterRevisionFloor),
      'settingsOwnershipRevision': serializer.toJson<int?>(
        settingsOwnershipRevision,
      ),
      'settingsVersionFloor': serializer.toJson<int>(settingsVersionFloor),
      'payload': serializer.toJson<String>(payload),
    };
  }

  CachedAccountHead copyWith({
    int? scopeId,
    String? accountId,
    int? localVersion,
    int? snapshotSequence,
    bool? complete,
    Value<int?> ownershipRevisionFloor = const Value.absent(),
    int? rosterRevisionFloor,
    Value<int?> settingsOwnershipRevision = const Value.absent(),
    int? settingsVersionFloor,
    String? payload,
  }) => CachedAccountHead(
    scopeId: scopeId ?? this.scopeId,
    accountId: accountId ?? this.accountId,
    localVersion: localVersion ?? this.localVersion,
    snapshotSequence: snapshotSequence ?? this.snapshotSequence,
    complete: complete ?? this.complete,
    ownershipRevisionFloor: ownershipRevisionFloor.present
        ? ownershipRevisionFloor.value
        : this.ownershipRevisionFloor,
    rosterRevisionFloor: rosterRevisionFloor ?? this.rosterRevisionFloor,
    settingsOwnershipRevision: settingsOwnershipRevision.present
        ? settingsOwnershipRevision.value
        : this.settingsOwnershipRevision,
    settingsVersionFloor: settingsVersionFloor ?? this.settingsVersionFloor,
    payload: payload ?? this.payload,
  );
  CachedAccountHead copyWithCompanion(CachedAccountHeadsCompanion data) {
    return CachedAccountHead(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      localVersion: data.localVersion.present
          ? data.localVersion.value
          : this.localVersion,
      snapshotSequence: data.snapshotSequence.present
          ? data.snapshotSequence.value
          : this.snapshotSequence,
      complete: data.complete.present ? data.complete.value : this.complete,
      ownershipRevisionFloor: data.ownershipRevisionFloor.present
          ? data.ownershipRevisionFloor.value
          : this.ownershipRevisionFloor,
      rosterRevisionFloor: data.rosterRevisionFloor.present
          ? data.rosterRevisionFloor.value
          : this.rosterRevisionFloor,
      settingsOwnershipRevision: data.settingsOwnershipRevision.present
          ? data.settingsOwnershipRevision.value
          : this.settingsOwnershipRevision,
      settingsVersionFloor: data.settingsVersionFloor.present
          ? data.settingsVersionFloor.value
          : this.settingsVersionFloor,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedAccountHead(')
          ..write('scopeId: $scopeId, ')
          ..write('accountId: $accountId, ')
          ..write('localVersion: $localVersion, ')
          ..write('snapshotSequence: $snapshotSequence, ')
          ..write('complete: $complete, ')
          ..write('ownershipRevisionFloor: $ownershipRevisionFloor, ')
          ..write('rosterRevisionFloor: $rosterRevisionFloor, ')
          ..write('settingsOwnershipRevision: $settingsOwnershipRevision, ')
          ..write('settingsVersionFloor: $settingsVersionFloor, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    accountId,
    localVersion,
    snapshotSequence,
    complete,
    ownershipRevisionFloor,
    rosterRevisionFloor,
    settingsOwnershipRevision,
    settingsVersionFloor,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedAccountHead &&
          other.scopeId == this.scopeId &&
          other.accountId == this.accountId &&
          other.localVersion == this.localVersion &&
          other.snapshotSequence == this.snapshotSequence &&
          other.complete == this.complete &&
          other.ownershipRevisionFloor == this.ownershipRevisionFloor &&
          other.rosterRevisionFloor == this.rosterRevisionFloor &&
          other.settingsOwnershipRevision == this.settingsOwnershipRevision &&
          other.settingsVersionFloor == this.settingsVersionFloor &&
          other.payload == this.payload);
}

class CachedAccountHeadsCompanion extends UpdateCompanion<CachedAccountHead> {
  final Value<int> scopeId;
  final Value<String> accountId;
  final Value<int> localVersion;
  final Value<int> snapshotSequence;
  final Value<bool> complete;
  final Value<int?> ownershipRevisionFloor;
  final Value<int> rosterRevisionFloor;
  final Value<int?> settingsOwnershipRevision;
  final Value<int> settingsVersionFloor;
  final Value<String> payload;
  final Value<int> rowid;
  const CachedAccountHeadsCompanion({
    this.scopeId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.snapshotSequence = const Value.absent(),
    this.complete = const Value.absent(),
    this.ownershipRevisionFloor = const Value.absent(),
    this.rosterRevisionFloor = const Value.absent(),
    this.settingsOwnershipRevision = const Value.absent(),
    this.settingsVersionFloor = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedAccountHeadsCompanion.insert({
    required int scopeId,
    required String accountId,
    this.localVersion = const Value.absent(),
    this.snapshotSequence = const Value.absent(),
    this.complete = const Value.absent(),
    this.ownershipRevisionFloor = const Value.absent(),
    this.rosterRevisionFloor = const Value.absent(),
    this.settingsOwnershipRevision = const Value.absent(),
    this.settingsVersionFloor = const Value.absent(),
    required String payload,
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       accountId = Value(accountId),
       payload = Value(payload);
  static Insertable<CachedAccountHead> custom({
    Expression<int>? scopeId,
    Expression<String>? accountId,
    Expression<int>? localVersion,
    Expression<int>? snapshotSequence,
    Expression<bool>? complete,
    Expression<int>? ownershipRevisionFloor,
    Expression<int>? rosterRevisionFloor,
    Expression<int>? settingsOwnershipRevision,
    Expression<int>? settingsVersionFloor,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (accountId != null) 'account_id': accountId,
      if (localVersion != null) 'local_version': localVersion,
      if (snapshotSequence != null) 'snapshot_sequence': snapshotSequence,
      if (complete != null) 'complete': complete,
      if (ownershipRevisionFloor != null)
        'ownership_revision_floor': ownershipRevisionFloor,
      if (rosterRevisionFloor != null)
        'roster_revision_floor': rosterRevisionFloor,
      if (settingsOwnershipRevision != null)
        'settings_ownership_revision': settingsOwnershipRevision,
      if (settingsVersionFloor != null)
        'settings_version_floor': settingsVersionFloor,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedAccountHeadsCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? accountId,
    Value<int>? localVersion,
    Value<int>? snapshotSequence,
    Value<bool>? complete,
    Value<int?>? ownershipRevisionFloor,
    Value<int>? rosterRevisionFloor,
    Value<int?>? settingsOwnershipRevision,
    Value<int>? settingsVersionFloor,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return CachedAccountHeadsCompanion(
      scopeId: scopeId ?? this.scopeId,
      accountId: accountId ?? this.accountId,
      localVersion: localVersion ?? this.localVersion,
      snapshotSequence: snapshotSequence ?? this.snapshotSequence,
      complete: complete ?? this.complete,
      ownershipRevisionFloor:
          ownershipRevisionFloor ?? this.ownershipRevisionFloor,
      rosterRevisionFloor: rosterRevisionFloor ?? this.rosterRevisionFloor,
      settingsOwnershipRevision:
          settingsOwnershipRevision ?? this.settingsOwnershipRevision,
      settingsVersionFloor: settingsVersionFloor ?? this.settingsVersionFloor,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (localVersion.present) {
      map['local_version'] = Variable<int>(localVersion.value);
    }
    if (snapshotSequence.present) {
      map['snapshot_sequence'] = Variable<int>(snapshotSequence.value);
    }
    if (complete.present) {
      map['complete'] = Variable<bool>(complete.value);
    }
    if (ownershipRevisionFloor.present) {
      map['ownership_revision_floor'] = Variable<int>(
        ownershipRevisionFloor.value,
      );
    }
    if (rosterRevisionFloor.present) {
      map['roster_revision_floor'] = Variable<int>(rosterRevisionFloor.value);
    }
    if (settingsOwnershipRevision.present) {
      map['settings_ownership_revision'] = Variable<int>(
        settingsOwnershipRevision.value,
      );
    }
    if (settingsVersionFloor.present) {
      map['settings_version_floor'] = Variable<int>(settingsVersionFloor.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedAccountHeadsCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('accountId: $accountId, ')
          ..write('localVersion: $localVersion, ')
          ..write('snapshotSequence: $snapshotSequence, ')
          ..write('complete: $complete, ')
          ..write('ownershipRevisionFloor: $ownershipRevisionFloor, ')
          ..write('rosterRevisionFloor: $rosterRevisionFloor, ')
          ..write('settingsOwnershipRevision: $settingsOwnershipRevision, ')
          ..write('settingsVersionFloor: $settingsVersionFloor, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedRegistrationsTable extends CachedRegistrations
    with TableInfo<$CachedRegistrationsTable, CachedRegistration> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedRegistrationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _registrationIdMeta = const VerificationMeta(
    'registrationId',
  );
  @override
  late final GeneratedColumn<String> registrationId = GeneratedColumn<String>(
    'registration_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localVersionMeta = const VerificationMeta(
    'localVersion',
  );
  @override
  late final GeneratedColumn<int> localVersion = GeneratedColumn<int>(
    'local_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _seenSequenceMeta = const VerificationMeta(
    'seenSequence',
  );
  @override
  late final GeneratedColumn<int> seenSequence = GeneratedColumn<int>(
    'seen_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    registrationId,
    accountId,
    localVersion,
    seenSequence,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_registrations';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedRegistration> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('registration_id')) {
      context.handle(
        _registrationIdMeta,
        registrationId.isAcceptableOrUnknown(
          data['registration_id']!,
          _registrationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_registrationIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('local_version')) {
      context.handle(
        _localVersionMeta,
        localVersion.isAcceptableOrUnknown(
          data['local_version']!,
          _localVersionMeta,
        ),
      );
    }
    if (data.containsKey('seen_sequence')) {
      context.handle(
        _seenSequenceMeta,
        seenSequence.isAcceptableOrUnknown(
          data['seen_sequence']!,
          _seenSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seenSequenceMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scopeId, registrationId};
  @override
  CachedRegistration map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedRegistration(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      registrationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registration_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      localVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_version'],
      )!,
      seenSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_sequence'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $CachedRegistrationsTable createAlias(String alias) {
    return $CachedRegistrationsTable(attachedDatabase, alias);
  }
}

class CachedRegistration extends DataClass
    implements Insertable<CachedRegistration> {
  final int scopeId;
  final String registrationId;
  final String? accountId;
  final int localVersion;
  final int seenSequence;
  final String payload;
  const CachedRegistration({
    required this.scopeId,
    required this.registrationId,
    this.accountId,
    required this.localVersion,
    required this.seenSequence,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['registration_id'] = Variable<String>(registrationId);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    map['local_version'] = Variable<int>(localVersion);
    map['seen_sequence'] = Variable<int>(seenSequence);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  CachedRegistrationsCompanion toCompanion(bool nullToAbsent) {
    return CachedRegistrationsCompanion(
      scopeId: Value(scopeId),
      registrationId: Value(registrationId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      localVersion: Value(localVersion),
      seenSequence: Value(seenSequence),
      payload: Value(payload),
    );
  }

  factory CachedRegistration.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedRegistration(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      registrationId: serializer.fromJson<String>(json['registrationId']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      localVersion: serializer.fromJson<int>(json['localVersion']),
      seenSequence: serializer.fromJson<int>(json['seenSequence']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'registrationId': serializer.toJson<String>(registrationId),
      'accountId': serializer.toJson<String?>(accountId),
      'localVersion': serializer.toJson<int>(localVersion),
      'seenSequence': serializer.toJson<int>(seenSequence),
      'payload': serializer.toJson<String>(payload),
    };
  }

  CachedRegistration copyWith({
    int? scopeId,
    String? registrationId,
    Value<String?> accountId = const Value.absent(),
    int? localVersion,
    int? seenSequence,
    String? payload,
  }) => CachedRegistration(
    scopeId: scopeId ?? this.scopeId,
    registrationId: registrationId ?? this.registrationId,
    accountId: accountId.present ? accountId.value : this.accountId,
    localVersion: localVersion ?? this.localVersion,
    seenSequence: seenSequence ?? this.seenSequence,
    payload: payload ?? this.payload,
  );
  CachedRegistration copyWithCompanion(CachedRegistrationsCompanion data) {
    return CachedRegistration(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      registrationId: data.registrationId.present
          ? data.registrationId.value
          : this.registrationId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      localVersion: data.localVersion.present
          ? data.localVersion.value
          : this.localVersion,
      seenSequence: data.seenSequence.present
          ? data.seenSequence.value
          : this.seenSequence,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedRegistration(')
          ..write('scopeId: $scopeId, ')
          ..write('registrationId: $registrationId, ')
          ..write('accountId: $accountId, ')
          ..write('localVersion: $localVersion, ')
          ..write('seenSequence: $seenSequence, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    registrationId,
    accountId,
    localVersion,
    seenSequence,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedRegistration &&
          other.scopeId == this.scopeId &&
          other.registrationId == this.registrationId &&
          other.accountId == this.accountId &&
          other.localVersion == this.localVersion &&
          other.seenSequence == this.seenSequence &&
          other.payload == this.payload);
}

class CachedRegistrationsCompanion extends UpdateCompanion<CachedRegistration> {
  final Value<int> scopeId;
  final Value<String> registrationId;
  final Value<String?> accountId;
  final Value<int> localVersion;
  final Value<int> seenSequence;
  final Value<String> payload;
  final Value<int> rowid;
  const CachedRegistrationsCompanion({
    this.scopeId = const Value.absent(),
    this.registrationId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.seenSequence = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedRegistrationsCompanion.insert({
    required int scopeId,
    required String registrationId,
    this.accountId = const Value.absent(),
    this.localVersion = const Value.absent(),
    required int seenSequence,
    required String payload,
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       registrationId = Value(registrationId),
       seenSequence = Value(seenSequence),
       payload = Value(payload);
  static Insertable<CachedRegistration> custom({
    Expression<int>? scopeId,
    Expression<String>? registrationId,
    Expression<String>? accountId,
    Expression<int>? localVersion,
    Expression<int>? seenSequence,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (registrationId != null) 'registration_id': registrationId,
      if (accountId != null) 'account_id': accountId,
      if (localVersion != null) 'local_version': localVersion,
      if (seenSequence != null) 'seen_sequence': seenSequence,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedRegistrationsCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? registrationId,
    Value<String?>? accountId,
    Value<int>? localVersion,
    Value<int>? seenSequence,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return CachedRegistrationsCompanion(
      scopeId: scopeId ?? this.scopeId,
      registrationId: registrationId ?? this.registrationId,
      accountId: accountId ?? this.accountId,
      localVersion: localVersion ?? this.localVersion,
      seenSequence: seenSequence ?? this.seenSequence,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (registrationId.present) {
      map['registration_id'] = Variable<String>(registrationId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (localVersion.present) {
      map['local_version'] = Variable<int>(localVersion.value);
    }
    if (seenSequence.present) {
      map['seen_sequence'] = Variable<int>(seenSequence.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedRegistrationsCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('registrationId: $registrationId, ')
          ..write('accountId: $accountId, ')
          ..write('localVersion: $localVersion, ')
          ..write('seenSequence: $seenSequence, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedCharactersTable extends CachedCharacters
    with TableInfo<$CachedCharactersTable, CachedCharacter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCharactersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localVersionMeta = const VerificationMeta(
    'localVersion',
  );
  @override
  late final GeneratedColumn<int> localVersion = GeneratedColumn<int>(
    'local_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _seenSequenceMeta = const VerificationMeta(
    'seenSequence',
  );
  @override
  late final GeneratedColumn<int> seenSequence = GeneratedColumn<int>(
    'seen_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    characterId,
    accountId,
    localVersion,
    seenSequence,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCharacter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('local_version')) {
      context.handle(
        _localVersionMeta,
        localVersion.isAcceptableOrUnknown(
          data['local_version']!,
          _localVersionMeta,
        ),
      );
    }
    if (data.containsKey('seen_sequence')) {
      context.handle(
        _seenSequenceMeta,
        seenSequence.isAcceptableOrUnknown(
          data['seen_sequence']!,
          _seenSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seenSequenceMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scopeId, characterId};
  @override
  CachedCharacter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCharacter(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      localVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_version'],
      )!,
      seenSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_sequence'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $CachedCharactersTable createAlias(String alias) {
    return $CachedCharactersTable(attachedDatabase, alias);
  }
}

class CachedCharacter extends DataClass implements Insertable<CachedCharacter> {
  final int scopeId;
  final String characterId;
  final String accountId;
  final int localVersion;
  final int seenSequence;
  final String payload;
  const CachedCharacter({
    required this.scopeId,
    required this.characterId,
    required this.accountId,
    required this.localVersion,
    required this.seenSequence,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['character_id'] = Variable<String>(characterId);
    map['account_id'] = Variable<String>(accountId);
    map['local_version'] = Variable<int>(localVersion);
    map['seen_sequence'] = Variable<int>(seenSequence);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  CachedCharactersCompanion toCompanion(bool nullToAbsent) {
    return CachedCharactersCompanion(
      scopeId: Value(scopeId),
      characterId: Value(characterId),
      accountId: Value(accountId),
      localVersion: Value(localVersion),
      seenSequence: Value(seenSequence),
      payload: Value(payload),
    );
  }

  factory CachedCharacter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCharacter(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      characterId: serializer.fromJson<String>(json['characterId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      localVersion: serializer.fromJson<int>(json['localVersion']),
      seenSequence: serializer.fromJson<int>(json['seenSequence']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'characterId': serializer.toJson<String>(characterId),
      'accountId': serializer.toJson<String>(accountId),
      'localVersion': serializer.toJson<int>(localVersion),
      'seenSequence': serializer.toJson<int>(seenSequence),
      'payload': serializer.toJson<String>(payload),
    };
  }

  CachedCharacter copyWith({
    int? scopeId,
    String? characterId,
    String? accountId,
    int? localVersion,
    int? seenSequence,
    String? payload,
  }) => CachedCharacter(
    scopeId: scopeId ?? this.scopeId,
    characterId: characterId ?? this.characterId,
    accountId: accountId ?? this.accountId,
    localVersion: localVersion ?? this.localVersion,
    seenSequence: seenSequence ?? this.seenSequence,
    payload: payload ?? this.payload,
  );
  CachedCharacter copyWithCompanion(CachedCharactersCompanion data) {
    return CachedCharacter(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      localVersion: data.localVersion.present
          ? data.localVersion.value
          : this.localVersion,
      seenSequence: data.seenSequence.present
          ? data.seenSequence.value
          : this.seenSequence,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCharacter(')
          ..write('scopeId: $scopeId, ')
          ..write('characterId: $characterId, ')
          ..write('accountId: $accountId, ')
          ..write('localVersion: $localVersion, ')
          ..write('seenSequence: $seenSequence, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    characterId,
    accountId,
    localVersion,
    seenSequence,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCharacter &&
          other.scopeId == this.scopeId &&
          other.characterId == this.characterId &&
          other.accountId == this.accountId &&
          other.localVersion == this.localVersion &&
          other.seenSequence == this.seenSequence &&
          other.payload == this.payload);
}

class CachedCharactersCompanion extends UpdateCompanion<CachedCharacter> {
  final Value<int> scopeId;
  final Value<String> characterId;
  final Value<String> accountId;
  final Value<int> localVersion;
  final Value<int> seenSequence;
  final Value<String> payload;
  final Value<int> rowid;
  const CachedCharactersCompanion({
    this.scopeId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.seenSequence = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCharactersCompanion.insert({
    required int scopeId,
    required String characterId,
    required String accountId,
    this.localVersion = const Value.absent(),
    required int seenSequence,
    required String payload,
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       characterId = Value(characterId),
       accountId = Value(accountId),
       seenSequence = Value(seenSequence),
       payload = Value(payload);
  static Insertable<CachedCharacter> custom({
    Expression<int>? scopeId,
    Expression<String>? characterId,
    Expression<String>? accountId,
    Expression<int>? localVersion,
    Expression<int>? seenSequence,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (characterId != null) 'character_id': characterId,
      if (accountId != null) 'account_id': accountId,
      if (localVersion != null) 'local_version': localVersion,
      if (seenSequence != null) 'seen_sequence': seenSequence,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCharactersCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? characterId,
    Value<String>? accountId,
    Value<int>? localVersion,
    Value<int>? seenSequence,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return CachedCharactersCompanion(
      scopeId: scopeId ?? this.scopeId,
      characterId: characterId ?? this.characterId,
      accountId: accountId ?? this.accountId,
      localVersion: localVersion ?? this.localVersion,
      seenSequence: seenSequence ?? this.seenSequence,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (localVersion.present) {
      map['local_version'] = Variable<int>(localVersion.value);
    }
    if (seenSequence.present) {
      map['seen_sequence'] = Variable<int>(seenSequence.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCharactersCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('characterId: $characterId, ')
          ..write('accountId: $accountId, ')
          ..write('localVersion: $localVersion, ')
          ..write('seenSequence: $seenSequence, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScopedRoleRecordsTable extends ScopedRoleRecords
    with TableInfo<$ScopedRoleRecordsTable, ScopedRoleRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScopedRoleRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownershipRevisionMeta = const VerificationMeta(
    'ownershipRevision',
  );
  @override
  late final GeneratedColumn<int> ownershipRevision = GeneratedColumn<int>(
    'ownership_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    characterId,
    accountId,
    ownershipRevision,
    role,
    rowVersion,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scoped_role_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScopedRoleRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('ownership_revision')) {
      context.handle(
        _ownershipRevisionMeta,
        ownershipRevision.isAcceptableOrUnknown(
          data['ownership_revision']!,
          _ownershipRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownershipRevisionMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    } else if (isInserting) {
      context.missing(_rowVersionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    scopeId,
    characterId,
    ownershipRevision,
    role,
  };
  @override
  ScopedRoleRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScopedRoleRecord(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      ownershipRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ownership_revision'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $ScopedRoleRecordsTable createAlias(String alias) {
    return $ScopedRoleRecordsTable(attachedDatabase, alias);
  }
}

class ScopedRoleRecord extends DataClass
    implements Insertable<ScopedRoleRecord> {
  final int scopeId;
  final String characterId;
  final String accountId;
  final int ownershipRevision;
  final String role;
  final int rowVersion;
  final String payload;
  const ScopedRoleRecord({
    required this.scopeId,
    required this.characterId,
    required this.accountId,
    required this.ownershipRevision,
    required this.role,
    required this.rowVersion,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['character_id'] = Variable<String>(characterId);
    map['account_id'] = Variable<String>(accountId);
    map['ownership_revision'] = Variable<int>(ownershipRevision);
    map['role'] = Variable<String>(role);
    map['row_version'] = Variable<int>(rowVersion);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  ScopedRoleRecordsCompanion toCompanion(bool nullToAbsent) {
    return ScopedRoleRecordsCompanion(
      scopeId: Value(scopeId),
      characterId: Value(characterId),
      accountId: Value(accountId),
      ownershipRevision: Value(ownershipRevision),
      role: Value(role),
      rowVersion: Value(rowVersion),
      payload: Value(payload),
    );
  }

  factory ScopedRoleRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScopedRoleRecord(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      characterId: serializer.fromJson<String>(json['characterId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      ownershipRevision: serializer.fromJson<int>(json['ownershipRevision']),
      role: serializer.fromJson<String>(json['role']),
      rowVersion: serializer.fromJson<int>(json['rowVersion']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'characterId': serializer.toJson<String>(characterId),
      'accountId': serializer.toJson<String>(accountId),
      'ownershipRevision': serializer.toJson<int>(ownershipRevision),
      'role': serializer.toJson<String>(role),
      'rowVersion': serializer.toJson<int>(rowVersion),
      'payload': serializer.toJson<String>(payload),
    };
  }

  ScopedRoleRecord copyWith({
    int? scopeId,
    String? characterId,
    String? accountId,
    int? ownershipRevision,
    String? role,
    int? rowVersion,
    String? payload,
  }) => ScopedRoleRecord(
    scopeId: scopeId ?? this.scopeId,
    characterId: characterId ?? this.characterId,
    accountId: accountId ?? this.accountId,
    ownershipRevision: ownershipRevision ?? this.ownershipRevision,
    role: role ?? this.role,
    rowVersion: rowVersion ?? this.rowVersion,
    payload: payload ?? this.payload,
  );
  ScopedRoleRecord copyWithCompanion(ScopedRoleRecordsCompanion data) {
    return ScopedRoleRecord(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      ownershipRevision: data.ownershipRevision.present
          ? data.ownershipRevision.value
          : this.ownershipRevision,
      role: data.role.present ? data.role.value : this.role,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScopedRoleRecord(')
          ..write('scopeId: $scopeId, ')
          ..write('characterId: $characterId, ')
          ..write('accountId: $accountId, ')
          ..write('ownershipRevision: $ownershipRevision, ')
          ..write('role: $role, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    characterId,
    accountId,
    ownershipRevision,
    role,
    rowVersion,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScopedRoleRecord &&
          other.scopeId == this.scopeId &&
          other.characterId == this.characterId &&
          other.accountId == this.accountId &&
          other.ownershipRevision == this.ownershipRevision &&
          other.role == this.role &&
          other.rowVersion == this.rowVersion &&
          other.payload == this.payload);
}

class ScopedRoleRecordsCompanion extends UpdateCompanion<ScopedRoleRecord> {
  final Value<int> scopeId;
  final Value<String> characterId;
  final Value<String> accountId;
  final Value<int> ownershipRevision;
  final Value<String> role;
  final Value<int> rowVersion;
  final Value<String> payload;
  final Value<int> rowid;
  const ScopedRoleRecordsCompanion({
    this.scopeId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.ownershipRevision = const Value.absent(),
    this.role = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScopedRoleRecordsCompanion.insert({
    required int scopeId,
    required String characterId,
    required String accountId,
    required int ownershipRevision,
    required String role,
    required int rowVersion,
    required String payload,
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       characterId = Value(characterId),
       accountId = Value(accountId),
       ownershipRevision = Value(ownershipRevision),
       role = Value(role),
       rowVersion = Value(rowVersion),
       payload = Value(payload);
  static Insertable<ScopedRoleRecord> custom({
    Expression<int>? scopeId,
    Expression<String>? characterId,
    Expression<String>? accountId,
    Expression<int>? ownershipRevision,
    Expression<String>? role,
    Expression<int>? rowVersion,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (characterId != null) 'character_id': characterId,
      if (accountId != null) 'account_id': accountId,
      if (ownershipRevision != null) 'ownership_revision': ownershipRevision,
      if (role != null) 'role': role,
      if (rowVersion != null) 'row_version': rowVersion,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScopedRoleRecordsCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? characterId,
    Value<String>? accountId,
    Value<int>? ownershipRevision,
    Value<String>? role,
    Value<int>? rowVersion,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return ScopedRoleRecordsCompanion(
      scopeId: scopeId ?? this.scopeId,
      characterId: characterId ?? this.characterId,
      accountId: accountId ?? this.accountId,
      ownershipRevision: ownershipRevision ?? this.ownershipRevision,
      role: role ?? this.role,
      rowVersion: rowVersion ?? this.rowVersion,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (ownershipRevision.present) {
      map['ownership_revision'] = Variable<int>(ownershipRevision.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScopedRoleRecordsCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('characterId: $characterId, ')
          ..write('accountId: $accountId, ')
          ..write('ownershipRevision: $ownershipRevision, ')
          ..write('role: $role, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScopedRoleCommandsTable extends ScopedRoleCommands
    with TableInfo<$ScopedRoleCommandsTable, RoleOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScopedRoleCommandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownershipRevisionMeta = const VerificationMeta(
    'ownershipRevision',
  );
  @override
  late final GeneratedColumn<int> ownershipRevision = GeneratedColumn<int>(
    'ownership_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSentAtMeta = const VerificationMeta(
    'firstSentAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSentAt = GeneratedColumn<DateTime>(
    'first_sent_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryAtMeta = const VerificationMeta(
    'retryAt',
  );
  @override
  late final GeneratedColumn<DateTime> retryAt = GeneratedColumn<DateTime>(
    'retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    commandId,
    characterId,
    ownershipRevision,
    role,
    payload,
    firstSentAt,
    retryAt,
    state,
    errorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scoped_role_commands';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoleOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('ownership_revision')) {
      context.handle(
        _ownershipRevisionMeta,
        ownershipRevision.isAcceptableOrUnknown(
          data['ownership_revision']!,
          _ownershipRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownershipRevisionMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('first_sent_at')) {
      context.handle(
        _firstSentAtMeta,
        firstSentAt.isAcceptableOrUnknown(
          data['first_sent_at']!,
          _firstSentAtMeta,
        ),
      );
    }
    if (data.containsKey('retry_at')) {
      context.handle(
        _retryAtMeta,
        retryAt.isAcceptableOrUnknown(data['retry_at']!, _retryAtMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scopeId, commandId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {scopeId, characterId, ownershipRevision, role},
  ];
  @override
  RoleOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoleOutboxRow(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      ownershipRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ownership_revision'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      firstSentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_sent_at'],
      ),
      retryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}retry_at'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
    );
  }

  @override
  $ScopedRoleCommandsTable createAlias(String alias) {
    return $ScopedRoleCommandsTable(attachedDatabase, alias);
  }
}

class RoleOutboxRow extends DataClass implements Insertable<RoleOutboxRow> {
  final int scopeId;
  final String commandId;
  final String characterId;
  final int ownershipRevision;
  final String role;
  final String payload;
  final DateTime? firstSentAt;
  final DateTime? retryAt;
  final String state;
  final String? errorCode;
  const RoleOutboxRow({
    required this.scopeId,
    required this.commandId,
    required this.characterId,
    required this.ownershipRevision,
    required this.role,
    required this.payload,
    this.firstSentAt,
    this.retryAt,
    required this.state,
    this.errorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['command_id'] = Variable<String>(commandId);
    map['character_id'] = Variable<String>(characterId);
    map['ownership_revision'] = Variable<int>(ownershipRevision);
    map['role'] = Variable<String>(role);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || firstSentAt != null) {
      map['first_sent_at'] = Variable<DateTime>(firstSentAt);
    }
    if (!nullToAbsent || retryAt != null) {
      map['retry_at'] = Variable<DateTime>(retryAt);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    return map;
  }

  ScopedRoleCommandsCompanion toCompanion(bool nullToAbsent) {
    return ScopedRoleCommandsCompanion(
      scopeId: Value(scopeId),
      commandId: Value(commandId),
      characterId: Value(characterId),
      ownershipRevision: Value(ownershipRevision),
      role: Value(role),
      payload: Value(payload),
      firstSentAt: firstSentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(firstSentAt),
      retryAt: retryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(retryAt),
      state: Value(state),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
    );
  }

  factory RoleOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoleOutboxRow(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      commandId: serializer.fromJson<String>(json['commandId']),
      characterId: serializer.fromJson<String>(json['characterId']),
      ownershipRevision: serializer.fromJson<int>(json['ownershipRevision']),
      role: serializer.fromJson<String>(json['role']),
      payload: serializer.fromJson<String>(json['payload']),
      firstSentAt: serializer.fromJson<DateTime?>(json['firstSentAt']),
      retryAt: serializer.fromJson<DateTime?>(json['retryAt']),
      state: serializer.fromJson<String>(json['state']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'commandId': serializer.toJson<String>(commandId),
      'characterId': serializer.toJson<String>(characterId),
      'ownershipRevision': serializer.toJson<int>(ownershipRevision),
      'role': serializer.toJson<String>(role),
      'payload': serializer.toJson<String>(payload),
      'firstSentAt': serializer.toJson<DateTime?>(firstSentAt),
      'retryAt': serializer.toJson<DateTime?>(retryAt),
      'state': serializer.toJson<String>(state),
      'errorCode': serializer.toJson<String?>(errorCode),
    };
  }

  RoleOutboxRow copyWith({
    int? scopeId,
    String? commandId,
    String? characterId,
    int? ownershipRevision,
    String? role,
    String? payload,
    Value<DateTime?> firstSentAt = const Value.absent(),
    Value<DateTime?> retryAt = const Value.absent(),
    String? state,
    Value<String?> errorCode = const Value.absent(),
  }) => RoleOutboxRow(
    scopeId: scopeId ?? this.scopeId,
    commandId: commandId ?? this.commandId,
    characterId: characterId ?? this.characterId,
    ownershipRevision: ownershipRevision ?? this.ownershipRevision,
    role: role ?? this.role,
    payload: payload ?? this.payload,
    firstSentAt: firstSentAt.present ? firstSentAt.value : this.firstSentAt,
    retryAt: retryAt.present ? retryAt.value : this.retryAt,
    state: state ?? this.state,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
  );
  RoleOutboxRow copyWithCompanion(ScopedRoleCommandsCompanion data) {
    return RoleOutboxRow(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      ownershipRevision: data.ownershipRevision.present
          ? data.ownershipRevision.value
          : this.ownershipRevision,
      role: data.role.present ? data.role.value : this.role,
      payload: data.payload.present ? data.payload.value : this.payload,
      firstSentAt: data.firstSentAt.present
          ? data.firstSentAt.value
          : this.firstSentAt,
      retryAt: data.retryAt.present ? data.retryAt.value : this.retryAt,
      state: data.state.present ? data.state.value : this.state,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoleOutboxRow(')
          ..write('scopeId: $scopeId, ')
          ..write('commandId: $commandId, ')
          ..write('characterId: $characterId, ')
          ..write('ownershipRevision: $ownershipRevision, ')
          ..write('role: $role, ')
          ..write('payload: $payload, ')
          ..write('firstSentAt: $firstSentAt, ')
          ..write('retryAt: $retryAt, ')
          ..write('state: $state, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    commandId,
    characterId,
    ownershipRevision,
    role,
    payload,
    firstSentAt,
    retryAt,
    state,
    errorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoleOutboxRow &&
          other.scopeId == this.scopeId &&
          other.commandId == this.commandId &&
          other.characterId == this.characterId &&
          other.ownershipRevision == this.ownershipRevision &&
          other.role == this.role &&
          other.payload == this.payload &&
          other.firstSentAt == this.firstSentAt &&
          other.retryAt == this.retryAt &&
          other.state == this.state &&
          other.errorCode == this.errorCode);
}

class ScopedRoleCommandsCompanion extends UpdateCompanion<RoleOutboxRow> {
  final Value<int> scopeId;
  final Value<String> commandId;
  final Value<String> characterId;
  final Value<int> ownershipRevision;
  final Value<String> role;
  final Value<String> payload;
  final Value<DateTime?> firstSentAt;
  final Value<DateTime?> retryAt;
  final Value<String> state;
  final Value<String?> errorCode;
  final Value<int> rowid;
  const ScopedRoleCommandsCompanion({
    this.scopeId = const Value.absent(),
    this.commandId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.ownershipRevision = const Value.absent(),
    this.role = const Value.absent(),
    this.payload = const Value.absent(),
    this.firstSentAt = const Value.absent(),
    this.retryAt = const Value.absent(),
    this.state = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScopedRoleCommandsCompanion.insert({
    required int scopeId,
    required String commandId,
    required String characterId,
    required int ownershipRevision,
    required String role,
    required String payload,
    this.firstSentAt = const Value.absent(),
    this.retryAt = const Value.absent(),
    required String state,
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       commandId = Value(commandId),
       characterId = Value(characterId),
       ownershipRevision = Value(ownershipRevision),
       role = Value(role),
       payload = Value(payload),
       state = Value(state);
  static Insertable<RoleOutboxRow> custom({
    Expression<int>? scopeId,
    Expression<String>? commandId,
    Expression<String>? characterId,
    Expression<int>? ownershipRevision,
    Expression<String>? role,
    Expression<String>? payload,
    Expression<DateTime>? firstSentAt,
    Expression<DateTime>? retryAt,
    Expression<String>? state,
    Expression<String>? errorCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (commandId != null) 'command_id': commandId,
      if (characterId != null) 'character_id': characterId,
      if (ownershipRevision != null) 'ownership_revision': ownershipRevision,
      if (role != null) 'role': role,
      if (payload != null) 'payload': payload,
      if (firstSentAt != null) 'first_sent_at': firstSentAt,
      if (retryAt != null) 'retry_at': retryAt,
      if (state != null) 'state': state,
      if (errorCode != null) 'error_code': errorCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScopedRoleCommandsCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? commandId,
    Value<String>? characterId,
    Value<int>? ownershipRevision,
    Value<String>? role,
    Value<String>? payload,
    Value<DateTime?>? firstSentAt,
    Value<DateTime?>? retryAt,
    Value<String>? state,
    Value<String?>? errorCode,
    Value<int>? rowid,
  }) {
    return ScopedRoleCommandsCompanion(
      scopeId: scopeId ?? this.scopeId,
      commandId: commandId ?? this.commandId,
      characterId: characterId ?? this.characterId,
      ownershipRevision: ownershipRevision ?? this.ownershipRevision,
      role: role ?? this.role,
      payload: payload ?? this.payload,
      firstSentAt: firstSentAt ?? this.firstSentAt,
      retryAt: retryAt ?? this.retryAt,
      state: state ?? this.state,
      errorCode: errorCode ?? this.errorCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (ownershipRevision.present) {
      map['ownership_revision'] = Variable<int>(ownershipRevision.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (firstSentAt.present) {
      map['first_sent_at'] = Variable<DateTime>(firstSentAt.value);
    }
    if (retryAt.present) {
      map['retry_at'] = Variable<DateTime>(retryAt.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScopedRoleCommandsCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('commandId: $commandId, ')
          ..write('characterId: $characterId, ')
          ..write('ownershipRevision: $ownershipRevision, ')
          ..write('role: $role, ')
          ..write('payload: $payload, ')
          ..write('firstSentAt: $firstSentAt, ')
          ..write('retryAt: $retryAt, ')
          ..write('state: $state, ')
          ..write('errorCode: $errorCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScopedSettingRecordsTable extends ScopedSettingRecords
    with TableInfo<$ScopedSettingRecordsTable, ScopedSettingRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScopedSettingRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownershipRevisionMeta = const VerificationMeta(
    'ownershipRevision',
  );
  @override
  late final GeneratedColumn<int> ownershipRevision = GeneratedColumn<int>(
    'ownership_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    kind,
    targetId,
    accountId,
    characterId,
    ownershipRevision,
    rowVersion,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scoped_setting_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScopedSettingRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    }
    if (data.containsKey('ownership_revision')) {
      context.handle(
        _ownershipRevisionMeta,
        ownershipRevision.isAcceptableOrUnknown(
          data['ownership_revision']!,
          _ownershipRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownershipRevisionMeta);
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    } else if (isInserting) {
      context.missing(_rowVersionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    scopeId,
    kind,
    targetId,
    ownershipRevision,
  };
  @override
  ScopedSettingRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScopedSettingRecord(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      ),
      ownershipRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ownership_revision'],
      )!,
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $ScopedSettingRecordsTable createAlias(String alias) {
    return $ScopedSettingRecordsTable(attachedDatabase, alias);
  }
}

class ScopedSettingRecord extends DataClass
    implements Insertable<ScopedSettingRecord> {
  final int scopeId;
  final String kind;
  final String targetId;
  final String accountId;
  final String? characterId;
  final int ownershipRevision;
  final int rowVersion;
  final String payload;
  const ScopedSettingRecord({
    required this.scopeId,
    required this.kind,
    required this.targetId,
    required this.accountId,
    this.characterId,
    required this.ownershipRevision,
    required this.rowVersion,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['kind'] = Variable<String>(kind);
    map['target_id'] = Variable<String>(targetId);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || characterId != null) {
      map['character_id'] = Variable<String>(characterId);
    }
    map['ownership_revision'] = Variable<int>(ownershipRevision);
    map['row_version'] = Variable<int>(rowVersion);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  ScopedSettingRecordsCompanion toCompanion(bool nullToAbsent) {
    return ScopedSettingRecordsCompanion(
      scopeId: Value(scopeId),
      kind: Value(kind),
      targetId: Value(targetId),
      accountId: Value(accountId),
      characterId: characterId == null && nullToAbsent
          ? const Value.absent()
          : Value(characterId),
      ownershipRevision: Value(ownershipRevision),
      rowVersion: Value(rowVersion),
      payload: Value(payload),
    );
  }

  factory ScopedSettingRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScopedSettingRecord(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      kind: serializer.fromJson<String>(json['kind']),
      targetId: serializer.fromJson<String>(json['targetId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      characterId: serializer.fromJson<String?>(json['characterId']),
      ownershipRevision: serializer.fromJson<int>(json['ownershipRevision']),
      rowVersion: serializer.fromJson<int>(json['rowVersion']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'kind': serializer.toJson<String>(kind),
      'targetId': serializer.toJson<String>(targetId),
      'accountId': serializer.toJson<String>(accountId),
      'characterId': serializer.toJson<String?>(characterId),
      'ownershipRevision': serializer.toJson<int>(ownershipRevision),
      'rowVersion': serializer.toJson<int>(rowVersion),
      'payload': serializer.toJson<String>(payload),
    };
  }

  ScopedSettingRecord copyWith({
    int? scopeId,
    String? kind,
    String? targetId,
    String? accountId,
    Value<String?> characterId = const Value.absent(),
    int? ownershipRevision,
    int? rowVersion,
    String? payload,
  }) => ScopedSettingRecord(
    scopeId: scopeId ?? this.scopeId,
    kind: kind ?? this.kind,
    targetId: targetId ?? this.targetId,
    accountId: accountId ?? this.accountId,
    characterId: characterId.present ? characterId.value : this.characterId,
    ownershipRevision: ownershipRevision ?? this.ownershipRevision,
    rowVersion: rowVersion ?? this.rowVersion,
    payload: payload ?? this.payload,
  );
  ScopedSettingRecord copyWithCompanion(ScopedSettingRecordsCompanion data) {
    return ScopedSettingRecord(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      kind: data.kind.present ? data.kind.value : this.kind,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      ownershipRevision: data.ownershipRevision.present
          ? data.ownershipRevision.value
          : this.ownershipRevision,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScopedSettingRecord(')
          ..write('scopeId: $scopeId, ')
          ..write('kind: $kind, ')
          ..write('targetId: $targetId, ')
          ..write('accountId: $accountId, ')
          ..write('characterId: $characterId, ')
          ..write('ownershipRevision: $ownershipRevision, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    kind,
    targetId,
    accountId,
    characterId,
    ownershipRevision,
    rowVersion,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScopedSettingRecord &&
          other.scopeId == this.scopeId &&
          other.kind == this.kind &&
          other.targetId == this.targetId &&
          other.accountId == this.accountId &&
          other.characterId == this.characterId &&
          other.ownershipRevision == this.ownershipRevision &&
          other.rowVersion == this.rowVersion &&
          other.payload == this.payload);
}

class ScopedSettingRecordsCompanion
    extends UpdateCompanion<ScopedSettingRecord> {
  final Value<int> scopeId;
  final Value<String> kind;
  final Value<String> targetId;
  final Value<String> accountId;
  final Value<String?> characterId;
  final Value<int> ownershipRevision;
  final Value<int> rowVersion;
  final Value<String> payload;
  final Value<int> rowid;
  const ScopedSettingRecordsCompanion({
    this.scopeId = const Value.absent(),
    this.kind = const Value.absent(),
    this.targetId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.ownershipRevision = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScopedSettingRecordsCompanion.insert({
    required int scopeId,
    required String kind,
    required String targetId,
    required String accountId,
    this.characterId = const Value.absent(),
    required int ownershipRevision,
    required int rowVersion,
    required String payload,
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       kind = Value(kind),
       targetId = Value(targetId),
       accountId = Value(accountId),
       ownershipRevision = Value(ownershipRevision),
       rowVersion = Value(rowVersion),
       payload = Value(payload);
  static Insertable<ScopedSettingRecord> custom({
    Expression<int>? scopeId,
    Expression<String>? kind,
    Expression<String>? targetId,
    Expression<String>? accountId,
    Expression<String>? characterId,
    Expression<int>? ownershipRevision,
    Expression<int>? rowVersion,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (kind != null) 'kind': kind,
      if (targetId != null) 'target_id': targetId,
      if (accountId != null) 'account_id': accountId,
      if (characterId != null) 'character_id': characterId,
      if (ownershipRevision != null) 'ownership_revision': ownershipRevision,
      if (rowVersion != null) 'row_version': rowVersion,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScopedSettingRecordsCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? kind,
    Value<String>? targetId,
    Value<String>? accountId,
    Value<String?>? characterId,
    Value<int>? ownershipRevision,
    Value<int>? rowVersion,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return ScopedSettingRecordsCompanion(
      scopeId: scopeId ?? this.scopeId,
      kind: kind ?? this.kind,
      targetId: targetId ?? this.targetId,
      accountId: accountId ?? this.accountId,
      characterId: characterId ?? this.characterId,
      ownershipRevision: ownershipRevision ?? this.ownershipRevision,
      rowVersion: rowVersion ?? this.rowVersion,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (ownershipRevision.present) {
      map['ownership_revision'] = Variable<int>(ownershipRevision.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScopedSettingRecordsCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('kind: $kind, ')
          ..write('targetId: $targetId, ')
          ..write('accountId: $accountId, ')
          ..write('characterId: $characterId, ')
          ..write('ownershipRevision: $ownershipRevision, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScopedSettingCommandsTable extends ScopedSettingCommands
    with TableInfo<$ScopedSettingCommandsTable, SettingOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScopedSettingCommandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownershipRevisionMeta = const VerificationMeta(
    'ownershipRevision',
  );
  @override
  late final GeneratedColumn<int> ownershipRevision = GeneratedColumn<int>(
    'ownership_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _registrationIdMeta = const VerificationMeta(
    'registrationId',
  );
  @override
  late final GeneratedColumn<String> registrationId = GeneratedColumn<String>(
    'registration_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSentAtMeta = const VerificationMeta(
    'firstSentAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSentAt = GeneratedColumn<DateTime>(
    'first_sent_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryAtMeta = const VerificationMeta(
    'retryAt',
  );
  @override
  late final GeneratedColumn<DateTime> retryAt = GeneratedColumn<DateTime>(
    'retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    commandId,
    kind,
    targetId,
    ownershipRevision,
    registrationId,
    payload,
    firstSentAt,
    retryAt,
    state,
    errorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scoped_setting_commands';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('ownership_revision')) {
      context.handle(
        _ownershipRevisionMeta,
        ownershipRevision.isAcceptableOrUnknown(
          data['ownership_revision']!,
          _ownershipRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownershipRevisionMeta);
    }
    if (data.containsKey('registration_id')) {
      context.handle(
        _registrationIdMeta,
        registrationId.isAcceptableOrUnknown(
          data['registration_id']!,
          _registrationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_registrationIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('first_sent_at')) {
      context.handle(
        _firstSentAtMeta,
        firstSentAt.isAcceptableOrUnknown(
          data['first_sent_at']!,
          _firstSentAtMeta,
        ),
      );
    }
    if (data.containsKey('retry_at')) {
      context.handle(
        _retryAtMeta,
        retryAt.isAcceptableOrUnknown(data['retry_at']!, _retryAtMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scopeId, commandId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {scopeId, kind, targetId, ownershipRevision},
  ];
  @override
  SettingOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingOutboxRow(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      ownershipRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ownership_revision'],
      )!,
      registrationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registration_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      firstSentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_sent_at'],
      ),
      retryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}retry_at'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
    );
  }

  @override
  $ScopedSettingCommandsTable createAlias(String alias) {
    return $ScopedSettingCommandsTable(attachedDatabase, alias);
  }
}

class SettingOutboxRow extends DataClass
    implements Insertable<SettingOutboxRow> {
  final int scopeId;
  final String commandId;
  final String kind;
  final String targetId;
  final int ownershipRevision;
  final String registrationId;
  final String payload;
  final DateTime? firstSentAt;
  final DateTime? retryAt;
  final String state;
  final String? errorCode;
  const SettingOutboxRow({
    required this.scopeId,
    required this.commandId,
    required this.kind,
    required this.targetId,
    required this.ownershipRevision,
    required this.registrationId,
    required this.payload,
    this.firstSentAt,
    this.retryAt,
    required this.state,
    this.errorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['command_id'] = Variable<String>(commandId);
    map['kind'] = Variable<String>(kind);
    map['target_id'] = Variable<String>(targetId);
    map['ownership_revision'] = Variable<int>(ownershipRevision);
    map['registration_id'] = Variable<String>(registrationId);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || firstSentAt != null) {
      map['first_sent_at'] = Variable<DateTime>(firstSentAt);
    }
    if (!nullToAbsent || retryAt != null) {
      map['retry_at'] = Variable<DateTime>(retryAt);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    return map;
  }

  ScopedSettingCommandsCompanion toCompanion(bool nullToAbsent) {
    return ScopedSettingCommandsCompanion(
      scopeId: Value(scopeId),
      commandId: Value(commandId),
      kind: Value(kind),
      targetId: Value(targetId),
      ownershipRevision: Value(ownershipRevision),
      registrationId: Value(registrationId),
      payload: Value(payload),
      firstSentAt: firstSentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(firstSentAt),
      retryAt: retryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(retryAt),
      state: Value(state),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
    );
  }

  factory SettingOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingOutboxRow(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      commandId: serializer.fromJson<String>(json['commandId']),
      kind: serializer.fromJson<String>(json['kind']),
      targetId: serializer.fromJson<String>(json['targetId']),
      ownershipRevision: serializer.fromJson<int>(json['ownershipRevision']),
      registrationId: serializer.fromJson<String>(json['registrationId']),
      payload: serializer.fromJson<String>(json['payload']),
      firstSentAt: serializer.fromJson<DateTime?>(json['firstSentAt']),
      retryAt: serializer.fromJson<DateTime?>(json['retryAt']),
      state: serializer.fromJson<String>(json['state']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'commandId': serializer.toJson<String>(commandId),
      'kind': serializer.toJson<String>(kind),
      'targetId': serializer.toJson<String>(targetId),
      'ownershipRevision': serializer.toJson<int>(ownershipRevision),
      'registrationId': serializer.toJson<String>(registrationId),
      'payload': serializer.toJson<String>(payload),
      'firstSentAt': serializer.toJson<DateTime?>(firstSentAt),
      'retryAt': serializer.toJson<DateTime?>(retryAt),
      'state': serializer.toJson<String>(state),
      'errorCode': serializer.toJson<String?>(errorCode),
    };
  }

  SettingOutboxRow copyWith({
    int? scopeId,
    String? commandId,
    String? kind,
    String? targetId,
    int? ownershipRevision,
    String? registrationId,
    String? payload,
    Value<DateTime?> firstSentAt = const Value.absent(),
    Value<DateTime?> retryAt = const Value.absent(),
    String? state,
    Value<String?> errorCode = const Value.absent(),
  }) => SettingOutboxRow(
    scopeId: scopeId ?? this.scopeId,
    commandId: commandId ?? this.commandId,
    kind: kind ?? this.kind,
    targetId: targetId ?? this.targetId,
    ownershipRevision: ownershipRevision ?? this.ownershipRevision,
    registrationId: registrationId ?? this.registrationId,
    payload: payload ?? this.payload,
    firstSentAt: firstSentAt.present ? firstSentAt.value : this.firstSentAt,
    retryAt: retryAt.present ? retryAt.value : this.retryAt,
    state: state ?? this.state,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
  );
  SettingOutboxRow copyWithCompanion(ScopedSettingCommandsCompanion data) {
    return SettingOutboxRow(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      kind: data.kind.present ? data.kind.value : this.kind,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      ownershipRevision: data.ownershipRevision.present
          ? data.ownershipRevision.value
          : this.ownershipRevision,
      registrationId: data.registrationId.present
          ? data.registrationId.value
          : this.registrationId,
      payload: data.payload.present ? data.payload.value : this.payload,
      firstSentAt: data.firstSentAt.present
          ? data.firstSentAt.value
          : this.firstSentAt,
      retryAt: data.retryAt.present ? data.retryAt.value : this.retryAt,
      state: data.state.present ? data.state.value : this.state,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingOutboxRow(')
          ..write('scopeId: $scopeId, ')
          ..write('commandId: $commandId, ')
          ..write('kind: $kind, ')
          ..write('targetId: $targetId, ')
          ..write('ownershipRevision: $ownershipRevision, ')
          ..write('registrationId: $registrationId, ')
          ..write('payload: $payload, ')
          ..write('firstSentAt: $firstSentAt, ')
          ..write('retryAt: $retryAt, ')
          ..write('state: $state, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    commandId,
    kind,
    targetId,
    ownershipRevision,
    registrationId,
    payload,
    firstSentAt,
    retryAt,
    state,
    errorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingOutboxRow &&
          other.scopeId == this.scopeId &&
          other.commandId == this.commandId &&
          other.kind == this.kind &&
          other.targetId == this.targetId &&
          other.ownershipRevision == this.ownershipRevision &&
          other.registrationId == this.registrationId &&
          other.payload == this.payload &&
          other.firstSentAt == this.firstSentAt &&
          other.retryAt == this.retryAt &&
          other.state == this.state &&
          other.errorCode == this.errorCode);
}

class ScopedSettingCommandsCompanion extends UpdateCompanion<SettingOutboxRow> {
  final Value<int> scopeId;
  final Value<String> commandId;
  final Value<String> kind;
  final Value<String> targetId;
  final Value<int> ownershipRevision;
  final Value<String> registrationId;
  final Value<String> payload;
  final Value<DateTime?> firstSentAt;
  final Value<DateTime?> retryAt;
  final Value<String> state;
  final Value<String?> errorCode;
  final Value<int> rowid;
  const ScopedSettingCommandsCompanion({
    this.scopeId = const Value.absent(),
    this.commandId = const Value.absent(),
    this.kind = const Value.absent(),
    this.targetId = const Value.absent(),
    this.ownershipRevision = const Value.absent(),
    this.registrationId = const Value.absent(),
    this.payload = const Value.absent(),
    this.firstSentAt = const Value.absent(),
    this.retryAt = const Value.absent(),
    this.state = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScopedSettingCommandsCompanion.insert({
    required int scopeId,
    required String commandId,
    required String kind,
    required String targetId,
    required int ownershipRevision,
    required String registrationId,
    required String payload,
    this.firstSentAt = const Value.absent(),
    this.retryAt = const Value.absent(),
    required String state,
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       commandId = Value(commandId),
       kind = Value(kind),
       targetId = Value(targetId),
       ownershipRevision = Value(ownershipRevision),
       registrationId = Value(registrationId),
       payload = Value(payload),
       state = Value(state);
  static Insertable<SettingOutboxRow> custom({
    Expression<int>? scopeId,
    Expression<String>? commandId,
    Expression<String>? kind,
    Expression<String>? targetId,
    Expression<int>? ownershipRevision,
    Expression<String>? registrationId,
    Expression<String>? payload,
    Expression<DateTime>? firstSentAt,
    Expression<DateTime>? retryAt,
    Expression<String>? state,
    Expression<String>? errorCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (commandId != null) 'command_id': commandId,
      if (kind != null) 'kind': kind,
      if (targetId != null) 'target_id': targetId,
      if (ownershipRevision != null) 'ownership_revision': ownershipRevision,
      if (registrationId != null) 'registration_id': registrationId,
      if (payload != null) 'payload': payload,
      if (firstSentAt != null) 'first_sent_at': firstSentAt,
      if (retryAt != null) 'retry_at': retryAt,
      if (state != null) 'state': state,
      if (errorCode != null) 'error_code': errorCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScopedSettingCommandsCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? commandId,
    Value<String>? kind,
    Value<String>? targetId,
    Value<int>? ownershipRevision,
    Value<String>? registrationId,
    Value<String>? payload,
    Value<DateTime?>? firstSentAt,
    Value<DateTime?>? retryAt,
    Value<String>? state,
    Value<String?>? errorCode,
    Value<int>? rowid,
  }) {
    return ScopedSettingCommandsCompanion(
      scopeId: scopeId ?? this.scopeId,
      commandId: commandId ?? this.commandId,
      kind: kind ?? this.kind,
      targetId: targetId ?? this.targetId,
      ownershipRevision: ownershipRevision ?? this.ownershipRevision,
      registrationId: registrationId ?? this.registrationId,
      payload: payload ?? this.payload,
      firstSentAt: firstSentAt ?? this.firstSentAt,
      retryAt: retryAt ?? this.retryAt,
      state: state ?? this.state,
      errorCode: errorCode ?? this.errorCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (ownershipRevision.present) {
      map['ownership_revision'] = Variable<int>(ownershipRevision.value);
    }
    if (registrationId.present) {
      map['registration_id'] = Variable<String>(registrationId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (firstSentAt.present) {
      map['first_sent_at'] = Variable<DateTime>(firstSentAt.value);
    }
    if (retryAt.present) {
      map['retry_at'] = Variable<DateTime>(retryAt.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScopedSettingCommandsCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('commandId: $commandId, ')
          ..write('kind: $kind, ')
          ..write('targetId: $targetId, ')
          ..write('ownershipRevision: $ownershipRevision, ')
          ..write('registrationId: $registrationId, ')
          ..write('payload: $payload, ')
          ..write('firstSentAt: $firstSentAt, ')
          ..write('retryAt: $retryAt, ')
          ..write('state: $state, ')
          ..write('errorCode: $errorCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ScopedAccountCacheDatabase extends GeneratedDatabase {
  _$ScopedAccountCacheDatabase(QueryExecutor e) : super(e);
  $ScopedAccountCacheDatabaseManager get managers =>
      $ScopedAccountCacheDatabaseManager(this);
  late final $CacheScopesTable cacheScopes = $CacheScopesTable(this);
  late final $CachedAccountHeadsTable cachedAccountHeads =
      $CachedAccountHeadsTable(this);
  late final $CachedRegistrationsTable cachedRegistrations =
      $CachedRegistrationsTable(this);
  late final $CachedCharactersTable cachedCharacters = $CachedCharactersTable(
    this,
  );
  late final $ScopedRoleRecordsTable scopedRoleRecords =
      $ScopedRoleRecordsTable(this);
  late final $ScopedRoleCommandsTable scopedRoleCommands =
      $ScopedRoleCommandsTable(this);
  late final $ScopedSettingRecordsTable scopedSettingRecords =
      $ScopedSettingRecordsTable(this);
  late final $ScopedSettingCommandsTable scopedSettingCommands =
      $ScopedSettingCommandsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cacheScopes,
    cachedAccountHeads,
    cachedRegistrations,
    cachedCharacters,
    scopedRoleRecords,
    scopedRoleCommands,
    scopedSettingRecords,
    scopedSettingCommands,
  ];
}

typedef $$CacheScopesTableCreateCompanionBuilder =
    CacheScopesCompanion Function({
      Value<int> id,
      required String environment,
      required String userId,
      Value<int> localVersion,
      Value<int> snapshotSequence,
    });
typedef $$CacheScopesTableUpdateCompanionBuilder =
    CacheScopesCompanion Function({
      Value<int> id,
      Value<String> environment,
      Value<String> userId,
      Value<int> localVersion,
      Value<int> snapshotSequence,
    });

final class $$CacheScopesTableReferences
    extends
        BaseReferences<
          _$ScopedAccountCacheDatabase,
          $CacheScopesTable,
          CacheScope
        > {
  $$CacheScopesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CachedAccountHeadsTable, List<CachedAccountHead>>
  _cachedAccountHeadsRefsTable(_$ScopedAccountCacheDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cachedAccountHeads,
        aliasName: 'cache_scopes__id__cached_account_heads__scope_id',
      );

  $$CachedAccountHeadsTableProcessedTableManager get cachedAccountHeadsRefs {
    final manager = $$CachedAccountHeadsTableTableManager(
      $_db,
      $_db.cachedAccountHeads,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cachedAccountHeadsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CachedRegistrationsTable,
    List<CachedRegistration>
  >
  _cachedRegistrationsRefsTable(_$ScopedAccountCacheDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cachedRegistrations,
        aliasName: 'cache_scopes__id__cached_registrations__scope_id',
      );

  $$CachedRegistrationsTableProcessedTableManager get cachedRegistrationsRefs {
    final manager = $$CachedRegistrationsTableTableManager(
      $_db,
      $_db.cachedRegistrations,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cachedRegistrationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CachedCharactersTable, List<CachedCharacter>>
  _cachedCharactersRefsTable(_$ScopedAccountCacheDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cachedCharacters,
        aliasName: 'cache_scopes__id__cached_characters__scope_id',
      );

  $$CachedCharactersTableProcessedTableManager get cachedCharactersRefs {
    final manager = $$CachedCharactersTableTableManager(
      $_db,
      $_db.cachedCharacters,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cachedCharactersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CacheScopesTableFilterComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CacheScopesTable> {
  $$CacheScopesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snapshotSequence => $composableBuilder(
    column: $table.snapshotSequence,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cachedAccountHeadsRefs(
    Expression<bool> Function($$CachedAccountHeadsTableFilterComposer f) f,
  ) {
    final $$CachedAccountHeadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachedAccountHeads,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedAccountHeadsTableFilterComposer(
            $db: $db,
            $table: $db.cachedAccountHeads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cachedRegistrationsRefs(
    Expression<bool> Function($$CachedRegistrationsTableFilterComposer f) f,
  ) {
    final $$CachedRegistrationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachedRegistrations,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedRegistrationsTableFilterComposer(
            $db: $db,
            $table: $db.cachedRegistrations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cachedCharactersRefs(
    Expression<bool> Function($$CachedCharactersTableFilterComposer f) f,
  ) {
    final $$CachedCharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachedCharacters,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedCharactersTableFilterComposer(
            $db: $db,
            $table: $db.cachedCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CacheScopesTableOrderingComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CacheScopesTable> {
  $$CacheScopesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snapshotSequence => $composableBuilder(
    column: $table.snapshotSequence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheScopesTableAnnotationComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CacheScopesTable> {
  $$CacheScopesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snapshotSequence => $composableBuilder(
    column: $table.snapshotSequence,
    builder: (column) => column,
  );

  Expression<T> cachedAccountHeadsRefs<T extends Object>(
    Expression<T> Function($$CachedAccountHeadsTableAnnotationComposer a) f,
  ) {
    final $$CachedAccountHeadsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cachedAccountHeads,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CachedAccountHeadsTableAnnotationComposer(
                $db: $db,
                $table: $db.cachedAccountHeads,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> cachedRegistrationsRefs<T extends Object>(
    Expression<T> Function($$CachedRegistrationsTableAnnotationComposer a) f,
  ) {
    final $$CachedRegistrationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cachedRegistrations,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CachedRegistrationsTableAnnotationComposer(
                $db: $db,
                $table: $db.cachedRegistrations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> cachedCharactersRefs<T extends Object>(
    Expression<T> Function($$CachedCharactersTableAnnotationComposer a) f,
  ) {
    final $$CachedCharactersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachedCharacters,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedCharactersTableAnnotationComposer(
            $db: $db,
            $table: $db.cachedCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CacheScopesTableTableManager
    extends
        RootTableManager<
          _$ScopedAccountCacheDatabase,
          $CacheScopesTable,
          CacheScope,
          $$CacheScopesTableFilterComposer,
          $$CacheScopesTableOrderingComposer,
          $$CacheScopesTableAnnotationComposer,
          $$CacheScopesTableCreateCompanionBuilder,
          $$CacheScopesTableUpdateCompanionBuilder,
          (CacheScope, $$CacheScopesTableReferences),
          CacheScope,
          PrefetchHooks Function({
            bool cachedAccountHeadsRefs,
            bool cachedRegistrationsRefs,
            bool cachedCharactersRefs,
          })
        > {
  $$CacheScopesTableTableManager(
    _$ScopedAccountCacheDatabase db,
    $CacheScopesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheScopesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheScopesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheScopesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> environment = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<int> snapshotSequence = const Value.absent(),
              }) => CacheScopesCompanion(
                id: id,
                environment: environment,
                userId: userId,
                localVersion: localVersion,
                snapshotSequence: snapshotSequence,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String environment,
                required String userId,
                Value<int> localVersion = const Value.absent(),
                Value<int> snapshotSequence = const Value.absent(),
              }) => CacheScopesCompanion.insert(
                id: id,
                environment: environment,
                userId: userId,
                localVersion: localVersion,
                snapshotSequence: snapshotSequence,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CacheScopesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                cachedAccountHeadsRefs = false,
                cachedRegistrationsRefs = false,
                cachedCharactersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cachedAccountHeadsRefs) db.cachedAccountHeads,
                    if (cachedRegistrationsRefs) db.cachedRegistrations,
                    if (cachedCharactersRefs) db.cachedCharacters,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cachedAccountHeadsRefs)
                        await $_getPrefetchedData<
                          CacheScope,
                          $CacheScopesTable,
                          CachedAccountHead
                        >(
                          currentTable: table,
                          referencedTable: $$CacheScopesTableReferences
                              ._cachedAccountHeadsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).cachedAccountHeadsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cachedRegistrationsRefs)
                        await $_getPrefetchedData<
                          CacheScope,
                          $CacheScopesTable,
                          CachedRegistration
                        >(
                          currentTable: table,
                          referencedTable: $$CacheScopesTableReferences
                              ._cachedRegistrationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).cachedRegistrationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cachedCharactersRefs)
                        await $_getPrefetchedData<
                          CacheScope,
                          $CacheScopesTable,
                          CachedCharacter
                        >(
                          currentTable: table,
                          referencedTable: $$CacheScopesTableReferences
                              ._cachedCharactersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).cachedCharactersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CacheScopesTableProcessedTableManager =
    ProcessedTableManager<
      _$ScopedAccountCacheDatabase,
      $CacheScopesTable,
      CacheScope,
      $$CacheScopesTableFilterComposer,
      $$CacheScopesTableOrderingComposer,
      $$CacheScopesTableAnnotationComposer,
      $$CacheScopesTableCreateCompanionBuilder,
      $$CacheScopesTableUpdateCompanionBuilder,
      (CacheScope, $$CacheScopesTableReferences),
      CacheScope,
      PrefetchHooks Function({
        bool cachedAccountHeadsRefs,
        bool cachedRegistrationsRefs,
        bool cachedCharactersRefs,
      })
    >;
typedef $$CachedAccountHeadsTableCreateCompanionBuilder =
    CachedAccountHeadsCompanion Function({
      required int scopeId,
      required String accountId,
      Value<int> localVersion,
      Value<int> snapshotSequence,
      Value<bool> complete,
      Value<int?> ownershipRevisionFloor,
      Value<int> rosterRevisionFloor,
      Value<int?> settingsOwnershipRevision,
      Value<int> settingsVersionFloor,
      required String payload,
      Value<int> rowid,
    });
typedef $$CachedAccountHeadsTableUpdateCompanionBuilder =
    CachedAccountHeadsCompanion Function({
      Value<int> scopeId,
      Value<String> accountId,
      Value<int> localVersion,
      Value<int> snapshotSequence,
      Value<bool> complete,
      Value<int?> ownershipRevisionFloor,
      Value<int> rosterRevisionFloor,
      Value<int?> settingsOwnershipRevision,
      Value<int> settingsVersionFloor,
      Value<String> payload,
      Value<int> rowid,
    });

final class $$CachedAccountHeadsTableReferences
    extends
        BaseReferences<
          _$ScopedAccountCacheDatabase,
          $CachedAccountHeadsTable,
          CachedAccountHead
        > {
  $$CachedAccountHeadsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CacheScopesTable _scopeIdTable(_$ScopedAccountCacheDatabase db) => db
      .cacheScopes
      .createAlias('cached_account_heads__scope_id__cache_scopes__id');

  $$CacheScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$CacheScopesTableTableManager(
      $_db,
      $_db.cacheScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CachedAccountHeadsTableFilterComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CachedAccountHeadsTable> {
  $$CachedAccountHeadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snapshotSequence => $composableBuilder(
    column: $table.snapshotSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get complete => $composableBuilder(
    column: $table.complete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownershipRevisionFloor => $composableBuilder(
    column: $table.ownershipRevisionFloor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rosterRevisionFloor => $composableBuilder(
    column: $table.rosterRevisionFloor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get settingsOwnershipRevision => $composableBuilder(
    column: $table.settingsOwnershipRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get settingsVersionFloor => $composableBuilder(
    column: $table.settingsVersionFloor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  $$CacheScopesTableFilterComposer get scopeId {
    final $$CacheScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.cacheScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheScopesTableFilterComposer(
            $db: $db,
            $table: $db.cacheScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedAccountHeadsTableOrderingComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CachedAccountHeadsTable> {
  $$CachedAccountHeadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snapshotSequence => $composableBuilder(
    column: $table.snapshotSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get complete => $composableBuilder(
    column: $table.complete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownershipRevisionFloor => $composableBuilder(
    column: $table.ownershipRevisionFloor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rosterRevisionFloor => $composableBuilder(
    column: $table.rosterRevisionFloor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get settingsOwnershipRevision => $composableBuilder(
    column: $table.settingsOwnershipRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get settingsVersionFloor => $composableBuilder(
    column: $table.settingsVersionFloor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  $$CacheScopesTableOrderingComposer get scopeId {
    final $$CacheScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.cacheScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheScopesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedAccountHeadsTableAnnotationComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CachedAccountHeadsTable> {
  $$CachedAccountHeadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snapshotSequence => $composableBuilder(
    column: $table.snapshotSequence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get complete =>
      $composableBuilder(column: $table.complete, builder: (column) => column);

  GeneratedColumn<int> get ownershipRevisionFloor => $composableBuilder(
    column: $table.ownershipRevisionFloor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rosterRevisionFloor => $composableBuilder(
    column: $table.rosterRevisionFloor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get settingsOwnershipRevision => $composableBuilder(
    column: $table.settingsOwnershipRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get settingsVersionFloor => $composableBuilder(
    column: $table.settingsVersionFloor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  $$CacheScopesTableAnnotationComposer get scopeId {
    final $$CacheScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.cacheScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedAccountHeadsTableTableManager
    extends
        RootTableManager<
          _$ScopedAccountCacheDatabase,
          $CachedAccountHeadsTable,
          CachedAccountHead,
          $$CachedAccountHeadsTableFilterComposer,
          $$CachedAccountHeadsTableOrderingComposer,
          $$CachedAccountHeadsTableAnnotationComposer,
          $$CachedAccountHeadsTableCreateCompanionBuilder,
          $$CachedAccountHeadsTableUpdateCompanionBuilder,
          (CachedAccountHead, $$CachedAccountHeadsTableReferences),
          CachedAccountHead,
          PrefetchHooks Function({bool scopeId})
        > {
  $$CachedAccountHeadsTableTableManager(
    _$ScopedAccountCacheDatabase db,
    $CachedAccountHeadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedAccountHeadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedAccountHeadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedAccountHeadsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<int> snapshotSequence = const Value.absent(),
                Value<bool> complete = const Value.absent(),
                Value<int?> ownershipRevisionFloor = const Value.absent(),
                Value<int> rosterRevisionFloor = const Value.absent(),
                Value<int?> settingsOwnershipRevision = const Value.absent(),
                Value<int> settingsVersionFloor = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedAccountHeadsCompanion(
                scopeId: scopeId,
                accountId: accountId,
                localVersion: localVersion,
                snapshotSequence: snapshotSequence,
                complete: complete,
                ownershipRevisionFloor: ownershipRevisionFloor,
                rosterRevisionFloor: rosterRevisionFloor,
                settingsOwnershipRevision: settingsOwnershipRevision,
                settingsVersionFloor: settingsVersionFloor,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String accountId,
                Value<int> localVersion = const Value.absent(),
                Value<int> snapshotSequence = const Value.absent(),
                Value<bool> complete = const Value.absent(),
                Value<int?> ownershipRevisionFloor = const Value.absent(),
                Value<int> rosterRevisionFloor = const Value.absent(),
                Value<int?> settingsOwnershipRevision = const Value.absent(),
                Value<int> settingsVersionFloor = const Value.absent(),
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => CachedAccountHeadsCompanion.insert(
                scopeId: scopeId,
                accountId: accountId,
                localVersion: localVersion,
                snapshotSequence: snapshotSequence,
                complete: complete,
                ownershipRevisionFloor: ownershipRevisionFloor,
                rosterRevisionFloor: rosterRevisionFloor,
                settingsOwnershipRevision: settingsOwnershipRevision,
                settingsVersionFloor: settingsVersionFloor,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CachedAccountHeadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$CachedAccountHeadsTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$CachedAccountHeadsTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CachedAccountHeadsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScopedAccountCacheDatabase,
      $CachedAccountHeadsTable,
      CachedAccountHead,
      $$CachedAccountHeadsTableFilterComposer,
      $$CachedAccountHeadsTableOrderingComposer,
      $$CachedAccountHeadsTableAnnotationComposer,
      $$CachedAccountHeadsTableCreateCompanionBuilder,
      $$CachedAccountHeadsTableUpdateCompanionBuilder,
      (CachedAccountHead, $$CachedAccountHeadsTableReferences),
      CachedAccountHead,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$CachedRegistrationsTableCreateCompanionBuilder =
    CachedRegistrationsCompanion Function({
      required int scopeId,
      required String registrationId,
      Value<String?> accountId,
      Value<int> localVersion,
      required int seenSequence,
      required String payload,
      Value<int> rowid,
    });
typedef $$CachedRegistrationsTableUpdateCompanionBuilder =
    CachedRegistrationsCompanion Function({
      Value<int> scopeId,
      Value<String> registrationId,
      Value<String?> accountId,
      Value<int> localVersion,
      Value<int> seenSequence,
      Value<String> payload,
      Value<int> rowid,
    });

final class $$CachedRegistrationsTableReferences
    extends
        BaseReferences<
          _$ScopedAccountCacheDatabase,
          $CachedRegistrationsTable,
          CachedRegistration
        > {
  $$CachedRegistrationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CacheScopesTable _scopeIdTable(_$ScopedAccountCacheDatabase db) => db
      .cacheScopes
      .createAlias('cached_registrations__scope_id__cache_scopes__id');

  $$CacheScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$CacheScopesTableTableManager(
      $_db,
      $_db.cacheScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CachedRegistrationsTableFilterComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CachedRegistrationsTable> {
  $$CachedRegistrationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenSequence => $composableBuilder(
    column: $table.seenSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  $$CacheScopesTableFilterComposer get scopeId {
    final $$CacheScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.cacheScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheScopesTableFilterComposer(
            $db: $db,
            $table: $db.cacheScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedRegistrationsTableOrderingComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CachedRegistrationsTable> {
  $$CachedRegistrationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenSequence => $composableBuilder(
    column: $table.seenSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  $$CacheScopesTableOrderingComposer get scopeId {
    final $$CacheScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.cacheScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheScopesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedRegistrationsTableAnnotationComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CachedRegistrationsTable> {
  $$CachedRegistrationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seenSequence => $composableBuilder(
    column: $table.seenSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  $$CacheScopesTableAnnotationComposer get scopeId {
    final $$CacheScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.cacheScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedRegistrationsTableTableManager
    extends
        RootTableManager<
          _$ScopedAccountCacheDatabase,
          $CachedRegistrationsTable,
          CachedRegistration,
          $$CachedRegistrationsTableFilterComposer,
          $$CachedRegistrationsTableOrderingComposer,
          $$CachedRegistrationsTableAnnotationComposer,
          $$CachedRegistrationsTableCreateCompanionBuilder,
          $$CachedRegistrationsTableUpdateCompanionBuilder,
          (CachedRegistration, $$CachedRegistrationsTableReferences),
          CachedRegistration,
          PrefetchHooks Function({bool scopeId})
        > {
  $$CachedRegistrationsTableTableManager(
    _$ScopedAccountCacheDatabase db,
    $CachedRegistrationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedRegistrationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedRegistrationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedRegistrationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> registrationId = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<int> seenSequence = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedRegistrationsCompanion(
                scopeId: scopeId,
                registrationId: registrationId,
                accountId: accountId,
                localVersion: localVersion,
                seenSequence: seenSequence,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String registrationId,
                Value<String?> accountId = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                required int seenSequence,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => CachedRegistrationsCompanion.insert(
                scopeId: scopeId,
                registrationId: registrationId,
                accountId: accountId,
                localVersion: localVersion,
                seenSequence: seenSequence,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CachedRegistrationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$CachedRegistrationsTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$CachedRegistrationsTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CachedRegistrationsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScopedAccountCacheDatabase,
      $CachedRegistrationsTable,
      CachedRegistration,
      $$CachedRegistrationsTableFilterComposer,
      $$CachedRegistrationsTableOrderingComposer,
      $$CachedRegistrationsTableAnnotationComposer,
      $$CachedRegistrationsTableCreateCompanionBuilder,
      $$CachedRegistrationsTableUpdateCompanionBuilder,
      (CachedRegistration, $$CachedRegistrationsTableReferences),
      CachedRegistration,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$CachedCharactersTableCreateCompanionBuilder =
    CachedCharactersCompanion Function({
      required int scopeId,
      required String characterId,
      required String accountId,
      Value<int> localVersion,
      required int seenSequence,
      required String payload,
      Value<int> rowid,
    });
typedef $$CachedCharactersTableUpdateCompanionBuilder =
    CachedCharactersCompanion Function({
      Value<int> scopeId,
      Value<String> characterId,
      Value<String> accountId,
      Value<int> localVersion,
      Value<int> seenSequence,
      Value<String> payload,
      Value<int> rowid,
    });

final class $$CachedCharactersTableReferences
    extends
        BaseReferences<
          _$ScopedAccountCacheDatabase,
          $CachedCharactersTable,
          CachedCharacter
        > {
  $$CachedCharactersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CacheScopesTable _scopeIdTable(_$ScopedAccountCacheDatabase db) => db
      .cacheScopes
      .createAlias('cached_characters__scope_id__cache_scopes__id');

  $$CacheScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$CacheScopesTableTableManager(
      $_db,
      $_db.cacheScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CachedCharactersTableFilterComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CachedCharactersTable> {
  $$CachedCharactersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenSequence => $composableBuilder(
    column: $table.seenSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  $$CacheScopesTableFilterComposer get scopeId {
    final $$CacheScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.cacheScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheScopesTableFilterComposer(
            $db: $db,
            $table: $db.cacheScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedCharactersTableOrderingComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CachedCharactersTable> {
  $$CachedCharactersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenSequence => $composableBuilder(
    column: $table.seenSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  $$CacheScopesTableOrderingComposer get scopeId {
    final $$CacheScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.cacheScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheScopesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedCharactersTableAnnotationComposer
    extends Composer<_$ScopedAccountCacheDatabase, $CachedCharactersTable> {
  $$CachedCharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seenSequence => $composableBuilder(
    column: $table.seenSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  $$CacheScopesTableAnnotationComposer get scopeId {
    final $$CacheScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.cacheScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedCharactersTableTableManager
    extends
        RootTableManager<
          _$ScopedAccountCacheDatabase,
          $CachedCharactersTable,
          CachedCharacter,
          $$CachedCharactersTableFilterComposer,
          $$CachedCharactersTableOrderingComposer,
          $$CachedCharactersTableAnnotationComposer,
          $$CachedCharactersTableCreateCompanionBuilder,
          $$CachedCharactersTableUpdateCompanionBuilder,
          (CachedCharacter, $$CachedCharactersTableReferences),
          CachedCharacter,
          PrefetchHooks Function({bool scopeId})
        > {
  $$CachedCharactersTableTableManager(
    _$ScopedAccountCacheDatabase db,
    $CachedCharactersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<int> seenSequence = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCharactersCompanion(
                scopeId: scopeId,
                characterId: characterId,
                accountId: accountId,
                localVersion: localVersion,
                seenSequence: seenSequence,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String characterId,
                required String accountId,
                Value<int> localVersion = const Value.absent(),
                required int seenSequence,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => CachedCharactersCompanion.insert(
                scopeId: scopeId,
                characterId: characterId,
                accountId: accountId,
                localVersion: localVersion,
                seenSequence: seenSequence,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CachedCharactersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$CachedCharactersTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$CachedCharactersTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CachedCharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$ScopedAccountCacheDatabase,
      $CachedCharactersTable,
      CachedCharacter,
      $$CachedCharactersTableFilterComposer,
      $$CachedCharactersTableOrderingComposer,
      $$CachedCharactersTableAnnotationComposer,
      $$CachedCharactersTableCreateCompanionBuilder,
      $$CachedCharactersTableUpdateCompanionBuilder,
      (CachedCharacter, $$CachedCharactersTableReferences),
      CachedCharacter,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$ScopedRoleRecordsTableCreateCompanionBuilder =
    ScopedRoleRecordsCompanion Function({
      required int scopeId,
      required String characterId,
      required String accountId,
      required int ownershipRevision,
      required String role,
      required int rowVersion,
      required String payload,
      Value<int> rowid,
    });
typedef $$ScopedRoleRecordsTableUpdateCompanionBuilder =
    ScopedRoleRecordsCompanion Function({
      Value<int> scopeId,
      Value<String> characterId,
      Value<String> accountId,
      Value<int> ownershipRevision,
      Value<String> role,
      Value<int> rowVersion,
      Value<String> payload,
      Value<int> rowid,
    });

class $$ScopedRoleRecordsTableFilterComposer
    extends Composer<_$ScopedAccountCacheDatabase, $ScopedRoleRecordsTable> {
  $$ScopedRoleRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScopedRoleRecordsTableOrderingComposer
    extends Composer<_$ScopedAccountCacheDatabase, $ScopedRoleRecordsTable> {
  $$ScopedRoleRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScopedRoleRecordsTableAnnotationComposer
    extends Composer<_$ScopedAccountCacheDatabase, $ScopedRoleRecordsTable> {
  $$ScopedRoleRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$ScopedRoleRecordsTableTableManager
    extends
        RootTableManager<
          _$ScopedAccountCacheDatabase,
          $ScopedRoleRecordsTable,
          ScopedRoleRecord,
          $$ScopedRoleRecordsTableFilterComposer,
          $$ScopedRoleRecordsTableOrderingComposer,
          $$ScopedRoleRecordsTableAnnotationComposer,
          $$ScopedRoleRecordsTableCreateCompanionBuilder,
          $$ScopedRoleRecordsTableUpdateCompanionBuilder,
          (
            ScopedRoleRecord,
            BaseReferences<
              _$ScopedAccountCacheDatabase,
              $ScopedRoleRecordsTable,
              ScopedRoleRecord
            >,
          ),
          ScopedRoleRecord,
          PrefetchHooks Function()
        > {
  $$ScopedRoleRecordsTableTableManager(
    _$ScopedAccountCacheDatabase db,
    $ScopedRoleRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScopedRoleRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScopedRoleRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScopedRoleRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<int> ownershipRevision = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> rowVersion = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScopedRoleRecordsCompanion(
                scopeId: scopeId,
                characterId: characterId,
                accountId: accountId,
                ownershipRevision: ownershipRevision,
                role: role,
                rowVersion: rowVersion,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String characterId,
                required String accountId,
                required int ownershipRevision,
                required String role,
                required int rowVersion,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => ScopedRoleRecordsCompanion.insert(
                scopeId: scopeId,
                characterId: characterId,
                accountId: accountId,
                ownershipRevision: ownershipRevision,
                role: role,
                rowVersion: rowVersion,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScopedRoleRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScopedAccountCacheDatabase,
      $ScopedRoleRecordsTable,
      ScopedRoleRecord,
      $$ScopedRoleRecordsTableFilterComposer,
      $$ScopedRoleRecordsTableOrderingComposer,
      $$ScopedRoleRecordsTableAnnotationComposer,
      $$ScopedRoleRecordsTableCreateCompanionBuilder,
      $$ScopedRoleRecordsTableUpdateCompanionBuilder,
      (
        ScopedRoleRecord,
        BaseReferences<
          _$ScopedAccountCacheDatabase,
          $ScopedRoleRecordsTable,
          ScopedRoleRecord
        >,
      ),
      ScopedRoleRecord,
      PrefetchHooks Function()
    >;
typedef $$ScopedRoleCommandsTableCreateCompanionBuilder =
    ScopedRoleCommandsCompanion Function({
      required int scopeId,
      required String commandId,
      required String characterId,
      required int ownershipRevision,
      required String role,
      required String payload,
      Value<DateTime?> firstSentAt,
      Value<DateTime?> retryAt,
      required String state,
      Value<String?> errorCode,
      Value<int> rowid,
    });
typedef $$ScopedRoleCommandsTableUpdateCompanionBuilder =
    ScopedRoleCommandsCompanion Function({
      Value<int> scopeId,
      Value<String> commandId,
      Value<String> characterId,
      Value<int> ownershipRevision,
      Value<String> role,
      Value<String> payload,
      Value<DateTime?> firstSentAt,
      Value<DateTime?> retryAt,
      Value<String> state,
      Value<String?> errorCode,
      Value<int> rowid,
    });

class $$ScopedRoleCommandsTableFilterComposer
    extends Composer<_$ScopedAccountCacheDatabase, $ScopedRoleCommandsTable> {
  $$ScopedRoleCommandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSentAt => $composableBuilder(
    column: $table.firstSentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get retryAt => $composableBuilder(
    column: $table.retryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScopedRoleCommandsTableOrderingComposer
    extends Composer<_$ScopedAccountCacheDatabase, $ScopedRoleCommandsTable> {
  $$ScopedRoleCommandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSentAt => $composableBuilder(
    column: $table.firstSentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get retryAt => $composableBuilder(
    column: $table.retryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScopedRoleCommandsTableAnnotationComposer
    extends Composer<_$ScopedAccountCacheDatabase, $ScopedRoleCommandsTable> {
  $$ScopedRoleCommandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSentAt => $composableBuilder(
    column: $table.firstSentAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get retryAt =>
      $composableBuilder(column: $table.retryAt, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);
}

class $$ScopedRoleCommandsTableTableManager
    extends
        RootTableManager<
          _$ScopedAccountCacheDatabase,
          $ScopedRoleCommandsTable,
          RoleOutboxRow,
          $$ScopedRoleCommandsTableFilterComposer,
          $$ScopedRoleCommandsTableOrderingComposer,
          $$ScopedRoleCommandsTableAnnotationComposer,
          $$ScopedRoleCommandsTableCreateCompanionBuilder,
          $$ScopedRoleCommandsTableUpdateCompanionBuilder,
          (
            RoleOutboxRow,
            BaseReferences<
              _$ScopedAccountCacheDatabase,
              $ScopedRoleCommandsTable,
              RoleOutboxRow
            >,
          ),
          RoleOutboxRow,
          PrefetchHooks Function()
        > {
  $$ScopedRoleCommandsTableTableManager(
    _$ScopedAccountCacheDatabase db,
    $ScopedRoleCommandsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScopedRoleCommandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScopedRoleCommandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScopedRoleCommandsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<int> ownershipRevision = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime?> firstSentAt = const Value.absent(),
                Value<DateTime?> retryAt = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScopedRoleCommandsCompanion(
                scopeId: scopeId,
                commandId: commandId,
                characterId: characterId,
                ownershipRevision: ownershipRevision,
                role: role,
                payload: payload,
                firstSentAt: firstSentAt,
                retryAt: retryAt,
                state: state,
                errorCode: errorCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String commandId,
                required String characterId,
                required int ownershipRevision,
                required String role,
                required String payload,
                Value<DateTime?> firstSentAt = const Value.absent(),
                Value<DateTime?> retryAt = const Value.absent(),
                required String state,
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScopedRoleCommandsCompanion.insert(
                scopeId: scopeId,
                commandId: commandId,
                characterId: characterId,
                ownershipRevision: ownershipRevision,
                role: role,
                payload: payload,
                firstSentAt: firstSentAt,
                retryAt: retryAt,
                state: state,
                errorCode: errorCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScopedRoleCommandsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScopedAccountCacheDatabase,
      $ScopedRoleCommandsTable,
      RoleOutboxRow,
      $$ScopedRoleCommandsTableFilterComposer,
      $$ScopedRoleCommandsTableOrderingComposer,
      $$ScopedRoleCommandsTableAnnotationComposer,
      $$ScopedRoleCommandsTableCreateCompanionBuilder,
      $$ScopedRoleCommandsTableUpdateCompanionBuilder,
      (
        RoleOutboxRow,
        BaseReferences<
          _$ScopedAccountCacheDatabase,
          $ScopedRoleCommandsTable,
          RoleOutboxRow
        >,
      ),
      RoleOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$ScopedSettingRecordsTableCreateCompanionBuilder =
    ScopedSettingRecordsCompanion Function({
      required int scopeId,
      required String kind,
      required String targetId,
      required String accountId,
      Value<String?> characterId,
      required int ownershipRevision,
      required int rowVersion,
      required String payload,
      Value<int> rowid,
    });
typedef $$ScopedSettingRecordsTableUpdateCompanionBuilder =
    ScopedSettingRecordsCompanion Function({
      Value<int> scopeId,
      Value<String> kind,
      Value<String> targetId,
      Value<String> accountId,
      Value<String?> characterId,
      Value<int> ownershipRevision,
      Value<int> rowVersion,
      Value<String> payload,
      Value<int> rowid,
    });

class $$ScopedSettingRecordsTableFilterComposer
    extends Composer<_$ScopedAccountCacheDatabase, $ScopedSettingRecordsTable> {
  $$ScopedSettingRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScopedSettingRecordsTableOrderingComposer
    extends Composer<_$ScopedAccountCacheDatabase, $ScopedSettingRecordsTable> {
  $$ScopedSettingRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScopedSettingRecordsTableAnnotationComposer
    extends Composer<_$ScopedAccountCacheDatabase, $ScopedSettingRecordsTable> {
  $$ScopedSettingRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$ScopedSettingRecordsTableTableManager
    extends
        RootTableManager<
          _$ScopedAccountCacheDatabase,
          $ScopedSettingRecordsTable,
          ScopedSettingRecord,
          $$ScopedSettingRecordsTableFilterComposer,
          $$ScopedSettingRecordsTableOrderingComposer,
          $$ScopedSettingRecordsTableAnnotationComposer,
          $$ScopedSettingRecordsTableCreateCompanionBuilder,
          $$ScopedSettingRecordsTableUpdateCompanionBuilder,
          (
            ScopedSettingRecord,
            BaseReferences<
              _$ScopedAccountCacheDatabase,
              $ScopedSettingRecordsTable,
              ScopedSettingRecord
            >,
          ),
          ScopedSettingRecord,
          PrefetchHooks Function()
        > {
  $$ScopedSettingRecordsTableTableManager(
    _$ScopedAccountCacheDatabase db,
    $ScopedSettingRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScopedSettingRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScopedSettingRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScopedSettingRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> characterId = const Value.absent(),
                Value<int> ownershipRevision = const Value.absent(),
                Value<int> rowVersion = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScopedSettingRecordsCompanion(
                scopeId: scopeId,
                kind: kind,
                targetId: targetId,
                accountId: accountId,
                characterId: characterId,
                ownershipRevision: ownershipRevision,
                rowVersion: rowVersion,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String kind,
                required String targetId,
                required String accountId,
                Value<String?> characterId = const Value.absent(),
                required int ownershipRevision,
                required int rowVersion,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => ScopedSettingRecordsCompanion.insert(
                scopeId: scopeId,
                kind: kind,
                targetId: targetId,
                accountId: accountId,
                characterId: characterId,
                ownershipRevision: ownershipRevision,
                rowVersion: rowVersion,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScopedSettingRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScopedAccountCacheDatabase,
      $ScopedSettingRecordsTable,
      ScopedSettingRecord,
      $$ScopedSettingRecordsTableFilterComposer,
      $$ScopedSettingRecordsTableOrderingComposer,
      $$ScopedSettingRecordsTableAnnotationComposer,
      $$ScopedSettingRecordsTableCreateCompanionBuilder,
      $$ScopedSettingRecordsTableUpdateCompanionBuilder,
      (
        ScopedSettingRecord,
        BaseReferences<
          _$ScopedAccountCacheDatabase,
          $ScopedSettingRecordsTable,
          ScopedSettingRecord
        >,
      ),
      ScopedSettingRecord,
      PrefetchHooks Function()
    >;
typedef $$ScopedSettingCommandsTableCreateCompanionBuilder =
    ScopedSettingCommandsCompanion Function({
      required int scopeId,
      required String commandId,
      required String kind,
      required String targetId,
      required int ownershipRevision,
      required String registrationId,
      required String payload,
      Value<DateTime?> firstSentAt,
      Value<DateTime?> retryAt,
      required String state,
      Value<String?> errorCode,
      Value<int> rowid,
    });
typedef $$ScopedSettingCommandsTableUpdateCompanionBuilder =
    ScopedSettingCommandsCompanion Function({
      Value<int> scopeId,
      Value<String> commandId,
      Value<String> kind,
      Value<String> targetId,
      Value<int> ownershipRevision,
      Value<String> registrationId,
      Value<String> payload,
      Value<DateTime?> firstSentAt,
      Value<DateTime?> retryAt,
      Value<String> state,
      Value<String?> errorCode,
      Value<int> rowid,
    });

class $$ScopedSettingCommandsTableFilterComposer
    extends
        Composer<_$ScopedAccountCacheDatabase, $ScopedSettingCommandsTable> {
  $$ScopedSettingCommandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSentAt => $composableBuilder(
    column: $table.firstSentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get retryAt => $composableBuilder(
    column: $table.retryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScopedSettingCommandsTableOrderingComposer
    extends
        Composer<_$ScopedAccountCacheDatabase, $ScopedSettingCommandsTable> {
  $$ScopedSettingCommandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSentAt => $composableBuilder(
    column: $table.firstSentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get retryAt => $composableBuilder(
    column: $table.retryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScopedSettingCommandsTableAnnotationComposer
    extends
        Composer<_$ScopedAccountCacheDatabase, $ScopedSettingCommandsTable> {
  $$ScopedSettingCommandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<int> get ownershipRevision => $composableBuilder(
    column: $table.ownershipRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSentAt => $composableBuilder(
    column: $table.firstSentAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get retryAt =>
      $composableBuilder(column: $table.retryAt, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);
}

class $$ScopedSettingCommandsTableTableManager
    extends
        RootTableManager<
          _$ScopedAccountCacheDatabase,
          $ScopedSettingCommandsTable,
          SettingOutboxRow,
          $$ScopedSettingCommandsTableFilterComposer,
          $$ScopedSettingCommandsTableOrderingComposer,
          $$ScopedSettingCommandsTableAnnotationComposer,
          $$ScopedSettingCommandsTableCreateCompanionBuilder,
          $$ScopedSettingCommandsTableUpdateCompanionBuilder,
          (
            SettingOutboxRow,
            BaseReferences<
              _$ScopedAccountCacheDatabase,
              $ScopedSettingCommandsTable,
              SettingOutboxRow
            >,
          ),
          SettingOutboxRow,
          PrefetchHooks Function()
        > {
  $$ScopedSettingCommandsTableTableManager(
    _$ScopedAccountCacheDatabase db,
    $ScopedSettingCommandsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScopedSettingCommandsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ScopedSettingCommandsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScopedSettingCommandsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<int> ownershipRevision = const Value.absent(),
                Value<String> registrationId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime?> firstSentAt = const Value.absent(),
                Value<DateTime?> retryAt = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScopedSettingCommandsCompanion(
                scopeId: scopeId,
                commandId: commandId,
                kind: kind,
                targetId: targetId,
                ownershipRevision: ownershipRevision,
                registrationId: registrationId,
                payload: payload,
                firstSentAt: firstSentAt,
                retryAt: retryAt,
                state: state,
                errorCode: errorCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String commandId,
                required String kind,
                required String targetId,
                required int ownershipRevision,
                required String registrationId,
                required String payload,
                Value<DateTime?> firstSentAt = const Value.absent(),
                Value<DateTime?> retryAt = const Value.absent(),
                required String state,
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScopedSettingCommandsCompanion.insert(
                scopeId: scopeId,
                commandId: commandId,
                kind: kind,
                targetId: targetId,
                ownershipRevision: ownershipRevision,
                registrationId: registrationId,
                payload: payload,
                firstSentAt: firstSentAt,
                retryAt: retryAt,
                state: state,
                errorCode: errorCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScopedSettingCommandsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScopedAccountCacheDatabase,
      $ScopedSettingCommandsTable,
      SettingOutboxRow,
      $$ScopedSettingCommandsTableFilterComposer,
      $$ScopedSettingCommandsTableOrderingComposer,
      $$ScopedSettingCommandsTableAnnotationComposer,
      $$ScopedSettingCommandsTableCreateCompanionBuilder,
      $$ScopedSettingCommandsTableUpdateCompanionBuilder,
      (
        SettingOutboxRow,
        BaseReferences<
          _$ScopedAccountCacheDatabase,
          $ScopedSettingCommandsTable,
          SettingOutboxRow
        >,
      ),
      SettingOutboxRow,
      PrefetchHooks Function()
    >;

class $ScopedAccountCacheDatabaseManager {
  final _$ScopedAccountCacheDatabase _db;
  $ScopedAccountCacheDatabaseManager(this._db);
  $$CacheScopesTableTableManager get cacheScopes =>
      $$CacheScopesTableTableManager(_db, _db.cacheScopes);
  $$CachedAccountHeadsTableTableManager get cachedAccountHeads =>
      $$CachedAccountHeadsTableTableManager(_db, _db.cachedAccountHeads);
  $$CachedRegistrationsTableTableManager get cachedRegistrations =>
      $$CachedRegistrationsTableTableManager(_db, _db.cachedRegistrations);
  $$CachedCharactersTableTableManager get cachedCharacters =>
      $$CachedCharactersTableTableManager(_db, _db.cachedCharacters);
  $$ScopedRoleRecordsTableTableManager get scopedRoleRecords =>
      $$ScopedRoleRecordsTableTableManager(_db, _db.scopedRoleRecords);
  $$ScopedRoleCommandsTableTableManager get scopedRoleCommands =>
      $$ScopedRoleCommandsTableTableManager(_db, _db.scopedRoleCommands);
  $$ScopedSettingRecordsTableTableManager get scopedSettingRecords =>
      $$ScopedSettingRecordsTableTableManager(_db, _db.scopedSettingRecords);
  $$ScopedSettingCommandsTableTableManager get scopedSettingCommands =>
      $$ScopedSettingCommandsTableTableManager(_db, _db.scopedSettingCommands);
}
