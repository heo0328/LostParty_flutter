// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recruitment_command_database.dart';

// ignore_for_file: type=lint
class $RecruitmentCommandRowsTable extends RecruitmentCommandRows
    with TableInfo<$RecruitmentCommandRowsTable, RecruitmentCommandRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecruitmentCommandRowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
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
  @override
  List<GeneratedColumn> get $columns => [environment, userId, owner, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recruitment_command_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecruitmentCommandRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
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
  Set<GeneratedColumn> get $primaryKey => {environment, userId, owner};
  @override
  RecruitmentCommandRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecruitmentCommandRow(
      environment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}environment'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $RecruitmentCommandRowsTable createAlias(String alias) {
    return $RecruitmentCommandRowsTable(attachedDatabase, alias);
  }
}

class RecruitmentCommandRow extends DataClass
    implements Insertable<RecruitmentCommandRow> {
  final String environment;
  final String userId;
  final String owner;
  final String payload;
  const RecruitmentCommandRow({
    required this.environment,
    required this.userId,
    required this.owner,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['environment'] = Variable<String>(environment);
    map['user_id'] = Variable<String>(userId);
    map['owner'] = Variable<String>(owner);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  RecruitmentCommandRowsCompanion toCompanion(bool nullToAbsent) {
    return RecruitmentCommandRowsCompanion(
      environment: Value(environment),
      userId: Value(userId),
      owner: Value(owner),
      payload: Value(payload),
    );
  }

  factory RecruitmentCommandRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecruitmentCommandRow(
      environment: serializer.fromJson<String>(json['environment']),
      userId: serializer.fromJson<String>(json['userId']),
      owner: serializer.fromJson<String>(json['owner']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'environment': serializer.toJson<String>(environment),
      'userId': serializer.toJson<String>(userId),
      'owner': serializer.toJson<String>(owner),
      'payload': serializer.toJson<String>(payload),
    };
  }

  RecruitmentCommandRow copyWith({
    String? environment,
    String? userId,
    String? owner,
    String? payload,
  }) => RecruitmentCommandRow(
    environment: environment ?? this.environment,
    userId: userId ?? this.userId,
    owner: owner ?? this.owner,
    payload: payload ?? this.payload,
  );
  RecruitmentCommandRow copyWithCompanion(
    RecruitmentCommandRowsCompanion data,
  ) {
    return RecruitmentCommandRow(
      environment: data.environment.present
          ? data.environment.value
          : this.environment,
      userId: data.userId.present ? data.userId.value : this.userId,
      owner: data.owner.present ? data.owner.value : this.owner,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecruitmentCommandRow(')
          ..write('environment: $environment, ')
          ..write('userId: $userId, ')
          ..write('owner: $owner, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(environment, userId, owner, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecruitmentCommandRow &&
          other.environment == this.environment &&
          other.userId == this.userId &&
          other.owner == this.owner &&
          other.payload == this.payload);
}

class RecruitmentCommandRowsCompanion
    extends UpdateCompanion<RecruitmentCommandRow> {
  final Value<String> environment;
  final Value<String> userId;
  final Value<String> owner;
  final Value<String> payload;
  final Value<int> rowid;
  const RecruitmentCommandRowsCompanion({
    this.environment = const Value.absent(),
    this.userId = const Value.absent(),
    this.owner = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecruitmentCommandRowsCompanion.insert({
    required String environment,
    required String userId,
    required String owner,
    required String payload,
    this.rowid = const Value.absent(),
  }) : environment = Value(environment),
       userId = Value(userId),
       owner = Value(owner),
       payload = Value(payload);
  static Insertable<RecruitmentCommandRow> custom({
    Expression<String>? environment,
    Expression<String>? userId,
    Expression<String>? owner,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (environment != null) 'environment': environment,
      if (userId != null) 'user_id': userId,
      if (owner != null) 'owner': owner,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecruitmentCommandRowsCompanion copyWith({
    Value<String>? environment,
    Value<String>? userId,
    Value<String>? owner,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return RecruitmentCommandRowsCompanion(
      environment: environment ?? this.environment,
      userId: userId ?? this.userId,
      owner: owner ?? this.owner,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
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
    return (StringBuffer('RecruitmentCommandRowsCompanion(')
          ..write('environment: $environment, ')
          ..write('userId: $userId, ')
          ..write('owner: $owner, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$RecruitmentCommandDatabase extends GeneratedDatabase {
  _$RecruitmentCommandDatabase(QueryExecutor e) : super(e);
  $RecruitmentCommandDatabaseManager get managers =>
      $RecruitmentCommandDatabaseManager(this);
  late final $RecruitmentCommandRowsTable recruitmentCommandRows =
      $RecruitmentCommandRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [recruitmentCommandRows];
}

typedef $$RecruitmentCommandRowsTableCreateCompanionBuilder =
    RecruitmentCommandRowsCompanion Function({
      required String environment,
      required String userId,
      required String owner,
      required String payload,
      Value<int> rowid,
    });
typedef $$RecruitmentCommandRowsTableUpdateCompanionBuilder =
    RecruitmentCommandRowsCompanion Function({
      Value<String> environment,
      Value<String> userId,
      Value<String> owner,
      Value<String> payload,
      Value<int> rowid,
    });

class $$RecruitmentCommandRowsTableFilterComposer
    extends
        Composer<_$RecruitmentCommandDatabase, $RecruitmentCommandRowsTable> {
  $$RecruitmentCommandRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecruitmentCommandRowsTableOrderingComposer
    extends
        Composer<_$RecruitmentCommandDatabase, $RecruitmentCommandRowsTable> {
  $$RecruitmentCommandRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecruitmentCommandRowsTableAnnotationComposer
    extends
        Composer<_$RecruitmentCommandDatabase, $RecruitmentCommandRowsTable> {
  $$RecruitmentCommandRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$RecruitmentCommandRowsTableTableManager
    extends
        RootTableManager<
          _$RecruitmentCommandDatabase,
          $RecruitmentCommandRowsTable,
          RecruitmentCommandRow,
          $$RecruitmentCommandRowsTableFilterComposer,
          $$RecruitmentCommandRowsTableOrderingComposer,
          $$RecruitmentCommandRowsTableAnnotationComposer,
          $$RecruitmentCommandRowsTableCreateCompanionBuilder,
          $$RecruitmentCommandRowsTableUpdateCompanionBuilder,
          (
            RecruitmentCommandRow,
            BaseReferences<
              _$RecruitmentCommandDatabase,
              $RecruitmentCommandRowsTable,
              RecruitmentCommandRow
            >,
          ),
          RecruitmentCommandRow,
          PrefetchHooks Function()
        > {
  $$RecruitmentCommandRowsTableTableManager(
    _$RecruitmentCommandDatabase db,
    $RecruitmentCommandRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecruitmentCommandRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RecruitmentCommandRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecruitmentCommandRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> environment = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> owner = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecruitmentCommandRowsCompanion(
                environment: environment,
                userId: userId,
                owner: owner,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String environment,
                required String userId,
                required String owner,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => RecruitmentCommandRowsCompanion.insert(
                environment: environment,
                userId: userId,
                owner: owner,
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

typedef $$RecruitmentCommandRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$RecruitmentCommandDatabase,
      $RecruitmentCommandRowsTable,
      RecruitmentCommandRow,
      $$RecruitmentCommandRowsTableFilterComposer,
      $$RecruitmentCommandRowsTableOrderingComposer,
      $$RecruitmentCommandRowsTableAnnotationComposer,
      $$RecruitmentCommandRowsTableCreateCompanionBuilder,
      $$RecruitmentCommandRowsTableUpdateCompanionBuilder,
      (
        RecruitmentCommandRow,
        BaseReferences<
          _$RecruitmentCommandDatabase,
          $RecruitmentCommandRowsTable,
          RecruitmentCommandRow
        >,
      ),
      RecruitmentCommandRow,
      PrefetchHooks Function()
    >;

class $RecruitmentCommandDatabaseManager {
  final _$RecruitmentCommandDatabase _db;
  $RecruitmentCommandDatabaseManager(this._db);
  $$RecruitmentCommandRowsTableTableManager get recruitmentCommandRows =>
      $$RecruitmentCommandRowsTableTableManager(
        _db,
        _db.recruitmentCommandRows,
      );
}
