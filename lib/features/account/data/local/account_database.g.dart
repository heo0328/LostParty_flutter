// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_database.dart';

// ignore_for_file: type=lint
class $GameAccountsTable extends GameAccounts
    with TableInfo<$GameAccountsTable, GameAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameAccountsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _serverGameAccountIdMeta =
      const VerificationMeta('serverGameAccountId');
  @override
  late final GeneratedColumn<String> serverGameAccountId =
      GeneratedColumn<String>(
        'server_game_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverOwnershipStatusMeta =
      const VerificationMeta('serverOwnershipStatus');
  @override
  late final GeneratedColumn<String> serverOwnershipStatus =
      GeneratedColumn<String>(
        'server_ownership_status',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isMainMeta = const VerificationMeta('isMain');
  @override
  late final GeneratedColumn<bool> isMain = GeneratedColumn<bool>(
    'is_main',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_main" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lookupCharacterNameMeta =
      const VerificationMeta('lookupCharacterName');
  @override
  late final GeneratedColumn<String> lookupCharacterName =
      GeneratedColumn<String>(
        'lookup_character_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _representativeCharacterIdMeta =
      const VerificationMeta('representativeCharacterId');
  @override
  late final GeneratedColumn<int> representativeCharacterId =
      GeneratedColumn<int>(
        'representative_character_id',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _displayLimitMeta = const VerificationMeta(
    'displayLimit',
  );
  @override
  late final GeneratedColumn<int> displayLimit = GeneratedColumn<int>(
    'display_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(6),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverGameAccountId,
    serverOwnershipStatus,
    label,
    isMain,
    lookupCharacterName,
    representativeCharacterId,
    displayLimit,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_game_account_id')) {
      context.handle(
        _serverGameAccountIdMeta,
        serverGameAccountId.isAcceptableOrUnknown(
          data['server_game_account_id']!,
          _serverGameAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('server_ownership_status')) {
      context.handle(
        _serverOwnershipStatusMeta,
        serverOwnershipStatus.isAcceptableOrUnknown(
          data['server_ownership_status']!,
          _serverOwnershipStatusMeta,
        ),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('is_main')) {
      context.handle(
        _isMainMeta,
        isMain.isAcceptableOrUnknown(data['is_main']!, _isMainMeta),
      );
    }
    if (data.containsKey('lookup_character_name')) {
      context.handle(
        _lookupCharacterNameMeta,
        lookupCharacterName.isAcceptableOrUnknown(
          data['lookup_character_name']!,
          _lookupCharacterNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lookupCharacterNameMeta);
    }
    if (data.containsKey('representative_character_id')) {
      context.handle(
        _representativeCharacterIdMeta,
        representativeCharacterId.isAcceptableOrUnknown(
          data['representative_character_id']!,
          _representativeCharacterIdMeta,
        ),
      );
    }
    if (data.containsKey('display_limit')) {
      context.handle(
        _displayLimitMeta,
        displayLimit.isAcceptableOrUnknown(
          data['display_limit']!,
          _displayLimitMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameAccount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverGameAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_game_account_id'],
      ),
      serverOwnershipStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_ownership_status'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      isMain: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_main'],
      )!,
      lookupCharacterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lookup_character_name'],
      )!,
      representativeCharacterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}representative_character_id'],
      ),
      displayLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_limit'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GameAccountsTable createAlias(String alias) {
    return $GameAccountsTable(attachedDatabase, alias);
  }
}

class GameAccount extends DataClass implements Insertable<GameAccount> {
  final int id;
  final String? serverGameAccountId;
  final String? serverOwnershipStatus;
  final String label;
  final bool isMain;
  final String lookupCharacterName;
  final int? representativeCharacterId;
  final int displayLimit;
  final DateTime createdAt;
  final DateTime updatedAt;
  const GameAccount({
    required this.id,
    this.serverGameAccountId,
    this.serverOwnershipStatus,
    required this.label,
    required this.isMain,
    required this.lookupCharacterName,
    this.representativeCharacterId,
    required this.displayLimit,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverGameAccountId != null) {
      map['server_game_account_id'] = Variable<String>(serverGameAccountId);
    }
    if (!nullToAbsent || serverOwnershipStatus != null) {
      map['server_ownership_status'] = Variable<String>(serverOwnershipStatus);
    }
    map['label'] = Variable<String>(label);
    map['is_main'] = Variable<bool>(isMain);
    map['lookup_character_name'] = Variable<String>(lookupCharacterName);
    if (!nullToAbsent || representativeCharacterId != null) {
      map['representative_character_id'] = Variable<int>(
        representativeCharacterId,
      );
    }
    map['display_limit'] = Variable<int>(displayLimit);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GameAccountsCompanion toCompanion(bool nullToAbsent) {
    return GameAccountsCompanion(
      id: Value(id),
      serverGameAccountId: serverGameAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverGameAccountId),
      serverOwnershipStatus: serverOwnershipStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(serverOwnershipStatus),
      label: Value(label),
      isMain: Value(isMain),
      lookupCharacterName: Value(lookupCharacterName),
      representativeCharacterId:
          representativeCharacterId == null && nullToAbsent
          ? const Value.absent()
          : Value(representativeCharacterId),
      displayLimit: Value(displayLimit),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GameAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameAccount(
      id: serializer.fromJson<int>(json['id']),
      serverGameAccountId: serializer.fromJson<String?>(
        json['serverGameAccountId'],
      ),
      serverOwnershipStatus: serializer.fromJson<String?>(
        json['serverOwnershipStatus'],
      ),
      label: serializer.fromJson<String>(json['label']),
      isMain: serializer.fromJson<bool>(json['isMain']),
      lookupCharacterName: serializer.fromJson<String>(
        json['lookupCharacterName'],
      ),
      representativeCharacterId: serializer.fromJson<int?>(
        json['representativeCharacterId'],
      ),
      displayLimit: serializer.fromJson<int>(json['displayLimit']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverGameAccountId': serializer.toJson<String?>(serverGameAccountId),
      'serverOwnershipStatus': serializer.toJson<String?>(
        serverOwnershipStatus,
      ),
      'label': serializer.toJson<String>(label),
      'isMain': serializer.toJson<bool>(isMain),
      'lookupCharacterName': serializer.toJson<String>(lookupCharacterName),
      'representativeCharacterId': serializer.toJson<int?>(
        representativeCharacterId,
      ),
      'displayLimit': serializer.toJson<int>(displayLimit),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GameAccount copyWith({
    int? id,
    Value<String?> serverGameAccountId = const Value.absent(),
    Value<String?> serverOwnershipStatus = const Value.absent(),
    String? label,
    bool? isMain,
    String? lookupCharacterName,
    Value<int?> representativeCharacterId = const Value.absent(),
    int? displayLimit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GameAccount(
    id: id ?? this.id,
    serverGameAccountId: serverGameAccountId.present
        ? serverGameAccountId.value
        : this.serverGameAccountId,
    serverOwnershipStatus: serverOwnershipStatus.present
        ? serverOwnershipStatus.value
        : this.serverOwnershipStatus,
    label: label ?? this.label,
    isMain: isMain ?? this.isMain,
    lookupCharacterName: lookupCharacterName ?? this.lookupCharacterName,
    representativeCharacterId: representativeCharacterId.present
        ? representativeCharacterId.value
        : this.representativeCharacterId,
    displayLimit: displayLimit ?? this.displayLimit,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GameAccount copyWithCompanion(GameAccountsCompanion data) {
    return GameAccount(
      id: data.id.present ? data.id.value : this.id,
      serverGameAccountId: data.serverGameAccountId.present
          ? data.serverGameAccountId.value
          : this.serverGameAccountId,
      serverOwnershipStatus: data.serverOwnershipStatus.present
          ? data.serverOwnershipStatus.value
          : this.serverOwnershipStatus,
      label: data.label.present ? data.label.value : this.label,
      isMain: data.isMain.present ? data.isMain.value : this.isMain,
      lookupCharacterName: data.lookupCharacterName.present
          ? data.lookupCharacterName.value
          : this.lookupCharacterName,
      representativeCharacterId: data.representativeCharacterId.present
          ? data.representativeCharacterId.value
          : this.representativeCharacterId,
      displayLimit: data.displayLimit.present
          ? data.displayLimit.value
          : this.displayLimit,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameAccount(')
          ..write('id: $id, ')
          ..write('serverGameAccountId: $serverGameAccountId, ')
          ..write('serverOwnershipStatus: $serverOwnershipStatus, ')
          ..write('label: $label, ')
          ..write('isMain: $isMain, ')
          ..write('lookupCharacterName: $lookupCharacterName, ')
          ..write('representativeCharacterId: $representativeCharacterId, ')
          ..write('displayLimit: $displayLimit, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverGameAccountId,
    serverOwnershipStatus,
    label,
    isMain,
    lookupCharacterName,
    representativeCharacterId,
    displayLimit,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameAccount &&
          other.id == this.id &&
          other.serverGameAccountId == this.serverGameAccountId &&
          other.serverOwnershipStatus == this.serverOwnershipStatus &&
          other.label == this.label &&
          other.isMain == this.isMain &&
          other.lookupCharacterName == this.lookupCharacterName &&
          other.representativeCharacterId == this.representativeCharacterId &&
          other.displayLimit == this.displayLimit &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GameAccountsCompanion extends UpdateCompanion<GameAccount> {
  final Value<int> id;
  final Value<String?> serverGameAccountId;
  final Value<String?> serverOwnershipStatus;
  final Value<String> label;
  final Value<bool> isMain;
  final Value<String> lookupCharacterName;
  final Value<int?> representativeCharacterId;
  final Value<int> displayLimit;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const GameAccountsCompanion({
    this.id = const Value.absent(),
    this.serverGameAccountId = const Value.absent(),
    this.serverOwnershipStatus = const Value.absent(),
    this.label = const Value.absent(),
    this.isMain = const Value.absent(),
    this.lookupCharacterName = const Value.absent(),
    this.representativeCharacterId = const Value.absent(),
    this.displayLimit = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GameAccountsCompanion.insert({
    this.id = const Value.absent(),
    this.serverGameAccountId = const Value.absent(),
    this.serverOwnershipStatus = const Value.absent(),
    required String label,
    this.isMain = const Value.absent(),
    required String lookupCharacterName,
    this.representativeCharacterId = const Value.absent(),
    this.displayLimit = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : label = Value(label),
       lookupCharacterName = Value(lookupCharacterName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GameAccount> custom({
    Expression<int>? id,
    Expression<String>? serverGameAccountId,
    Expression<String>? serverOwnershipStatus,
    Expression<String>? label,
    Expression<bool>? isMain,
    Expression<String>? lookupCharacterName,
    Expression<int>? representativeCharacterId,
    Expression<int>? displayLimit,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverGameAccountId != null)
        'server_game_account_id': serverGameAccountId,
      if (serverOwnershipStatus != null)
        'server_ownership_status': serverOwnershipStatus,
      if (label != null) 'label': label,
      if (isMain != null) 'is_main': isMain,
      if (lookupCharacterName != null)
        'lookup_character_name': lookupCharacterName,
      if (representativeCharacterId != null)
        'representative_character_id': representativeCharacterId,
      if (displayLimit != null) 'display_limit': displayLimit,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GameAccountsCompanion copyWith({
    Value<int>? id,
    Value<String?>? serverGameAccountId,
    Value<String?>? serverOwnershipStatus,
    Value<String>? label,
    Value<bool>? isMain,
    Value<String>? lookupCharacterName,
    Value<int?>? representativeCharacterId,
    Value<int>? displayLimit,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return GameAccountsCompanion(
      id: id ?? this.id,
      serverGameAccountId: serverGameAccountId ?? this.serverGameAccountId,
      serverOwnershipStatus:
          serverOwnershipStatus ?? this.serverOwnershipStatus,
      label: label ?? this.label,
      isMain: isMain ?? this.isMain,
      lookupCharacterName: lookupCharacterName ?? this.lookupCharacterName,
      representativeCharacterId:
          representativeCharacterId ?? this.representativeCharacterId,
      displayLimit: displayLimit ?? this.displayLimit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverGameAccountId.present) {
      map['server_game_account_id'] = Variable<String>(
        serverGameAccountId.value,
      );
    }
    if (serverOwnershipStatus.present) {
      map['server_ownership_status'] = Variable<String>(
        serverOwnershipStatus.value,
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (isMain.present) {
      map['is_main'] = Variable<bool>(isMain.value);
    }
    if (lookupCharacterName.present) {
      map['lookup_character_name'] = Variable<String>(
        lookupCharacterName.value,
      );
    }
    if (representativeCharacterId.present) {
      map['representative_character_id'] = Variable<int>(
        representativeCharacterId.value,
      );
    }
    if (displayLimit.present) {
      map['display_limit'] = Variable<int>(displayLimit.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameAccountsCompanion(')
          ..write('id: $id, ')
          ..write('serverGameAccountId: $serverGameAccountId, ')
          ..write('serverOwnershipStatus: $serverOwnershipStatus, ')
          ..write('label: $label, ')
          ..write('isMain: $isMain, ')
          ..write('lookupCharacterName: $lookupCharacterName, ')
          ..write('representativeCharacterId: $representativeCharacterId, ')
          ..write('displayLimit: $displayLimit, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AccountCharactersTable extends AccountCharacters
    with TableInfo<$AccountCharactersTable, AccountCharacter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountCharactersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _serverCharacterIdMeta = const VerificationMeta(
    'serverCharacterId',
  );
  @override
  late final GeneratedColumn<String> serverCharacterId =
      GeneratedColumn<String>(
        'server_character_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES game_accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _serverNameMeta = const VerificationMeta(
    'serverName',
  );
  @override
  late final GeneratedColumn<String> serverName = GeneratedColumn<String>(
    'server_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characterNameMeta = const VerificationMeta(
    'characterName',
  );
  @override
  late final GeneratedColumn<String> characterName = GeneratedColumn<String>(
    'character_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characterLevelMeta = const VerificationMeta(
    'characterLevel',
  );
  @override
  late final GeneratedColumn<int> characterLevel = GeneratedColumn<int>(
    'character_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characterClassNameMeta =
      const VerificationMeta('characterClassName');
  @override
  late final GeneratedColumn<String> characterClassName =
      GeneratedColumn<String>(
        'character_class_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _itemLevelMeta = const VerificationMeta(
    'itemLevel',
  );
  @override
  late final GeneratedColumn<double> itemLevel = GeneratedColumn<double>(
    'item_level',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _combatPowerMeta = const VerificationMeta(
    'combatPower',
  );
  @override
  late final GeneratedColumn<double> combatPower = GeneratedColumn<double>(
    'combat_power',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isVisibleMeta = const VerificationMeta(
    'isVisible',
  );
  @override
  late final GeneratedColumn<bool> isVisible = GeneratedColumn<bool>(
    'is_visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_visible" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isRosterMissingMeta = const VerificationMeta(
    'isRosterMissing',
  );
  @override
  late final GeneratedColumn<bool> isRosterMissing = GeneratedColumn<bool>(
    'is_roster_missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_roster_missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferredRoleMeta = const VerificationMeta(
    'preferredRole',
  );
  @override
  late final GeneratedColumn<String> preferredRole = GeneratedColumn<String>(
    'preferred_role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSummaryFetchedAtMeta =
      const VerificationMeta('lastSummaryFetchedAt');
  @override
  late final GeneratedColumn<DateTime> lastSummaryFetchedAt =
      GeneratedColumn<DateTime>(
        'last_summary_fetched_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverCharacterId,
    accountId,
    serverName,
    characterName,
    characterLevel,
    characterClassName,
    itemLevel,
    combatPower,
    isVisible,
    isRosterMissing,
    displayOrder,
    preferredRole,
    lastSummaryFetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account_characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountCharacter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_character_id')) {
      context.handle(
        _serverCharacterIdMeta,
        serverCharacterId.isAcceptableOrUnknown(
          data['server_character_id']!,
          _serverCharacterIdMeta,
        ),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('server_name')) {
      context.handle(
        _serverNameMeta,
        serverName.isAcceptableOrUnknown(data['server_name']!, _serverNameMeta),
      );
    } else if (isInserting) {
      context.missing(_serverNameMeta);
    }
    if (data.containsKey('character_name')) {
      context.handle(
        _characterNameMeta,
        characterName.isAcceptableOrUnknown(
          data['character_name']!,
          _characterNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterNameMeta);
    }
    if (data.containsKey('character_level')) {
      context.handle(
        _characterLevelMeta,
        characterLevel.isAcceptableOrUnknown(
          data['character_level']!,
          _characterLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterLevelMeta);
    }
    if (data.containsKey('character_class_name')) {
      context.handle(
        _characterClassNameMeta,
        characterClassName.isAcceptableOrUnknown(
          data['character_class_name']!,
          _characterClassNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterClassNameMeta);
    }
    if (data.containsKey('item_level')) {
      context.handle(
        _itemLevelMeta,
        itemLevel.isAcceptableOrUnknown(data['item_level']!, _itemLevelMeta),
      );
    }
    if (data.containsKey('combat_power')) {
      context.handle(
        _combatPowerMeta,
        combatPower.isAcceptableOrUnknown(
          data['combat_power']!,
          _combatPowerMeta,
        ),
      );
    }
    if (data.containsKey('is_visible')) {
      context.handle(
        _isVisibleMeta,
        isVisible.isAcceptableOrUnknown(data['is_visible']!, _isVisibleMeta),
      );
    }
    if (data.containsKey('is_roster_missing')) {
      context.handle(
        _isRosterMissingMeta,
        isRosterMissing.isAcceptableOrUnknown(
          data['is_roster_missing']!,
          _isRosterMissingMeta,
        ),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    if (data.containsKey('preferred_role')) {
      context.handle(
        _preferredRoleMeta,
        preferredRole.isAcceptableOrUnknown(
          data['preferred_role']!,
          _preferredRoleMeta,
        ),
      );
    }
    if (data.containsKey('last_summary_fetched_at')) {
      context.handle(
        _lastSummaryFetchedAtMeta,
        lastSummaryFetchedAt.isAcceptableOrUnknown(
          data['last_summary_fetched_at']!,
          _lastSummaryFetchedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSummaryFetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountId, serverName, characterName},
  ];
  @override
  AccountCharacter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountCharacter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverCharacterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_character_id'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      serverName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_name'],
      )!,
      characterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_name'],
      )!,
      characterLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}character_level'],
      )!,
      characterClassName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_class_name'],
      )!,
      itemLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}item_level'],
      ),
      combatPower: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}combat_power'],
      ),
      isVisible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_visible'],
      )!,
      isRosterMissing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_roster_missing'],
      )!,
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      ),
      preferredRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_role'],
      ),
      lastSummaryFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_summary_fetched_at'],
      )!,
    );
  }

  @override
  $AccountCharactersTable createAlias(String alias) {
    return $AccountCharactersTable(attachedDatabase, alias);
  }
}

class AccountCharacter extends DataClass
    implements Insertable<AccountCharacter> {
  final int id;
  final String? serverCharacterId;
  final int accountId;
  final String serverName;
  final String characterName;
  final int characterLevel;
  final String characterClassName;
  final double? itemLevel;
  final double? combatPower;
  final bool isVisible;
  final bool isRosterMissing;
  final int? displayOrder;
  final String? preferredRole;
  final DateTime lastSummaryFetchedAt;
  const AccountCharacter({
    required this.id,
    this.serverCharacterId,
    required this.accountId,
    required this.serverName,
    required this.characterName,
    required this.characterLevel,
    required this.characterClassName,
    this.itemLevel,
    this.combatPower,
    required this.isVisible,
    required this.isRosterMissing,
    this.displayOrder,
    this.preferredRole,
    required this.lastSummaryFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverCharacterId != null) {
      map['server_character_id'] = Variable<String>(serverCharacterId);
    }
    map['account_id'] = Variable<int>(accountId);
    map['server_name'] = Variable<String>(serverName);
    map['character_name'] = Variable<String>(characterName);
    map['character_level'] = Variable<int>(characterLevel);
    map['character_class_name'] = Variable<String>(characterClassName);
    if (!nullToAbsent || itemLevel != null) {
      map['item_level'] = Variable<double>(itemLevel);
    }
    if (!nullToAbsent || combatPower != null) {
      map['combat_power'] = Variable<double>(combatPower);
    }
    map['is_visible'] = Variable<bool>(isVisible);
    map['is_roster_missing'] = Variable<bool>(isRosterMissing);
    if (!nullToAbsent || displayOrder != null) {
      map['display_order'] = Variable<int>(displayOrder);
    }
    if (!nullToAbsent || preferredRole != null) {
      map['preferred_role'] = Variable<String>(preferredRole);
    }
    map['last_summary_fetched_at'] = Variable<DateTime>(lastSummaryFetchedAt);
    return map;
  }

  AccountCharactersCompanion toCompanion(bool nullToAbsent) {
    return AccountCharactersCompanion(
      id: Value(id),
      serverCharacterId: serverCharacterId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverCharacterId),
      accountId: Value(accountId),
      serverName: Value(serverName),
      characterName: Value(characterName),
      characterLevel: Value(characterLevel),
      characterClassName: Value(characterClassName),
      itemLevel: itemLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(itemLevel),
      combatPower: combatPower == null && nullToAbsent
          ? const Value.absent()
          : Value(combatPower),
      isVisible: Value(isVisible),
      isRosterMissing: Value(isRosterMissing),
      displayOrder: displayOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(displayOrder),
      preferredRole: preferredRole == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredRole),
      lastSummaryFetchedAt: Value(lastSummaryFetchedAt),
    );
  }

  factory AccountCharacter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountCharacter(
      id: serializer.fromJson<int>(json['id']),
      serverCharacterId: serializer.fromJson<String?>(
        json['serverCharacterId'],
      ),
      accountId: serializer.fromJson<int>(json['accountId']),
      serverName: serializer.fromJson<String>(json['serverName']),
      characterName: serializer.fromJson<String>(json['characterName']),
      characterLevel: serializer.fromJson<int>(json['characterLevel']),
      characterClassName: serializer.fromJson<String>(
        json['characterClassName'],
      ),
      itemLevel: serializer.fromJson<double?>(json['itemLevel']),
      combatPower: serializer.fromJson<double?>(json['combatPower']),
      isVisible: serializer.fromJson<bool>(json['isVisible']),
      isRosterMissing: serializer.fromJson<bool>(json['isRosterMissing']),
      displayOrder: serializer.fromJson<int?>(json['displayOrder']),
      preferredRole: serializer.fromJson<String?>(json['preferredRole']),
      lastSummaryFetchedAt: serializer.fromJson<DateTime>(
        json['lastSummaryFetchedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverCharacterId': serializer.toJson<String?>(serverCharacterId),
      'accountId': serializer.toJson<int>(accountId),
      'serverName': serializer.toJson<String>(serverName),
      'characterName': serializer.toJson<String>(characterName),
      'characterLevel': serializer.toJson<int>(characterLevel),
      'characterClassName': serializer.toJson<String>(characterClassName),
      'itemLevel': serializer.toJson<double?>(itemLevel),
      'combatPower': serializer.toJson<double?>(combatPower),
      'isVisible': serializer.toJson<bool>(isVisible),
      'isRosterMissing': serializer.toJson<bool>(isRosterMissing),
      'displayOrder': serializer.toJson<int?>(displayOrder),
      'preferredRole': serializer.toJson<String?>(preferredRole),
      'lastSummaryFetchedAt': serializer.toJson<DateTime>(lastSummaryFetchedAt),
    };
  }

  AccountCharacter copyWith({
    int? id,
    Value<String?> serverCharacterId = const Value.absent(),
    int? accountId,
    String? serverName,
    String? characterName,
    int? characterLevel,
    String? characterClassName,
    Value<double?> itemLevel = const Value.absent(),
    Value<double?> combatPower = const Value.absent(),
    bool? isVisible,
    bool? isRosterMissing,
    Value<int?> displayOrder = const Value.absent(),
    Value<String?> preferredRole = const Value.absent(),
    DateTime? lastSummaryFetchedAt,
  }) => AccountCharacter(
    id: id ?? this.id,
    serverCharacterId: serverCharacterId.present
        ? serverCharacterId.value
        : this.serverCharacterId,
    accountId: accountId ?? this.accountId,
    serverName: serverName ?? this.serverName,
    characterName: characterName ?? this.characterName,
    characterLevel: characterLevel ?? this.characterLevel,
    characterClassName: characterClassName ?? this.characterClassName,
    itemLevel: itemLevel.present ? itemLevel.value : this.itemLevel,
    combatPower: combatPower.present ? combatPower.value : this.combatPower,
    isVisible: isVisible ?? this.isVisible,
    isRosterMissing: isRosterMissing ?? this.isRosterMissing,
    displayOrder: displayOrder.present ? displayOrder.value : this.displayOrder,
    preferredRole: preferredRole.present
        ? preferredRole.value
        : this.preferredRole,
    lastSummaryFetchedAt: lastSummaryFetchedAt ?? this.lastSummaryFetchedAt,
  );
  AccountCharacter copyWithCompanion(AccountCharactersCompanion data) {
    return AccountCharacter(
      id: data.id.present ? data.id.value : this.id,
      serverCharacterId: data.serverCharacterId.present
          ? data.serverCharacterId.value
          : this.serverCharacterId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      serverName: data.serverName.present
          ? data.serverName.value
          : this.serverName,
      characterName: data.characterName.present
          ? data.characterName.value
          : this.characterName,
      characterLevel: data.characterLevel.present
          ? data.characterLevel.value
          : this.characterLevel,
      characterClassName: data.characterClassName.present
          ? data.characterClassName.value
          : this.characterClassName,
      itemLevel: data.itemLevel.present ? data.itemLevel.value : this.itemLevel,
      combatPower: data.combatPower.present
          ? data.combatPower.value
          : this.combatPower,
      isVisible: data.isVisible.present ? data.isVisible.value : this.isVisible,
      isRosterMissing: data.isRosterMissing.present
          ? data.isRosterMissing.value
          : this.isRosterMissing,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      preferredRole: data.preferredRole.present
          ? data.preferredRole.value
          : this.preferredRole,
      lastSummaryFetchedAt: data.lastSummaryFetchedAt.present
          ? data.lastSummaryFetchedAt.value
          : this.lastSummaryFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountCharacter(')
          ..write('id: $id, ')
          ..write('serverCharacterId: $serverCharacterId, ')
          ..write('accountId: $accountId, ')
          ..write('serverName: $serverName, ')
          ..write('characterName: $characterName, ')
          ..write('characterLevel: $characterLevel, ')
          ..write('characterClassName: $characterClassName, ')
          ..write('itemLevel: $itemLevel, ')
          ..write('combatPower: $combatPower, ')
          ..write('isVisible: $isVisible, ')
          ..write('isRosterMissing: $isRosterMissing, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('preferredRole: $preferredRole, ')
          ..write('lastSummaryFetchedAt: $lastSummaryFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverCharacterId,
    accountId,
    serverName,
    characterName,
    characterLevel,
    characterClassName,
    itemLevel,
    combatPower,
    isVisible,
    isRosterMissing,
    displayOrder,
    preferredRole,
    lastSummaryFetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountCharacter &&
          other.id == this.id &&
          other.serverCharacterId == this.serverCharacterId &&
          other.accountId == this.accountId &&
          other.serverName == this.serverName &&
          other.characterName == this.characterName &&
          other.characterLevel == this.characterLevel &&
          other.characterClassName == this.characterClassName &&
          other.itemLevel == this.itemLevel &&
          other.combatPower == this.combatPower &&
          other.isVisible == this.isVisible &&
          other.isRosterMissing == this.isRosterMissing &&
          other.displayOrder == this.displayOrder &&
          other.preferredRole == this.preferredRole &&
          other.lastSummaryFetchedAt == this.lastSummaryFetchedAt);
}

class AccountCharactersCompanion extends UpdateCompanion<AccountCharacter> {
  final Value<int> id;
  final Value<String?> serverCharacterId;
  final Value<int> accountId;
  final Value<String> serverName;
  final Value<String> characterName;
  final Value<int> characterLevel;
  final Value<String> characterClassName;
  final Value<double?> itemLevel;
  final Value<double?> combatPower;
  final Value<bool> isVisible;
  final Value<bool> isRosterMissing;
  final Value<int?> displayOrder;
  final Value<String?> preferredRole;
  final Value<DateTime> lastSummaryFetchedAt;
  const AccountCharactersCompanion({
    this.id = const Value.absent(),
    this.serverCharacterId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.serverName = const Value.absent(),
    this.characterName = const Value.absent(),
    this.characterLevel = const Value.absent(),
    this.characterClassName = const Value.absent(),
    this.itemLevel = const Value.absent(),
    this.combatPower = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.isRosterMissing = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.preferredRole = const Value.absent(),
    this.lastSummaryFetchedAt = const Value.absent(),
  });
  AccountCharactersCompanion.insert({
    this.id = const Value.absent(),
    this.serverCharacterId = const Value.absent(),
    required int accountId,
    required String serverName,
    required String characterName,
    required int characterLevel,
    required String characterClassName,
    this.itemLevel = const Value.absent(),
    this.combatPower = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.isRosterMissing = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.preferredRole = const Value.absent(),
    required DateTime lastSummaryFetchedAt,
  }) : accountId = Value(accountId),
       serverName = Value(serverName),
       characterName = Value(characterName),
       characterLevel = Value(characterLevel),
       characterClassName = Value(characterClassName),
       lastSummaryFetchedAt = Value(lastSummaryFetchedAt);
  static Insertable<AccountCharacter> custom({
    Expression<int>? id,
    Expression<String>? serverCharacterId,
    Expression<int>? accountId,
    Expression<String>? serverName,
    Expression<String>? characterName,
    Expression<int>? characterLevel,
    Expression<String>? characterClassName,
    Expression<double>? itemLevel,
    Expression<double>? combatPower,
    Expression<bool>? isVisible,
    Expression<bool>? isRosterMissing,
    Expression<int>? displayOrder,
    Expression<String>? preferredRole,
    Expression<DateTime>? lastSummaryFetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverCharacterId != null) 'server_character_id': serverCharacterId,
      if (accountId != null) 'account_id': accountId,
      if (serverName != null) 'server_name': serverName,
      if (characterName != null) 'character_name': characterName,
      if (characterLevel != null) 'character_level': characterLevel,
      if (characterClassName != null)
        'character_class_name': characterClassName,
      if (itemLevel != null) 'item_level': itemLevel,
      if (combatPower != null) 'combat_power': combatPower,
      if (isVisible != null) 'is_visible': isVisible,
      if (isRosterMissing != null) 'is_roster_missing': isRosterMissing,
      if (displayOrder != null) 'display_order': displayOrder,
      if (preferredRole != null) 'preferred_role': preferredRole,
      if (lastSummaryFetchedAt != null)
        'last_summary_fetched_at': lastSummaryFetchedAt,
    });
  }

  AccountCharactersCompanion copyWith({
    Value<int>? id,
    Value<String?>? serverCharacterId,
    Value<int>? accountId,
    Value<String>? serverName,
    Value<String>? characterName,
    Value<int>? characterLevel,
    Value<String>? characterClassName,
    Value<double?>? itemLevel,
    Value<double?>? combatPower,
    Value<bool>? isVisible,
    Value<bool>? isRosterMissing,
    Value<int?>? displayOrder,
    Value<String?>? preferredRole,
    Value<DateTime>? lastSummaryFetchedAt,
  }) {
    return AccountCharactersCompanion(
      id: id ?? this.id,
      serverCharacterId: serverCharacterId ?? this.serverCharacterId,
      accountId: accountId ?? this.accountId,
      serverName: serverName ?? this.serverName,
      characterName: characterName ?? this.characterName,
      characterLevel: characterLevel ?? this.characterLevel,
      characterClassName: characterClassName ?? this.characterClassName,
      itemLevel: itemLevel ?? this.itemLevel,
      combatPower: combatPower ?? this.combatPower,
      isVisible: isVisible ?? this.isVisible,
      isRosterMissing: isRosterMissing ?? this.isRosterMissing,
      displayOrder: displayOrder ?? this.displayOrder,
      preferredRole: preferredRole ?? this.preferredRole,
      lastSummaryFetchedAt: lastSummaryFetchedAt ?? this.lastSummaryFetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverCharacterId.present) {
      map['server_character_id'] = Variable<String>(serverCharacterId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (serverName.present) {
      map['server_name'] = Variable<String>(serverName.value);
    }
    if (characterName.present) {
      map['character_name'] = Variable<String>(characterName.value);
    }
    if (characterLevel.present) {
      map['character_level'] = Variable<int>(characterLevel.value);
    }
    if (characterClassName.present) {
      map['character_class_name'] = Variable<String>(characterClassName.value);
    }
    if (itemLevel.present) {
      map['item_level'] = Variable<double>(itemLevel.value);
    }
    if (combatPower.present) {
      map['combat_power'] = Variable<double>(combatPower.value);
    }
    if (isVisible.present) {
      map['is_visible'] = Variable<bool>(isVisible.value);
    }
    if (isRosterMissing.present) {
      map['is_roster_missing'] = Variable<bool>(isRosterMissing.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (preferredRole.present) {
      map['preferred_role'] = Variable<String>(preferredRole.value);
    }
    if (lastSummaryFetchedAt.present) {
      map['last_summary_fetched_at'] = Variable<DateTime>(
        lastSummaryFetchedAt.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountCharactersCompanion(')
          ..write('id: $id, ')
          ..write('serverCharacterId: $serverCharacterId, ')
          ..write('accountId: $accountId, ')
          ..write('serverName: $serverName, ')
          ..write('characterName: $characterName, ')
          ..write('characterLevel: $characterLevel, ')
          ..write('characterClassName: $characterClassName, ')
          ..write('itemLevel: $itemLevel, ')
          ..write('combatPower: $combatPower, ')
          ..write('isVisible: $isVisible, ')
          ..write('isRosterMissing: $isRosterMissing, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('preferredRole: $preferredRole, ')
          ..write('lastSummaryFetchedAt: $lastSummaryFetchedAt')
          ..write(')'))
        .toString();
  }
}

class $CharacterBuildSnapshotsTable extends CharacterBuildSnapshots
    with TableInfo<$CharacterBuildSnapshotsTable, CharacterBuildSnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharacterBuildSnapshotsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES account_characters (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemLevelMeta = const VerificationMeta(
    'itemLevel',
  );
  @override
  late final GeneratedColumn<double> itemLevel = GeneratedColumn<double>(
    'item_level',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _combatPowerMeta = const VerificationMeta(
    'combatPower',
  );
  @override
  late final GeneratedColumn<double> combatPower = GeneratedColumn<double>(
    'combat_power',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataVersionMeta = const VerificationMeta(
    'dataVersion',
  );
  @override
  late final GeneratedColumn<int> dataVersion = GeneratedColumn<int>(
    'data_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    characterId,
    role,
    rawJson,
    itemLevel,
    combatPower,
    capturedAt,
    dataVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'character_build_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<CharacterBuildSnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('item_level')) {
      context.handle(
        _itemLevelMeta,
        itemLevel.isAcceptableOrUnknown(data['item_level']!, _itemLevelMeta),
      );
    }
    if (data.containsKey('combat_power')) {
      context.handle(
        _combatPowerMeta,
        combatPower.isAcceptableOrUnknown(
          data['combat_power']!,
          _combatPowerMeta,
        ),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('data_version')) {
      context.handle(
        _dataVersionMeta,
        dataVersion.isAcceptableOrUnknown(
          data['data_version']!,
          _dataVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {characterId, role},
  ];
  @override
  CharacterBuildSnapshotRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CharacterBuildSnapshotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}character_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      itemLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}item_level'],
      ),
      combatPower: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}combat_power'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      dataVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_version'],
      )!,
    );
  }

  @override
  $CharacterBuildSnapshotsTable createAlias(String alias) {
    return $CharacterBuildSnapshotsTable(attachedDatabase, alias);
  }
}

class CharacterBuildSnapshotRow extends DataClass
    implements Insertable<CharacterBuildSnapshotRow> {
  final int id;
  final int characterId;
  final String role;
  final String rawJson;
  final double? itemLevel;
  final double? combatPower;
  final DateTime capturedAt;
  final int dataVersion;
  const CharacterBuildSnapshotRow({
    required this.id,
    required this.characterId,
    required this.role,
    required this.rawJson,
    this.itemLevel,
    this.combatPower,
    required this.capturedAt,
    required this.dataVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['character_id'] = Variable<int>(characterId);
    map['role'] = Variable<String>(role);
    map['raw_json'] = Variable<String>(rawJson);
    if (!nullToAbsent || itemLevel != null) {
      map['item_level'] = Variable<double>(itemLevel);
    }
    if (!nullToAbsent || combatPower != null) {
      map['combat_power'] = Variable<double>(combatPower);
    }
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['data_version'] = Variable<int>(dataVersion);
    return map;
  }

  CharacterBuildSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return CharacterBuildSnapshotsCompanion(
      id: Value(id),
      characterId: Value(characterId),
      role: Value(role),
      rawJson: Value(rawJson),
      itemLevel: itemLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(itemLevel),
      combatPower: combatPower == null && nullToAbsent
          ? const Value.absent()
          : Value(combatPower),
      capturedAt: Value(capturedAt),
      dataVersion: Value(dataVersion),
    );
  }

  factory CharacterBuildSnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CharacterBuildSnapshotRow(
      id: serializer.fromJson<int>(json['id']),
      characterId: serializer.fromJson<int>(json['characterId']),
      role: serializer.fromJson<String>(json['role']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      itemLevel: serializer.fromJson<double?>(json['itemLevel']),
      combatPower: serializer.fromJson<double?>(json['combatPower']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      dataVersion: serializer.fromJson<int>(json['dataVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'characterId': serializer.toJson<int>(characterId),
      'role': serializer.toJson<String>(role),
      'rawJson': serializer.toJson<String>(rawJson),
      'itemLevel': serializer.toJson<double?>(itemLevel),
      'combatPower': serializer.toJson<double?>(combatPower),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'dataVersion': serializer.toJson<int>(dataVersion),
    };
  }

  CharacterBuildSnapshotRow copyWith({
    int? id,
    int? characterId,
    String? role,
    String? rawJson,
    Value<double?> itemLevel = const Value.absent(),
    Value<double?> combatPower = const Value.absent(),
    DateTime? capturedAt,
    int? dataVersion,
  }) => CharacterBuildSnapshotRow(
    id: id ?? this.id,
    characterId: characterId ?? this.characterId,
    role: role ?? this.role,
    rawJson: rawJson ?? this.rawJson,
    itemLevel: itemLevel.present ? itemLevel.value : this.itemLevel,
    combatPower: combatPower.present ? combatPower.value : this.combatPower,
    capturedAt: capturedAt ?? this.capturedAt,
    dataVersion: dataVersion ?? this.dataVersion,
  );
  CharacterBuildSnapshotRow copyWithCompanion(
    CharacterBuildSnapshotsCompanion data,
  ) {
    return CharacterBuildSnapshotRow(
      id: data.id.present ? data.id.value : this.id,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      role: data.role.present ? data.role.value : this.role,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      itemLevel: data.itemLevel.present ? data.itemLevel.value : this.itemLevel,
      combatPower: data.combatPower.present
          ? data.combatPower.value
          : this.combatPower,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      dataVersion: data.dataVersion.present
          ? data.dataVersion.value
          : this.dataVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CharacterBuildSnapshotRow(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('role: $role, ')
          ..write('rawJson: $rawJson, ')
          ..write('itemLevel: $itemLevel, ')
          ..write('combatPower: $combatPower, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('dataVersion: $dataVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    characterId,
    role,
    rawJson,
    itemLevel,
    combatPower,
    capturedAt,
    dataVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CharacterBuildSnapshotRow &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.role == this.role &&
          other.rawJson == this.rawJson &&
          other.itemLevel == this.itemLevel &&
          other.combatPower == this.combatPower &&
          other.capturedAt == this.capturedAt &&
          other.dataVersion == this.dataVersion);
}

class CharacterBuildSnapshotsCompanion
    extends UpdateCompanion<CharacterBuildSnapshotRow> {
  final Value<int> id;
  final Value<int> characterId;
  final Value<String> role;
  final Value<String> rawJson;
  final Value<double?> itemLevel;
  final Value<double?> combatPower;
  final Value<DateTime> capturedAt;
  final Value<int> dataVersion;
  const CharacterBuildSnapshotsCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.role = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.itemLevel = const Value.absent(),
    this.combatPower = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.dataVersion = const Value.absent(),
  });
  CharacterBuildSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required int characterId,
    required String role,
    required String rawJson,
    this.itemLevel = const Value.absent(),
    this.combatPower = const Value.absent(),
    required DateTime capturedAt,
    this.dataVersion = const Value.absent(),
  }) : characterId = Value(characterId),
       role = Value(role),
       rawJson = Value(rawJson),
       capturedAt = Value(capturedAt);
  static Insertable<CharacterBuildSnapshotRow> custom({
    Expression<int>? id,
    Expression<int>? characterId,
    Expression<String>? role,
    Expression<String>? rawJson,
    Expression<double>? itemLevel,
    Expression<double>? combatPower,
    Expression<DateTime>? capturedAt,
    Expression<int>? dataVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (role != null) 'role': role,
      if (rawJson != null) 'raw_json': rawJson,
      if (itemLevel != null) 'item_level': itemLevel,
      if (combatPower != null) 'combat_power': combatPower,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (dataVersion != null) 'data_version': dataVersion,
    });
  }

  CharacterBuildSnapshotsCompanion copyWith({
    Value<int>? id,
    Value<int>? characterId,
    Value<String>? role,
    Value<String>? rawJson,
    Value<double?>? itemLevel,
    Value<double?>? combatPower,
    Value<DateTime>? capturedAt,
    Value<int>? dataVersion,
  }) {
    return CharacterBuildSnapshotsCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      role: role ?? this.role,
      rawJson: rawJson ?? this.rawJson,
      itemLevel: itemLevel ?? this.itemLevel,
      combatPower: combatPower ?? this.combatPower,
      capturedAt: capturedAt ?? this.capturedAt,
      dataVersion: dataVersion ?? this.dataVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (itemLevel.present) {
      map['item_level'] = Variable<double>(itemLevel.value);
    }
    if (combatPower.present) {
      map['combat_power'] = Variable<double>(combatPower.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (dataVersion.present) {
      map['data_version'] = Variable<int>(dataVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharacterBuildSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('role: $role, ')
          ..write('rawJson: $rawJson, ')
          ..write('itemLevel: $itemLevel, ')
          ..write('combatPower: $combatPower, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('dataVersion: $dataVersion')
          ..write(')'))
        .toString();
  }
}

class $RaidHistoryEntriesTable extends RaidHistoryEntries
    with TableInfo<$RaidHistoryEntriesTable, RaidHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RaidHistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
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
  static const VerificationMeta _recruitmentIdMeta = const VerificationMeta(
    'recruitmentId',
  );
  @override
  late final GeneratedColumn<String> recruitmentId = GeneratedColumn<String>(
    'recruitment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _raidIdMeta = const VerificationMeta('raidId');
  @override
  late final GeneratedColumn<String> raidId = GeneratedColumn<String>(
    'raid_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyIdMeta = const VerificationMeta(
    'difficultyId',
  );
  @override
  late final GeneratedColumn<String> difficultyId = GeneratedColumn<String>(
    'difficulty_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cycleKeyMeta = const VerificationMeta(
    'cycleKey',
  );
  @override
  late final GeneratedColumn<String> cycleKey = GeneratedColumn<String>(
    'cycle_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverStatusMeta = const VerificationMeta(
    'serverStatus',
  );
  @override
  late final GeneratedColumn<String> serverStatus = GeneratedColumn<String>(
    'server_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localStatusOverrideMeta =
      const VerificationMeta('localStatusOverride');
  @override
  late final GeneratedColumn<String> localStatusOverride =
      GeneratedColumn<String>(
        'local_status_override',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('partyEvent'),
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('visible'),
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    playerId,
    characterId,
    recruitmentId,
    raidId,
    difficultyId,
    cycleKey,
    serverStatus,
    localStatusOverride,
    source,
    visibility,
    occurredAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'raid_history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RaidHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
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
    if (data.containsKey('recruitment_id')) {
      context.handle(
        _recruitmentIdMeta,
        recruitmentId.isAcceptableOrUnknown(
          data['recruitment_id']!,
          _recruitmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recruitmentIdMeta);
    }
    if (data.containsKey('raid_id')) {
      context.handle(
        _raidIdMeta,
        raidId.isAcceptableOrUnknown(data['raid_id']!, _raidIdMeta),
      );
    } else if (isInserting) {
      context.missing(_raidIdMeta);
    }
    if (data.containsKey('difficulty_id')) {
      context.handle(
        _difficultyIdMeta,
        difficultyId.isAcceptableOrUnknown(
          data['difficulty_id']!,
          _difficultyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_difficultyIdMeta);
    }
    if (data.containsKey('cycle_key')) {
      context.handle(
        _cycleKeyMeta,
        cycleKey.isAcceptableOrUnknown(data['cycle_key']!, _cycleKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleKeyMeta);
    }
    if (data.containsKey('server_status')) {
      context.handle(
        _serverStatusMeta,
        serverStatus.isAcceptableOrUnknown(
          data['server_status']!,
          _serverStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverStatusMeta);
    }
    if (data.containsKey('local_status_override')) {
      context.handle(
        _localStatusOverrideMeta,
        localStatusOverride.isAcceptableOrUnknown(
          data['local_status_override']!,
          _localStatusOverrideMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  RaidHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RaidHistoryEntry(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      recruitmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recruitment_id'],
      )!,
      raidId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raid_id'],
      )!,
      difficultyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty_id'],
      )!,
      cycleKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_key'],
      )!,
      serverStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_status'],
      )!,
      localStatusOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_status_override'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $RaidHistoryEntriesTable createAlias(String alias) {
    return $RaidHistoryEntriesTable(attachedDatabase, alias);
  }
}

class RaidHistoryEntry extends DataClass
    implements Insertable<RaidHistoryEntry> {
  final String eventId;
  final String playerId;
  final String characterId;
  final String recruitmentId;
  final String raidId;
  final String difficultyId;
  final String cycleKey;
  final String serverStatus;
  final String? localStatusOverride;
  final String source;
  final String visibility;
  final DateTime occurredAt;
  final DateTime syncedAt;
  const RaidHistoryEntry({
    required this.eventId,
    required this.playerId,
    required this.characterId,
    required this.recruitmentId,
    required this.raidId,
    required this.difficultyId,
    required this.cycleKey,
    required this.serverStatus,
    this.localStatusOverride,
    required this.source,
    required this.visibility,
    required this.occurredAt,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['player_id'] = Variable<String>(playerId);
    map['character_id'] = Variable<String>(characterId);
    map['recruitment_id'] = Variable<String>(recruitmentId);
    map['raid_id'] = Variable<String>(raidId);
    map['difficulty_id'] = Variable<String>(difficultyId);
    map['cycle_key'] = Variable<String>(cycleKey);
    map['server_status'] = Variable<String>(serverStatus);
    if (!nullToAbsent || localStatusOverride != null) {
      map['local_status_override'] = Variable<String>(localStatusOverride);
    }
    map['source'] = Variable<String>(source);
    map['visibility'] = Variable<String>(visibility);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  RaidHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return RaidHistoryEntriesCompanion(
      eventId: Value(eventId),
      playerId: Value(playerId),
      characterId: Value(characterId),
      recruitmentId: Value(recruitmentId),
      raidId: Value(raidId),
      difficultyId: Value(difficultyId),
      cycleKey: Value(cycleKey),
      serverStatus: Value(serverStatus),
      localStatusOverride: localStatusOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(localStatusOverride),
      source: Value(source),
      visibility: Value(visibility),
      occurredAt: Value(occurredAt),
      syncedAt: Value(syncedAt),
    );
  }

  factory RaidHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RaidHistoryEntry(
      eventId: serializer.fromJson<String>(json['eventId']),
      playerId: serializer.fromJson<String>(json['playerId']),
      characterId: serializer.fromJson<String>(json['characterId']),
      recruitmentId: serializer.fromJson<String>(json['recruitmentId']),
      raidId: serializer.fromJson<String>(json['raidId']),
      difficultyId: serializer.fromJson<String>(json['difficultyId']),
      cycleKey: serializer.fromJson<String>(json['cycleKey']),
      serverStatus: serializer.fromJson<String>(json['serverStatus']),
      localStatusOverride: serializer.fromJson<String?>(
        json['localStatusOverride'],
      ),
      source: serializer.fromJson<String>(json['source']),
      visibility: serializer.fromJson<String>(json['visibility']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'playerId': serializer.toJson<String>(playerId),
      'characterId': serializer.toJson<String>(characterId),
      'recruitmentId': serializer.toJson<String>(recruitmentId),
      'raidId': serializer.toJson<String>(raidId),
      'difficultyId': serializer.toJson<String>(difficultyId),
      'cycleKey': serializer.toJson<String>(cycleKey),
      'serverStatus': serializer.toJson<String>(serverStatus),
      'localStatusOverride': serializer.toJson<String?>(localStatusOverride),
      'source': serializer.toJson<String>(source),
      'visibility': serializer.toJson<String>(visibility),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  RaidHistoryEntry copyWith({
    String? eventId,
    String? playerId,
    String? characterId,
    String? recruitmentId,
    String? raidId,
    String? difficultyId,
    String? cycleKey,
    String? serverStatus,
    Value<String?> localStatusOverride = const Value.absent(),
    String? source,
    String? visibility,
    DateTime? occurredAt,
    DateTime? syncedAt,
  }) => RaidHistoryEntry(
    eventId: eventId ?? this.eventId,
    playerId: playerId ?? this.playerId,
    characterId: characterId ?? this.characterId,
    recruitmentId: recruitmentId ?? this.recruitmentId,
    raidId: raidId ?? this.raidId,
    difficultyId: difficultyId ?? this.difficultyId,
    cycleKey: cycleKey ?? this.cycleKey,
    serverStatus: serverStatus ?? this.serverStatus,
    localStatusOverride: localStatusOverride.present
        ? localStatusOverride.value
        : this.localStatusOverride,
    source: source ?? this.source,
    visibility: visibility ?? this.visibility,
    occurredAt: occurredAt ?? this.occurredAt,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  RaidHistoryEntry copyWithCompanion(RaidHistoryEntriesCompanion data) {
    return RaidHistoryEntry(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      recruitmentId: data.recruitmentId.present
          ? data.recruitmentId.value
          : this.recruitmentId,
      raidId: data.raidId.present ? data.raidId.value : this.raidId,
      difficultyId: data.difficultyId.present
          ? data.difficultyId.value
          : this.difficultyId,
      cycleKey: data.cycleKey.present ? data.cycleKey.value : this.cycleKey,
      serverStatus: data.serverStatus.present
          ? data.serverStatus.value
          : this.serverStatus,
      localStatusOverride: data.localStatusOverride.present
          ? data.localStatusOverride.value
          : this.localStatusOverride,
      source: data.source.present ? data.source.value : this.source,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RaidHistoryEntry(')
          ..write('eventId: $eventId, ')
          ..write('playerId: $playerId, ')
          ..write('characterId: $characterId, ')
          ..write('recruitmentId: $recruitmentId, ')
          ..write('raidId: $raidId, ')
          ..write('difficultyId: $difficultyId, ')
          ..write('cycleKey: $cycleKey, ')
          ..write('serverStatus: $serverStatus, ')
          ..write('localStatusOverride: $localStatusOverride, ')
          ..write('source: $source, ')
          ..write('visibility: $visibility, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    playerId,
    characterId,
    recruitmentId,
    raidId,
    difficultyId,
    cycleKey,
    serverStatus,
    localStatusOverride,
    source,
    visibility,
    occurredAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RaidHistoryEntry &&
          other.eventId == this.eventId &&
          other.playerId == this.playerId &&
          other.characterId == this.characterId &&
          other.recruitmentId == this.recruitmentId &&
          other.raidId == this.raidId &&
          other.difficultyId == this.difficultyId &&
          other.cycleKey == this.cycleKey &&
          other.serverStatus == this.serverStatus &&
          other.localStatusOverride == this.localStatusOverride &&
          other.source == this.source &&
          other.visibility == this.visibility &&
          other.occurredAt == this.occurredAt &&
          other.syncedAt == this.syncedAt);
}

class RaidHistoryEntriesCompanion extends UpdateCompanion<RaidHistoryEntry> {
  final Value<String> eventId;
  final Value<String> playerId;
  final Value<String> characterId;
  final Value<String> recruitmentId;
  final Value<String> raidId;
  final Value<String> difficultyId;
  final Value<String> cycleKey;
  final Value<String> serverStatus;
  final Value<String?> localStatusOverride;
  final Value<String> source;
  final Value<String> visibility;
  final Value<DateTime> occurredAt;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const RaidHistoryEntriesCompanion({
    this.eventId = const Value.absent(),
    this.playerId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.recruitmentId = const Value.absent(),
    this.raidId = const Value.absent(),
    this.difficultyId = const Value.absent(),
    this.cycleKey = const Value.absent(),
    this.serverStatus = const Value.absent(),
    this.localStatusOverride = const Value.absent(),
    this.source = const Value.absent(),
    this.visibility = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RaidHistoryEntriesCompanion.insert({
    required String eventId,
    required String playerId,
    required String characterId,
    required String recruitmentId,
    required String raidId,
    required String difficultyId,
    required String cycleKey,
    required String serverStatus,
    this.localStatusOverride = const Value.absent(),
    this.source = const Value.absent(),
    this.visibility = const Value.absent(),
    required DateTime occurredAt,
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       playerId = Value(playerId),
       characterId = Value(characterId),
       recruitmentId = Value(recruitmentId),
       raidId = Value(raidId),
       difficultyId = Value(difficultyId),
       cycleKey = Value(cycleKey),
       serverStatus = Value(serverStatus),
       occurredAt = Value(occurredAt),
       syncedAt = Value(syncedAt);
  static Insertable<RaidHistoryEntry> custom({
    Expression<String>? eventId,
    Expression<String>? playerId,
    Expression<String>? characterId,
    Expression<String>? recruitmentId,
    Expression<String>? raidId,
    Expression<String>? difficultyId,
    Expression<String>? cycleKey,
    Expression<String>? serverStatus,
    Expression<String>? localStatusOverride,
    Expression<String>? source,
    Expression<String>? visibility,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (playerId != null) 'player_id': playerId,
      if (characterId != null) 'character_id': characterId,
      if (recruitmentId != null) 'recruitment_id': recruitmentId,
      if (raidId != null) 'raid_id': raidId,
      if (difficultyId != null) 'difficulty_id': difficultyId,
      if (cycleKey != null) 'cycle_key': cycleKey,
      if (serverStatus != null) 'server_status': serverStatus,
      if (localStatusOverride != null)
        'local_status_override': localStatusOverride,
      if (source != null) 'source': source,
      if (visibility != null) 'visibility': visibility,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RaidHistoryEntriesCompanion copyWith({
    Value<String>? eventId,
    Value<String>? playerId,
    Value<String>? characterId,
    Value<String>? recruitmentId,
    Value<String>? raidId,
    Value<String>? difficultyId,
    Value<String>? cycleKey,
    Value<String>? serverStatus,
    Value<String?>? localStatusOverride,
    Value<String>? source,
    Value<String>? visibility,
    Value<DateTime>? occurredAt,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return RaidHistoryEntriesCompanion(
      eventId: eventId ?? this.eventId,
      playerId: playerId ?? this.playerId,
      characterId: characterId ?? this.characterId,
      recruitmentId: recruitmentId ?? this.recruitmentId,
      raidId: raidId ?? this.raidId,
      difficultyId: difficultyId ?? this.difficultyId,
      cycleKey: cycleKey ?? this.cycleKey,
      serverStatus: serverStatus ?? this.serverStatus,
      localStatusOverride: localStatusOverride ?? this.localStatusOverride,
      source: source ?? this.source,
      visibility: visibility ?? this.visibility,
      occurredAt: occurredAt ?? this.occurredAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (recruitmentId.present) {
      map['recruitment_id'] = Variable<String>(recruitmentId.value);
    }
    if (raidId.present) {
      map['raid_id'] = Variable<String>(raidId.value);
    }
    if (difficultyId.present) {
      map['difficulty_id'] = Variable<String>(difficultyId.value);
    }
    if (cycleKey.present) {
      map['cycle_key'] = Variable<String>(cycleKey.value);
    }
    if (serverStatus.present) {
      map['server_status'] = Variable<String>(serverStatus.value);
    }
    if (localStatusOverride.present) {
      map['local_status_override'] = Variable<String>(
        localStatusOverride.value,
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RaidHistoryEntriesCompanion(')
          ..write('eventId: $eventId, ')
          ..write('playerId: $playerId, ')
          ..write('characterId: $characterId, ')
          ..write('recruitmentId: $recruitmentId, ')
          ..write('raidId: $raidId, ')
          ..write('difficultyId: $difficultyId, ')
          ..write('cycleKey: $cycleKey, ')
          ..write('serverStatus: $serverStatus, ')
          ..write('localStatusOverride: $localStatusOverride, ')
          ..write('source: $source, ')
          ..write('visibility: $visibility, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PartyNotificationReceiptsTable extends PartyNotificationReceipts
    with TableInfo<$PartyNotificationReceiptsTable, PartyNotificationReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartyNotificationReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recruitmentIdMeta = const VerificationMeta(
    'recruitmentId',
  );
  @override
  late final GeneratedColumn<String> recruitmentId = GeneratedColumn<String>(
    'recruitment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cycleKeyMeta = const VerificationMeta(
    'cycleKey',
  );
  @override
  late final GeneratedColumn<String> cycleKey = GeneratedColumn<String>(
    'cycle_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _raidIdMeta = const VerificationMeta('raidId');
  @override
  late final GeneratedColumn<String> raidId = GeneratedColumn<String>(
    'raid_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyIdMeta = const VerificationMeta(
    'difficultyId',
  );
  @override
  late final GeneratedColumn<String> difficultyId = GeneratedColumn<String>(
    'difficulty_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _characterNameSnapshotMeta =
      const VerificationMeta('characterNameSnapshot');
  @override
  late final GeneratedColumn<String> characterNameSnapshot =
      GeneratedColumn<String>(
        'character_name_snapshot',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstSyncedAtMeta = const VerificationMeta(
    'firstSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSyncedAt =
      GeneratedColumn<DateTime>(
        'first_synced_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    playerId,
    type,
    recruitmentId,
    cycleKey,
    raidId,
    difficultyId,
    characterNameSnapshot,
    occurredAt,
    expiresAt,
    readAt,
    firstSyncedAt,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'party_notification_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PartyNotificationReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('recruitment_id')) {
      context.handle(
        _recruitmentIdMeta,
        recruitmentId.isAcceptableOrUnknown(
          data['recruitment_id']!,
          _recruitmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recruitmentIdMeta);
    }
    if (data.containsKey('cycle_key')) {
      context.handle(
        _cycleKeyMeta,
        cycleKey.isAcceptableOrUnknown(data['cycle_key']!, _cycleKeyMeta),
      );
    }
    if (data.containsKey('raid_id')) {
      context.handle(
        _raidIdMeta,
        raidId.isAcceptableOrUnknown(data['raid_id']!, _raidIdMeta),
      );
    }
    if (data.containsKey('difficulty_id')) {
      context.handle(
        _difficultyIdMeta,
        difficultyId.isAcceptableOrUnknown(
          data['difficulty_id']!,
          _difficultyIdMeta,
        ),
      );
    }
    if (data.containsKey('character_name_snapshot')) {
      context.handle(
        _characterNameSnapshotMeta,
        characterNameSnapshot.isAcceptableOrUnknown(
          data['character_name_snapshot']!,
          _characterNameSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('first_synced_at')) {
      context.handle(
        _firstSyncedAtMeta,
        firstSyncedAt.isAcceptableOrUnknown(
          data['first_synced_at']!,
          _firstSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSyncedAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  PartyNotificationReceipt map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartyNotificationReceipt(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      recruitmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recruitment_id'],
      )!,
      cycleKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_key'],
      ),
      raidId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raid_id'],
      ),
      difficultyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty_id'],
      ),
      characterNameSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_name_snapshot'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      ),
      firstSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_synced_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $PartyNotificationReceiptsTable createAlias(String alias) {
    return $PartyNotificationReceiptsTable(attachedDatabase, alias);
  }
}

class PartyNotificationReceipt extends DataClass
    implements Insertable<PartyNotificationReceipt> {
  final String eventId;
  final String playerId;
  final String type;
  final String recruitmentId;
  final String? cycleKey;
  final String? raidId;
  final String? difficultyId;
  final String? characterNameSnapshot;
  final DateTime occurredAt;
  final DateTime expiresAt;
  final DateTime? readAt;
  final DateTime firstSyncedAt;
  final DateTime lastSyncedAt;
  const PartyNotificationReceipt({
    required this.eventId,
    required this.playerId,
    required this.type,
    required this.recruitmentId,
    this.cycleKey,
    this.raidId,
    this.difficultyId,
    this.characterNameSnapshot,
    required this.occurredAt,
    required this.expiresAt,
    this.readAt,
    required this.firstSyncedAt,
    required this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['player_id'] = Variable<String>(playerId);
    map['type'] = Variable<String>(type);
    map['recruitment_id'] = Variable<String>(recruitmentId);
    if (!nullToAbsent || cycleKey != null) {
      map['cycle_key'] = Variable<String>(cycleKey);
    }
    if (!nullToAbsent || raidId != null) {
      map['raid_id'] = Variable<String>(raidId);
    }
    if (!nullToAbsent || difficultyId != null) {
      map['difficulty_id'] = Variable<String>(difficultyId);
    }
    if (!nullToAbsent || characterNameSnapshot != null) {
      map['character_name_snapshot'] = Variable<String>(characterNameSnapshot);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    map['first_synced_at'] = Variable<DateTime>(firstSyncedAt);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  PartyNotificationReceiptsCompanion toCompanion(bool nullToAbsent) {
    return PartyNotificationReceiptsCompanion(
      eventId: Value(eventId),
      playerId: Value(playerId),
      type: Value(type),
      recruitmentId: Value(recruitmentId),
      cycleKey: cycleKey == null && nullToAbsent
          ? const Value.absent()
          : Value(cycleKey),
      raidId: raidId == null && nullToAbsent
          ? const Value.absent()
          : Value(raidId),
      difficultyId: difficultyId == null && nullToAbsent
          ? const Value.absent()
          : Value(difficultyId),
      characterNameSnapshot: characterNameSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(characterNameSnapshot),
      occurredAt: Value(occurredAt),
      expiresAt: Value(expiresAt),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      firstSyncedAt: Value(firstSyncedAt),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory PartyNotificationReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartyNotificationReceipt(
      eventId: serializer.fromJson<String>(json['eventId']),
      playerId: serializer.fromJson<String>(json['playerId']),
      type: serializer.fromJson<String>(json['type']),
      recruitmentId: serializer.fromJson<String>(json['recruitmentId']),
      cycleKey: serializer.fromJson<String?>(json['cycleKey']),
      raidId: serializer.fromJson<String?>(json['raidId']),
      difficultyId: serializer.fromJson<String?>(json['difficultyId']),
      characterNameSnapshot: serializer.fromJson<String?>(
        json['characterNameSnapshot'],
      ),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
      firstSyncedAt: serializer.fromJson<DateTime>(json['firstSyncedAt']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'playerId': serializer.toJson<String>(playerId),
      'type': serializer.toJson<String>(type),
      'recruitmentId': serializer.toJson<String>(recruitmentId),
      'cycleKey': serializer.toJson<String?>(cycleKey),
      'raidId': serializer.toJson<String?>(raidId),
      'difficultyId': serializer.toJson<String?>(difficultyId),
      'characterNameSnapshot': serializer.toJson<String?>(
        characterNameSnapshot,
      ),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'readAt': serializer.toJson<DateTime?>(readAt),
      'firstSyncedAt': serializer.toJson<DateTime>(firstSyncedAt),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  PartyNotificationReceipt copyWith({
    String? eventId,
    String? playerId,
    String? type,
    String? recruitmentId,
    Value<String?> cycleKey = const Value.absent(),
    Value<String?> raidId = const Value.absent(),
    Value<String?> difficultyId = const Value.absent(),
    Value<String?> characterNameSnapshot = const Value.absent(),
    DateTime? occurredAt,
    DateTime? expiresAt,
    Value<DateTime?> readAt = const Value.absent(),
    DateTime? firstSyncedAt,
    DateTime? lastSyncedAt,
  }) => PartyNotificationReceipt(
    eventId: eventId ?? this.eventId,
    playerId: playerId ?? this.playerId,
    type: type ?? this.type,
    recruitmentId: recruitmentId ?? this.recruitmentId,
    cycleKey: cycleKey.present ? cycleKey.value : this.cycleKey,
    raidId: raidId.present ? raidId.value : this.raidId,
    difficultyId: difficultyId.present ? difficultyId.value : this.difficultyId,
    characterNameSnapshot: characterNameSnapshot.present
        ? characterNameSnapshot.value
        : this.characterNameSnapshot,
    occurredAt: occurredAt ?? this.occurredAt,
    expiresAt: expiresAt ?? this.expiresAt,
    readAt: readAt.present ? readAt.value : this.readAt,
    firstSyncedAt: firstSyncedAt ?? this.firstSyncedAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
  PartyNotificationReceipt copyWithCompanion(
    PartyNotificationReceiptsCompanion data,
  ) {
    return PartyNotificationReceipt(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      type: data.type.present ? data.type.value : this.type,
      recruitmentId: data.recruitmentId.present
          ? data.recruitmentId.value
          : this.recruitmentId,
      cycleKey: data.cycleKey.present ? data.cycleKey.value : this.cycleKey,
      raidId: data.raidId.present ? data.raidId.value : this.raidId,
      difficultyId: data.difficultyId.present
          ? data.difficultyId.value
          : this.difficultyId,
      characterNameSnapshot: data.characterNameSnapshot.present
          ? data.characterNameSnapshot.value
          : this.characterNameSnapshot,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      firstSyncedAt: data.firstSyncedAt.present
          ? data.firstSyncedAt.value
          : this.firstSyncedAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartyNotificationReceipt(')
          ..write('eventId: $eventId, ')
          ..write('playerId: $playerId, ')
          ..write('type: $type, ')
          ..write('recruitmentId: $recruitmentId, ')
          ..write('cycleKey: $cycleKey, ')
          ..write('raidId: $raidId, ')
          ..write('difficultyId: $difficultyId, ')
          ..write('characterNameSnapshot: $characterNameSnapshot, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('readAt: $readAt, ')
          ..write('firstSyncedAt: $firstSyncedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    playerId,
    type,
    recruitmentId,
    cycleKey,
    raidId,
    difficultyId,
    characterNameSnapshot,
    occurredAt,
    expiresAt,
    readAt,
    firstSyncedAt,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartyNotificationReceipt &&
          other.eventId == this.eventId &&
          other.playerId == this.playerId &&
          other.type == this.type &&
          other.recruitmentId == this.recruitmentId &&
          other.cycleKey == this.cycleKey &&
          other.raidId == this.raidId &&
          other.difficultyId == this.difficultyId &&
          other.characterNameSnapshot == this.characterNameSnapshot &&
          other.occurredAt == this.occurredAt &&
          other.expiresAt == this.expiresAt &&
          other.readAt == this.readAt &&
          other.firstSyncedAt == this.firstSyncedAt &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class PartyNotificationReceiptsCompanion
    extends UpdateCompanion<PartyNotificationReceipt> {
  final Value<String> eventId;
  final Value<String> playerId;
  final Value<String> type;
  final Value<String> recruitmentId;
  final Value<String?> cycleKey;
  final Value<String?> raidId;
  final Value<String?> difficultyId;
  final Value<String?> characterNameSnapshot;
  final Value<DateTime> occurredAt;
  final Value<DateTime> expiresAt;
  final Value<DateTime?> readAt;
  final Value<DateTime> firstSyncedAt;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const PartyNotificationReceiptsCompanion({
    this.eventId = const Value.absent(),
    this.playerId = const Value.absent(),
    this.type = const Value.absent(),
    this.recruitmentId = const Value.absent(),
    this.cycleKey = const Value.absent(),
    this.raidId = const Value.absent(),
    this.difficultyId = const Value.absent(),
    this.characterNameSnapshot = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.firstSyncedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartyNotificationReceiptsCompanion.insert({
    required String eventId,
    required String playerId,
    required String type,
    required String recruitmentId,
    this.cycleKey = const Value.absent(),
    this.raidId = const Value.absent(),
    this.difficultyId = const Value.absent(),
    this.characterNameSnapshot = const Value.absent(),
    required DateTime occurredAt,
    required DateTime expiresAt,
    this.readAt = const Value.absent(),
    required DateTime firstSyncedAt,
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       playerId = Value(playerId),
       type = Value(type),
       recruitmentId = Value(recruitmentId),
       occurredAt = Value(occurredAt),
       expiresAt = Value(expiresAt),
       firstSyncedAt = Value(firstSyncedAt),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<PartyNotificationReceipt> custom({
    Expression<String>? eventId,
    Expression<String>? playerId,
    Expression<String>? type,
    Expression<String>? recruitmentId,
    Expression<String>? cycleKey,
    Expression<String>? raidId,
    Expression<String>? difficultyId,
    Expression<String>? characterNameSnapshot,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? readAt,
    Expression<DateTime>? firstSyncedAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (playerId != null) 'player_id': playerId,
      if (type != null) 'type': type,
      if (recruitmentId != null) 'recruitment_id': recruitmentId,
      if (cycleKey != null) 'cycle_key': cycleKey,
      if (raidId != null) 'raid_id': raidId,
      if (difficultyId != null) 'difficulty_id': difficultyId,
      if (characterNameSnapshot != null)
        'character_name_snapshot': characterNameSnapshot,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (readAt != null) 'read_at': readAt,
      if (firstSyncedAt != null) 'first_synced_at': firstSyncedAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartyNotificationReceiptsCompanion copyWith({
    Value<String>? eventId,
    Value<String>? playerId,
    Value<String>? type,
    Value<String>? recruitmentId,
    Value<String?>? cycleKey,
    Value<String?>? raidId,
    Value<String?>? difficultyId,
    Value<String?>? characterNameSnapshot,
    Value<DateTime>? occurredAt,
    Value<DateTime>? expiresAt,
    Value<DateTime?>? readAt,
    Value<DateTime>? firstSyncedAt,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return PartyNotificationReceiptsCompanion(
      eventId: eventId ?? this.eventId,
      playerId: playerId ?? this.playerId,
      type: type ?? this.type,
      recruitmentId: recruitmentId ?? this.recruitmentId,
      cycleKey: cycleKey ?? this.cycleKey,
      raidId: raidId ?? this.raidId,
      difficultyId: difficultyId ?? this.difficultyId,
      characterNameSnapshot:
          characterNameSnapshot ?? this.characterNameSnapshot,
      occurredAt: occurredAt ?? this.occurredAt,
      expiresAt: expiresAt ?? this.expiresAt,
      readAt: readAt ?? this.readAt,
      firstSyncedAt: firstSyncedAt ?? this.firstSyncedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (recruitmentId.present) {
      map['recruitment_id'] = Variable<String>(recruitmentId.value);
    }
    if (cycleKey.present) {
      map['cycle_key'] = Variable<String>(cycleKey.value);
    }
    if (raidId.present) {
      map['raid_id'] = Variable<String>(raidId.value);
    }
    if (difficultyId.present) {
      map['difficulty_id'] = Variable<String>(difficultyId.value);
    }
    if (characterNameSnapshot.present) {
      map['character_name_snapshot'] = Variable<String>(
        characterNameSnapshot.value,
      );
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (firstSyncedAt.present) {
      map['first_synced_at'] = Variable<DateTime>(firstSyncedAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartyNotificationReceiptsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('playerId: $playerId, ')
          ..write('type: $type, ')
          ..write('recruitmentId: $recruitmentId, ')
          ..write('cycleKey: $cycleKey, ')
          ..write('raidId: $raidId, ')
          ..write('difficultyId: $difficultyId, ')
          ..write('characterNameSnapshot: $characterNameSnapshot, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('readAt: $readAt, ')
          ..write('firstSyncedAt: $firstSyncedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CharacterWeeklyRaidDisplaysTable extends CharacterWeeklyRaidDisplays
    with
        TableInfo<
          $CharacterWeeklyRaidDisplaysTable,
          CharacterWeeklyRaidDisplay
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharacterWeeklyRaidDisplaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES account_characters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _displayCountMeta = const VerificationMeta(
    'displayCount',
  );
  @override
  late final GeneratedColumn<int> displayCount = GeneratedColumn<int>(
    'display_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _raidIdsCsvMeta = const VerificationMeta(
    'raidIdsCsv',
  );
  @override
  late final GeneratedColumn<String> raidIdsCsv = GeneratedColumn<String>(
    'raid_ids_csv',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [characterId, displayCount, raidIdsCsv];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'character_weekly_raid_displays';
  @override
  VerificationContext validateIntegrity(
    Insertable<CharacterWeeklyRaidDisplay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    }
    if (data.containsKey('display_count')) {
      context.handle(
        _displayCountMeta,
        displayCount.isAcceptableOrUnknown(
          data['display_count']!,
          _displayCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayCountMeta);
    }
    if (data.containsKey('raid_ids_csv')) {
      context.handle(
        _raidIdsCsvMeta,
        raidIdsCsv.isAcceptableOrUnknown(
          data['raid_ids_csv']!,
          _raidIdsCsvMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_raidIdsCsvMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {characterId};
  @override
  CharacterWeeklyRaidDisplay map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CharacterWeeklyRaidDisplay(
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}character_id'],
      )!,
      displayCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_count'],
      )!,
      raidIdsCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raid_ids_csv'],
      )!,
    );
  }

  @override
  $CharacterWeeklyRaidDisplaysTable createAlias(String alias) {
    return $CharacterWeeklyRaidDisplaysTable(attachedDatabase, alias);
  }
}

class CharacterWeeklyRaidDisplay extends DataClass
    implements Insertable<CharacterWeeklyRaidDisplay> {
  final int characterId;
  final int displayCount;

  /// 표시 순서대로 쉼표 구분 raidId. displayCount == 0이면 빈 문자열.
  final String raidIdsCsv;
  const CharacterWeeklyRaidDisplay({
    required this.characterId,
    required this.displayCount,
    required this.raidIdsCsv,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['character_id'] = Variable<int>(characterId);
    map['display_count'] = Variable<int>(displayCount);
    map['raid_ids_csv'] = Variable<String>(raidIdsCsv);
    return map;
  }

  CharacterWeeklyRaidDisplaysCompanion toCompanion(bool nullToAbsent) {
    return CharacterWeeklyRaidDisplaysCompanion(
      characterId: Value(characterId),
      displayCount: Value(displayCount),
      raidIdsCsv: Value(raidIdsCsv),
    );
  }

  factory CharacterWeeklyRaidDisplay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CharacterWeeklyRaidDisplay(
      characterId: serializer.fromJson<int>(json['characterId']),
      displayCount: serializer.fromJson<int>(json['displayCount']),
      raidIdsCsv: serializer.fromJson<String>(json['raidIdsCsv']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'characterId': serializer.toJson<int>(characterId),
      'displayCount': serializer.toJson<int>(displayCount),
      'raidIdsCsv': serializer.toJson<String>(raidIdsCsv),
    };
  }

  CharacterWeeklyRaidDisplay copyWith({
    int? characterId,
    int? displayCount,
    String? raidIdsCsv,
  }) => CharacterWeeklyRaidDisplay(
    characterId: characterId ?? this.characterId,
    displayCount: displayCount ?? this.displayCount,
    raidIdsCsv: raidIdsCsv ?? this.raidIdsCsv,
  );
  CharacterWeeklyRaidDisplay copyWithCompanion(
    CharacterWeeklyRaidDisplaysCompanion data,
  ) {
    return CharacterWeeklyRaidDisplay(
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      displayCount: data.displayCount.present
          ? data.displayCount.value
          : this.displayCount,
      raidIdsCsv: data.raidIdsCsv.present
          ? data.raidIdsCsv.value
          : this.raidIdsCsv,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CharacterWeeklyRaidDisplay(')
          ..write('characterId: $characterId, ')
          ..write('displayCount: $displayCount, ')
          ..write('raidIdsCsv: $raidIdsCsv')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(characterId, displayCount, raidIdsCsv);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CharacterWeeklyRaidDisplay &&
          other.characterId == this.characterId &&
          other.displayCount == this.displayCount &&
          other.raidIdsCsv == this.raidIdsCsv);
}

class CharacterWeeklyRaidDisplaysCompanion
    extends UpdateCompanion<CharacterWeeklyRaidDisplay> {
  final Value<int> characterId;
  final Value<int> displayCount;
  final Value<String> raidIdsCsv;
  const CharacterWeeklyRaidDisplaysCompanion({
    this.characterId = const Value.absent(),
    this.displayCount = const Value.absent(),
    this.raidIdsCsv = const Value.absent(),
  });
  CharacterWeeklyRaidDisplaysCompanion.insert({
    this.characterId = const Value.absent(),
    required int displayCount,
    required String raidIdsCsv,
  }) : displayCount = Value(displayCount),
       raidIdsCsv = Value(raidIdsCsv);
  static Insertable<CharacterWeeklyRaidDisplay> custom({
    Expression<int>? characterId,
    Expression<int>? displayCount,
    Expression<String>? raidIdsCsv,
  }) {
    return RawValuesInsertable({
      if (characterId != null) 'character_id': characterId,
      if (displayCount != null) 'display_count': displayCount,
      if (raidIdsCsv != null) 'raid_ids_csv': raidIdsCsv,
    });
  }

  CharacterWeeklyRaidDisplaysCompanion copyWith({
    Value<int>? characterId,
    Value<int>? displayCount,
    Value<String>? raidIdsCsv,
  }) {
    return CharacterWeeklyRaidDisplaysCompanion(
      characterId: characterId ?? this.characterId,
      displayCount: displayCount ?? this.displayCount,
      raidIdsCsv: raidIdsCsv ?? this.raidIdsCsv,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (displayCount.present) {
      map['display_count'] = Variable<int>(displayCount.value);
    }
    if (raidIdsCsv.present) {
      map['raid_ids_csv'] = Variable<String>(raidIdsCsv.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharacterWeeklyRaidDisplaysCompanion(')
          ..write('characterId: $characterId, ')
          ..write('displayCount: $displayCount, ')
          ..write('raidIdsCsv: $raidIdsCsv')
          ..write(')'))
        .toString();
  }
}

abstract class _$AccountDatabase extends GeneratedDatabase {
  _$AccountDatabase(QueryExecutor e) : super(e);
  $AccountDatabaseManager get managers => $AccountDatabaseManager(this);
  late final $GameAccountsTable gameAccounts = $GameAccountsTable(this);
  late final $AccountCharactersTable accountCharacters =
      $AccountCharactersTable(this);
  late final $CharacterBuildSnapshotsTable characterBuildSnapshots =
      $CharacterBuildSnapshotsTable(this);
  late final $RaidHistoryEntriesTable raidHistoryEntries =
      $RaidHistoryEntriesTable(this);
  late final $PartyNotificationReceiptsTable partyNotificationReceipts =
      $PartyNotificationReceiptsTable(this);
  late final $CharacterWeeklyRaidDisplaysTable characterWeeklyRaidDisplays =
      $CharacterWeeklyRaidDisplaysTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    gameAccounts,
    accountCharacters,
    characterBuildSnapshots,
    raidHistoryEntries,
    partyNotificationReceipts,
    characterWeeklyRaidDisplays,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'game_accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('account_characters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'account_characters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('character_build_snapshots', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'account_characters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('character_weekly_raid_displays', kind: UpdateKind.delete),
      ],
    ),
  ]);
}

typedef $$GameAccountsTableCreateCompanionBuilder =
    GameAccountsCompanion Function({
      Value<int> id,
      Value<String?> serverGameAccountId,
      Value<String?> serverOwnershipStatus,
      required String label,
      Value<bool> isMain,
      required String lookupCharacterName,
      Value<int?> representativeCharacterId,
      Value<int> displayLimit,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$GameAccountsTableUpdateCompanionBuilder =
    GameAccountsCompanion Function({
      Value<int> id,
      Value<String?> serverGameAccountId,
      Value<String?> serverOwnershipStatus,
      Value<String> label,
      Value<bool> isMain,
      Value<String> lookupCharacterName,
      Value<int?> representativeCharacterId,
      Value<int> displayLimit,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$GameAccountsTableReferences
    extends BaseReferences<_$AccountDatabase, $GameAccountsTable, GameAccount> {
  $$GameAccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AccountCharactersTable, List<AccountCharacter>>
  _accountCharactersRefsTable(_$AccountDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.accountCharacters,
        aliasName: 'game_accounts__id__account_characters__account_id',
      );

  $$AccountCharactersTableProcessedTableManager get accountCharactersRefs {
    final manager = $$AccountCharactersTableTableManager(
      $_db,
      $_db.accountCharacters,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _accountCharactersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GameAccountsTableFilterComposer
    extends Composer<_$AccountDatabase, $GameAccountsTable> {
  $$GameAccountsTableFilterComposer({
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

  ColumnFilters<String> get serverGameAccountId => $composableBuilder(
    column: $table.serverGameAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverOwnershipStatus => $composableBuilder(
    column: $table.serverOwnershipStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMain => $composableBuilder(
    column: $table.isMain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lookupCharacterName => $composableBuilder(
    column: $table.lookupCharacterName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get representativeCharacterId => $composableBuilder(
    column: $table.representativeCharacterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayLimit => $composableBuilder(
    column: $table.displayLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> accountCharactersRefs(
    Expression<bool> Function($$AccountCharactersTableFilterComposer f) f,
  ) {
    final $$AccountCharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.accountCharacters,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountCharactersTableFilterComposer(
            $db: $db,
            $table: $db.accountCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GameAccountsTableOrderingComposer
    extends Composer<_$AccountDatabase, $GameAccountsTable> {
  $$GameAccountsTableOrderingComposer({
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

  ColumnOrderings<String> get serverGameAccountId => $composableBuilder(
    column: $table.serverGameAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverOwnershipStatus => $composableBuilder(
    column: $table.serverOwnershipStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMain => $composableBuilder(
    column: $table.isMain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lookupCharacterName => $composableBuilder(
    column: $table.lookupCharacterName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get representativeCharacterId => $composableBuilder(
    column: $table.representativeCharacterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayLimit => $composableBuilder(
    column: $table.displayLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameAccountsTableAnnotationComposer
    extends Composer<_$AccountDatabase, $GameAccountsTable> {
  $$GameAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverGameAccountId => $composableBuilder(
    column: $table.serverGameAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverOwnershipStatus => $composableBuilder(
    column: $table.serverOwnershipStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<bool> get isMain =>
      $composableBuilder(column: $table.isMain, builder: (column) => column);

  GeneratedColumn<String> get lookupCharacterName => $composableBuilder(
    column: $table.lookupCharacterName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get representativeCharacterId => $composableBuilder(
    column: $table.representativeCharacterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get displayLimit => $composableBuilder(
    column: $table.displayLimit,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> accountCharactersRefs<T extends Object>(
    Expression<T> Function($$AccountCharactersTableAnnotationComposer a) f,
  ) {
    final $$AccountCharactersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.accountCharacters,
          getReferencedColumn: (t) => t.accountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AccountCharactersTableAnnotationComposer(
                $db: $db,
                $table: $db.accountCharacters,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$GameAccountsTableTableManager
    extends
        RootTableManager<
          _$AccountDatabase,
          $GameAccountsTable,
          GameAccount,
          $$GameAccountsTableFilterComposer,
          $$GameAccountsTableOrderingComposer,
          $$GameAccountsTableAnnotationComposer,
          $$GameAccountsTableCreateCompanionBuilder,
          $$GameAccountsTableUpdateCompanionBuilder,
          (GameAccount, $$GameAccountsTableReferences),
          GameAccount,
          PrefetchHooks Function({bool accountCharactersRefs})
        > {
  $$GameAccountsTableTableManager(
    _$AccountDatabase db,
    $GameAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverGameAccountId = const Value.absent(),
                Value<String?> serverOwnershipStatus = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<bool> isMain = const Value.absent(),
                Value<String> lookupCharacterName = const Value.absent(),
                Value<int?> representativeCharacterId = const Value.absent(),
                Value<int> displayLimit = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GameAccountsCompanion(
                id: id,
                serverGameAccountId: serverGameAccountId,
                serverOwnershipStatus: serverOwnershipStatus,
                label: label,
                isMain: isMain,
                lookupCharacterName: lookupCharacterName,
                representativeCharacterId: representativeCharacterId,
                displayLimit: displayLimit,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverGameAccountId = const Value.absent(),
                Value<String?> serverOwnershipStatus = const Value.absent(),
                required String label,
                Value<bool> isMain = const Value.absent(),
                required String lookupCharacterName,
                Value<int?> representativeCharacterId = const Value.absent(),
                Value<int> displayLimit = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => GameAccountsCompanion.insert(
                id: id,
                serverGameAccountId: serverGameAccountId,
                serverOwnershipStatus: serverOwnershipStatus,
                label: label,
                isMain: isMain,
                lookupCharacterName: lookupCharacterName,
                representativeCharacterId: representativeCharacterId,
                displayLimit: displayLimit,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GameAccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountCharactersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (accountCharactersRefs) db.accountCharacters,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (accountCharactersRefs)
                    await $_getPrefetchedData<
                      GameAccount,
                      $GameAccountsTable,
                      AccountCharacter
                    >(
                      currentTable: table,
                      referencedTable: $$GameAccountsTableReferences
                          ._accountCharactersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$GameAccountsTableReferences(
                            db,
                            table,
                            p0,
                          ).accountCharactersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.accountId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GameAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AccountDatabase,
      $GameAccountsTable,
      GameAccount,
      $$GameAccountsTableFilterComposer,
      $$GameAccountsTableOrderingComposer,
      $$GameAccountsTableAnnotationComposer,
      $$GameAccountsTableCreateCompanionBuilder,
      $$GameAccountsTableUpdateCompanionBuilder,
      (GameAccount, $$GameAccountsTableReferences),
      GameAccount,
      PrefetchHooks Function({bool accountCharactersRefs})
    >;
typedef $$AccountCharactersTableCreateCompanionBuilder =
    AccountCharactersCompanion Function({
      Value<int> id,
      Value<String?> serverCharacterId,
      required int accountId,
      required String serverName,
      required String characterName,
      required int characterLevel,
      required String characterClassName,
      Value<double?> itemLevel,
      Value<double?> combatPower,
      Value<bool> isVisible,
      Value<bool> isRosterMissing,
      Value<int?> displayOrder,
      Value<String?> preferredRole,
      required DateTime lastSummaryFetchedAt,
    });
typedef $$AccountCharactersTableUpdateCompanionBuilder =
    AccountCharactersCompanion Function({
      Value<int> id,
      Value<String?> serverCharacterId,
      Value<int> accountId,
      Value<String> serverName,
      Value<String> characterName,
      Value<int> characterLevel,
      Value<String> characterClassName,
      Value<double?> itemLevel,
      Value<double?> combatPower,
      Value<bool> isVisible,
      Value<bool> isRosterMissing,
      Value<int?> displayOrder,
      Value<String?> preferredRole,
      Value<DateTime> lastSummaryFetchedAt,
    });

final class $$AccountCharactersTableReferences
    extends
        BaseReferences<
          _$AccountDatabase,
          $AccountCharactersTable,
          AccountCharacter
        > {
  $$AccountCharactersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GameAccountsTable _accountIdTable(_$AccountDatabase db) => db
      .gameAccounts
      .createAlias('account_characters__account_id__game_accounts__id');

  $$GameAccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$GameAccountsTableTableManager(
      $_db,
      $_db.gameAccounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $CharacterBuildSnapshotsTable,
    List<CharacterBuildSnapshotRow>
  >
  _characterBuildSnapshotsRefsTable(_$AccountDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.characterBuildSnapshots,
        aliasName:
            'account_characters__id__character_build_snapshots__character_id',
      );

  $$CharacterBuildSnapshotsTableProcessedTableManager
  get characterBuildSnapshotsRefs {
    final manager = $$CharacterBuildSnapshotsTableTableManager(
      $_db,
      $_db.characterBuildSnapshots,
    ).filter((f) => f.characterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _characterBuildSnapshotsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CharacterWeeklyRaidDisplaysTable,
    List<CharacterWeeklyRaidDisplay>
  >
  _characterWeeklyRaidDisplaysRefsTable(
    _$AccountDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.characterWeeklyRaidDisplays,
    aliasName:
        'account_characters__id__character_weekly_raid_displays__character_id',
  );

  $$CharacterWeeklyRaidDisplaysTableProcessedTableManager
  get characterWeeklyRaidDisplaysRefs {
    final manager = $$CharacterWeeklyRaidDisplaysTableTableManager(
      $_db,
      $_db.characterWeeklyRaidDisplays,
    ).filter((f) => f.characterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _characterWeeklyRaidDisplaysRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountCharactersTableFilterComposer
    extends Composer<_$AccountDatabase, $AccountCharactersTable> {
  $$AccountCharactersTableFilterComposer({
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

  ColumnFilters<String> get serverCharacterId => $composableBuilder(
    column: $table.serverCharacterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterName => $composableBuilder(
    column: $table.characterName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get characterLevel => $composableBuilder(
    column: $table.characterLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterClassName => $composableBuilder(
    column: $table.characterClassName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get itemLevel => $composableBuilder(
    column: $table.itemLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get combatPower => $composableBuilder(
    column: $table.combatPower,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVisible => $composableBuilder(
    column: $table.isVisible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRosterMissing => $composableBuilder(
    column: $table.isRosterMissing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredRole => $composableBuilder(
    column: $table.preferredRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSummaryFetchedAt => $composableBuilder(
    column: $table.lastSummaryFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GameAccountsTableFilterComposer get accountId {
    final $$GameAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.gameAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameAccountsTableFilterComposer(
            $db: $db,
            $table: $db.gameAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> characterBuildSnapshotsRefs(
    Expression<bool> Function($$CharacterBuildSnapshotsTableFilterComposer f) f,
  ) {
    final $$CharacterBuildSnapshotsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.characterBuildSnapshots,
          getReferencedColumn: (t) => t.characterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CharacterBuildSnapshotsTableFilterComposer(
                $db: $db,
                $table: $db.characterBuildSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> characterWeeklyRaidDisplaysRefs(
    Expression<bool> Function(
      $$CharacterWeeklyRaidDisplaysTableFilterComposer f,
    )
    f,
  ) {
    final $$CharacterWeeklyRaidDisplaysTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.characterWeeklyRaidDisplays,
          getReferencedColumn: (t) => t.characterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CharacterWeeklyRaidDisplaysTableFilterComposer(
                $db: $db,
                $table: $db.characterWeeklyRaidDisplays,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AccountCharactersTableOrderingComposer
    extends Composer<_$AccountDatabase, $AccountCharactersTable> {
  $$AccountCharactersTableOrderingComposer({
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

  ColumnOrderings<String> get serverCharacterId => $composableBuilder(
    column: $table.serverCharacterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterName => $composableBuilder(
    column: $table.characterName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get characterLevel => $composableBuilder(
    column: $table.characterLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterClassName => $composableBuilder(
    column: $table.characterClassName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get itemLevel => $composableBuilder(
    column: $table.itemLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get combatPower => $composableBuilder(
    column: $table.combatPower,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVisible => $composableBuilder(
    column: $table.isVisible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRosterMissing => $composableBuilder(
    column: $table.isRosterMissing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredRole => $composableBuilder(
    column: $table.preferredRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSummaryFetchedAt => $composableBuilder(
    column: $table.lastSummaryFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GameAccountsTableOrderingComposer get accountId {
    final $$GameAccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.gameAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameAccountsTableOrderingComposer(
            $db: $db,
            $table: $db.gameAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AccountCharactersTableAnnotationComposer
    extends Composer<_$AccountDatabase, $AccountCharactersTable> {
  $$AccountCharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverCharacterId => $composableBuilder(
    column: $table.serverCharacterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get characterName => $composableBuilder(
    column: $table.characterName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get characterLevel => $composableBuilder(
    column: $table.characterLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get characterClassName => $composableBuilder(
    column: $table.characterClassName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get itemLevel =>
      $composableBuilder(column: $table.itemLevel, builder: (column) => column);

  GeneratedColumn<double> get combatPower => $composableBuilder(
    column: $table.combatPower,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isVisible =>
      $composableBuilder(column: $table.isVisible, builder: (column) => column);

  GeneratedColumn<bool> get isRosterMissing => $composableBuilder(
    column: $table.isRosterMissing,
    builder: (column) => column,
  );

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredRole => $composableBuilder(
    column: $table.preferredRole,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSummaryFetchedAt => $composableBuilder(
    column: $table.lastSummaryFetchedAt,
    builder: (column) => column,
  );

  $$GameAccountsTableAnnotationComposer get accountId {
    final $$GameAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.gameAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.gameAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> characterBuildSnapshotsRefs<T extends Object>(
    Expression<T> Function($$CharacterBuildSnapshotsTableAnnotationComposer a)
    f,
  ) {
    final $$CharacterBuildSnapshotsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.characterBuildSnapshots,
          getReferencedColumn: (t) => t.characterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CharacterBuildSnapshotsTableAnnotationComposer(
                $db: $db,
                $table: $db.characterBuildSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> characterWeeklyRaidDisplaysRefs<T extends Object>(
    Expression<T> Function(
      $$CharacterWeeklyRaidDisplaysTableAnnotationComposer a,
    )
    f,
  ) {
    final $$CharacterWeeklyRaidDisplaysTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.characterWeeklyRaidDisplays,
          getReferencedColumn: (t) => t.characterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CharacterWeeklyRaidDisplaysTableAnnotationComposer(
                $db: $db,
                $table: $db.characterWeeklyRaidDisplays,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AccountCharactersTableTableManager
    extends
        RootTableManager<
          _$AccountDatabase,
          $AccountCharactersTable,
          AccountCharacter,
          $$AccountCharactersTableFilterComposer,
          $$AccountCharactersTableOrderingComposer,
          $$AccountCharactersTableAnnotationComposer,
          $$AccountCharactersTableCreateCompanionBuilder,
          $$AccountCharactersTableUpdateCompanionBuilder,
          (AccountCharacter, $$AccountCharactersTableReferences),
          AccountCharacter,
          PrefetchHooks Function({
            bool accountId,
            bool characterBuildSnapshotsRefs,
            bool characterWeeklyRaidDisplaysRefs,
          })
        > {
  $$AccountCharactersTableTableManager(
    _$AccountDatabase db,
    $AccountCharactersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountCharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountCharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountCharactersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverCharacterId = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<String> serverName = const Value.absent(),
                Value<String> characterName = const Value.absent(),
                Value<int> characterLevel = const Value.absent(),
                Value<String> characterClassName = const Value.absent(),
                Value<double?> itemLevel = const Value.absent(),
                Value<double?> combatPower = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<bool> isRosterMissing = const Value.absent(),
                Value<int?> displayOrder = const Value.absent(),
                Value<String?> preferredRole = const Value.absent(),
                Value<DateTime> lastSummaryFetchedAt = const Value.absent(),
              }) => AccountCharactersCompanion(
                id: id,
                serverCharacterId: serverCharacterId,
                accountId: accountId,
                serverName: serverName,
                characterName: characterName,
                characterLevel: characterLevel,
                characterClassName: characterClassName,
                itemLevel: itemLevel,
                combatPower: combatPower,
                isVisible: isVisible,
                isRosterMissing: isRosterMissing,
                displayOrder: displayOrder,
                preferredRole: preferredRole,
                lastSummaryFetchedAt: lastSummaryFetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverCharacterId = const Value.absent(),
                required int accountId,
                required String serverName,
                required String characterName,
                required int characterLevel,
                required String characterClassName,
                Value<double?> itemLevel = const Value.absent(),
                Value<double?> combatPower = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<bool> isRosterMissing = const Value.absent(),
                Value<int?> displayOrder = const Value.absent(),
                Value<String?> preferredRole = const Value.absent(),
                required DateTime lastSummaryFetchedAt,
              }) => AccountCharactersCompanion.insert(
                id: id,
                serverCharacterId: serverCharacterId,
                accountId: accountId,
                serverName: serverName,
                characterName: characterName,
                characterLevel: characterLevel,
                characterClassName: characterClassName,
                itemLevel: itemLevel,
                combatPower: combatPower,
                isVisible: isVisible,
                isRosterMissing: isRosterMissing,
                displayOrder: displayOrder,
                preferredRole: preferredRole,
                lastSummaryFetchedAt: lastSummaryFetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountCharactersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                characterBuildSnapshotsRefs = false,
                characterWeeklyRaidDisplaysRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (characterBuildSnapshotsRefs) db.characterBuildSnapshots,
                    if (characterWeeklyRaidDisplaysRefs)
                      db.characterWeeklyRaidDisplays,
                  ],
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
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$AccountCharactersTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$AccountCharactersTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (characterBuildSnapshotsRefs)
                        await $_getPrefetchedData<
                          AccountCharacter,
                          $AccountCharactersTable,
                          CharacterBuildSnapshotRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountCharactersTableReferences
                              ._characterBuildSnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountCharactersTableReferences(
                                db,
                                table,
                                p0,
                              ).characterBuildSnapshotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (characterWeeklyRaidDisplaysRefs)
                        await $_getPrefetchedData<
                          AccountCharacter,
                          $AccountCharactersTable,
                          CharacterWeeklyRaidDisplay
                        >(
                          currentTable: table,
                          referencedTable: $$AccountCharactersTableReferences
                              ._characterWeeklyRaidDisplaysRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountCharactersTableReferences(
                                db,
                                table,
                                p0,
                              ).characterWeeklyRaidDisplaysRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.id,
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

typedef $$AccountCharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AccountDatabase,
      $AccountCharactersTable,
      AccountCharacter,
      $$AccountCharactersTableFilterComposer,
      $$AccountCharactersTableOrderingComposer,
      $$AccountCharactersTableAnnotationComposer,
      $$AccountCharactersTableCreateCompanionBuilder,
      $$AccountCharactersTableUpdateCompanionBuilder,
      (AccountCharacter, $$AccountCharactersTableReferences),
      AccountCharacter,
      PrefetchHooks Function({
        bool accountId,
        bool characterBuildSnapshotsRefs,
        bool characterWeeklyRaidDisplaysRefs,
      })
    >;
typedef $$CharacterBuildSnapshotsTableCreateCompanionBuilder =
    CharacterBuildSnapshotsCompanion Function({
      Value<int> id,
      required int characterId,
      required String role,
      required String rawJson,
      Value<double?> itemLevel,
      Value<double?> combatPower,
      required DateTime capturedAt,
      Value<int> dataVersion,
    });
typedef $$CharacterBuildSnapshotsTableUpdateCompanionBuilder =
    CharacterBuildSnapshotsCompanion Function({
      Value<int> id,
      Value<int> characterId,
      Value<String> role,
      Value<String> rawJson,
      Value<double?> itemLevel,
      Value<double?> combatPower,
      Value<DateTime> capturedAt,
      Value<int> dataVersion,
    });

final class $$CharacterBuildSnapshotsTableReferences
    extends
        BaseReferences<
          _$AccountDatabase,
          $CharacterBuildSnapshotsTable,
          CharacterBuildSnapshotRow
        > {
  $$CharacterBuildSnapshotsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountCharactersTable _characterIdTable(_$AccountDatabase db) =>
      db.accountCharacters.createAlias(
        'character_build_snapshots__character_id__account_characters__id',
      );

  $$AccountCharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$AccountCharactersTableTableManager(
      $_db,
      $_db.accountCharacters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CharacterBuildSnapshotsTableFilterComposer
    extends Composer<_$AccountDatabase, $CharacterBuildSnapshotsTable> {
  $$CharacterBuildSnapshotsTableFilterComposer({
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

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get itemLevel => $composableBuilder(
    column: $table.itemLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get combatPower => $composableBuilder(
    column: $table.combatPower,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataVersion => $composableBuilder(
    column: $table.dataVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountCharactersTableFilterComposer get characterId {
    final $$AccountCharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.accountCharacters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountCharactersTableFilterComposer(
            $db: $db,
            $table: $db.accountCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharacterBuildSnapshotsTableOrderingComposer
    extends Composer<_$AccountDatabase, $CharacterBuildSnapshotsTable> {
  $$CharacterBuildSnapshotsTableOrderingComposer({
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

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get itemLevel => $composableBuilder(
    column: $table.itemLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get combatPower => $composableBuilder(
    column: $table.combatPower,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataVersion => $composableBuilder(
    column: $table.dataVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountCharactersTableOrderingComposer get characterId {
    final $$AccountCharactersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.accountCharacters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountCharactersTableOrderingComposer(
            $db: $db,
            $table: $db.accountCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharacterBuildSnapshotsTableAnnotationComposer
    extends Composer<_$AccountDatabase, $CharacterBuildSnapshotsTable> {
  $$CharacterBuildSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<double> get itemLevel =>
      $composableBuilder(column: $table.itemLevel, builder: (column) => column);

  GeneratedColumn<double> get combatPower => $composableBuilder(
    column: $table.combatPower,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dataVersion => $composableBuilder(
    column: $table.dataVersion,
    builder: (column) => column,
  );

  $$AccountCharactersTableAnnotationComposer get characterId {
    final $$AccountCharactersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.characterId,
          referencedTable: $db.accountCharacters,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AccountCharactersTableAnnotationComposer(
                $db: $db,
                $table: $db.accountCharacters,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$CharacterBuildSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AccountDatabase,
          $CharacterBuildSnapshotsTable,
          CharacterBuildSnapshotRow,
          $$CharacterBuildSnapshotsTableFilterComposer,
          $$CharacterBuildSnapshotsTableOrderingComposer,
          $$CharacterBuildSnapshotsTableAnnotationComposer,
          $$CharacterBuildSnapshotsTableCreateCompanionBuilder,
          $$CharacterBuildSnapshotsTableUpdateCompanionBuilder,
          (CharacterBuildSnapshotRow, $$CharacterBuildSnapshotsTableReferences),
          CharacterBuildSnapshotRow,
          PrefetchHooks Function({bool characterId})
        > {
  $$CharacterBuildSnapshotsTableTableManager(
    _$AccountDatabase db,
    $CharacterBuildSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharacterBuildSnapshotsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CharacterBuildSnapshotsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CharacterBuildSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> characterId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<double?> itemLevel = const Value.absent(),
                Value<double?> combatPower = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<int> dataVersion = const Value.absent(),
              }) => CharacterBuildSnapshotsCompanion(
                id: id,
                characterId: characterId,
                role: role,
                rawJson: rawJson,
                itemLevel: itemLevel,
                combatPower: combatPower,
                capturedAt: capturedAt,
                dataVersion: dataVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int characterId,
                required String role,
                required String rawJson,
                Value<double?> itemLevel = const Value.absent(),
                Value<double?> combatPower = const Value.absent(),
                required DateTime capturedAt,
                Value<int> dataVersion = const Value.absent(),
              }) => CharacterBuildSnapshotsCompanion.insert(
                id: id,
                characterId: characterId,
                role: role,
                rawJson: rawJson,
                itemLevel: itemLevel,
                combatPower: combatPower,
                capturedAt: capturedAt,
                dataVersion: dataVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CharacterBuildSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
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
                    if (characterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.characterId,
                                referencedTable:
                                    $$CharacterBuildSnapshotsTableReferences
                                        ._characterIdTable(db),
                                referencedColumn:
                                    $$CharacterBuildSnapshotsTableReferences
                                        ._characterIdTable(db)
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

typedef $$CharacterBuildSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AccountDatabase,
      $CharacterBuildSnapshotsTable,
      CharacterBuildSnapshotRow,
      $$CharacterBuildSnapshotsTableFilterComposer,
      $$CharacterBuildSnapshotsTableOrderingComposer,
      $$CharacterBuildSnapshotsTableAnnotationComposer,
      $$CharacterBuildSnapshotsTableCreateCompanionBuilder,
      $$CharacterBuildSnapshotsTableUpdateCompanionBuilder,
      (CharacterBuildSnapshotRow, $$CharacterBuildSnapshotsTableReferences),
      CharacterBuildSnapshotRow,
      PrefetchHooks Function({bool characterId})
    >;
typedef $$RaidHistoryEntriesTableCreateCompanionBuilder =
    RaidHistoryEntriesCompanion Function({
      required String eventId,
      required String playerId,
      required String characterId,
      required String recruitmentId,
      required String raidId,
      required String difficultyId,
      required String cycleKey,
      required String serverStatus,
      Value<String?> localStatusOverride,
      Value<String> source,
      Value<String> visibility,
      required DateTime occurredAt,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$RaidHistoryEntriesTableUpdateCompanionBuilder =
    RaidHistoryEntriesCompanion Function({
      Value<String> eventId,
      Value<String> playerId,
      Value<String> characterId,
      Value<String> recruitmentId,
      Value<String> raidId,
      Value<String> difficultyId,
      Value<String> cycleKey,
      Value<String> serverStatus,
      Value<String?> localStatusOverride,
      Value<String> source,
      Value<String> visibility,
      Value<DateTime> occurredAt,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$RaidHistoryEntriesTableFilterComposer
    extends Composer<_$AccountDatabase, $RaidHistoryEntriesTable> {
  $$RaidHistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recruitmentId => $composableBuilder(
    column: $table.recruitmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get raidId => $composableBuilder(
    column: $table.raidId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficultyId => $composableBuilder(
    column: $table.difficultyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cycleKey => $composableBuilder(
    column: $table.cycleKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverStatus => $composableBuilder(
    column: $table.serverStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localStatusOverride => $composableBuilder(
    column: $table.localStatusOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RaidHistoryEntriesTableOrderingComposer
    extends Composer<_$AccountDatabase, $RaidHistoryEntriesTable> {
  $$RaidHistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recruitmentId => $composableBuilder(
    column: $table.recruitmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get raidId => $composableBuilder(
    column: $table.raidId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficultyId => $composableBuilder(
    column: $table.difficultyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycleKey => $composableBuilder(
    column: $table.cycleKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverStatus => $composableBuilder(
    column: $table.serverStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localStatusOverride => $composableBuilder(
    column: $table.localStatusOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RaidHistoryEntriesTableAnnotationComposer
    extends Composer<_$AccountDatabase, $RaidHistoryEntriesTable> {
  $$RaidHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get playerId =>
      $composableBuilder(column: $table.playerId, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recruitmentId => $composableBuilder(
    column: $table.recruitmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get raidId =>
      $composableBuilder(column: $table.raidId, builder: (column) => column);

  GeneratedColumn<String> get difficultyId => $composableBuilder(
    column: $table.difficultyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cycleKey =>
      $composableBuilder(column: $table.cycleKey, builder: (column) => column);

  GeneratedColumn<String> get serverStatus => $composableBuilder(
    column: $table.serverStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localStatusOverride => $composableBuilder(
    column: $table.localStatusOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$RaidHistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AccountDatabase,
          $RaidHistoryEntriesTable,
          RaidHistoryEntry,
          $$RaidHistoryEntriesTableFilterComposer,
          $$RaidHistoryEntriesTableOrderingComposer,
          $$RaidHistoryEntriesTableAnnotationComposer,
          $$RaidHistoryEntriesTableCreateCompanionBuilder,
          $$RaidHistoryEntriesTableUpdateCompanionBuilder,
          (
            RaidHistoryEntry,
            BaseReferences<
              _$AccountDatabase,
              $RaidHistoryEntriesTable,
              RaidHistoryEntry
            >,
          ),
          RaidHistoryEntry,
          PrefetchHooks Function()
        > {
  $$RaidHistoryEntriesTableTableManager(
    _$AccountDatabase db,
    $RaidHistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RaidHistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RaidHistoryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RaidHistoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> playerId = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<String> recruitmentId = const Value.absent(),
                Value<String> raidId = const Value.absent(),
                Value<String> difficultyId = const Value.absent(),
                Value<String> cycleKey = const Value.absent(),
                Value<String> serverStatus = const Value.absent(),
                Value<String?> localStatusOverride = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RaidHistoryEntriesCompanion(
                eventId: eventId,
                playerId: playerId,
                characterId: characterId,
                recruitmentId: recruitmentId,
                raidId: raidId,
                difficultyId: difficultyId,
                cycleKey: cycleKey,
                serverStatus: serverStatus,
                localStatusOverride: localStatusOverride,
                source: source,
                visibility: visibility,
                occurredAt: occurredAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String playerId,
                required String characterId,
                required String recruitmentId,
                required String raidId,
                required String difficultyId,
                required String cycleKey,
                required String serverStatus,
                Value<String?> localStatusOverride = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                required DateTime occurredAt,
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => RaidHistoryEntriesCompanion.insert(
                eventId: eventId,
                playerId: playerId,
                characterId: characterId,
                recruitmentId: recruitmentId,
                raidId: raidId,
                difficultyId: difficultyId,
                cycleKey: cycleKey,
                serverStatus: serverStatus,
                localStatusOverride: localStatusOverride,
                source: source,
                visibility: visibility,
                occurredAt: occurredAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RaidHistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AccountDatabase,
      $RaidHistoryEntriesTable,
      RaidHistoryEntry,
      $$RaidHistoryEntriesTableFilterComposer,
      $$RaidHistoryEntriesTableOrderingComposer,
      $$RaidHistoryEntriesTableAnnotationComposer,
      $$RaidHistoryEntriesTableCreateCompanionBuilder,
      $$RaidHistoryEntriesTableUpdateCompanionBuilder,
      (
        RaidHistoryEntry,
        BaseReferences<
          _$AccountDatabase,
          $RaidHistoryEntriesTable,
          RaidHistoryEntry
        >,
      ),
      RaidHistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$PartyNotificationReceiptsTableCreateCompanionBuilder =
    PartyNotificationReceiptsCompanion Function({
      required String eventId,
      required String playerId,
      required String type,
      required String recruitmentId,
      Value<String?> cycleKey,
      Value<String?> raidId,
      Value<String?> difficultyId,
      Value<String?> characterNameSnapshot,
      required DateTime occurredAt,
      required DateTime expiresAt,
      Value<DateTime?> readAt,
      required DateTime firstSyncedAt,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$PartyNotificationReceiptsTableUpdateCompanionBuilder =
    PartyNotificationReceiptsCompanion Function({
      Value<String> eventId,
      Value<String> playerId,
      Value<String> type,
      Value<String> recruitmentId,
      Value<String?> cycleKey,
      Value<String?> raidId,
      Value<String?> difficultyId,
      Value<String?> characterNameSnapshot,
      Value<DateTime> occurredAt,
      Value<DateTime> expiresAt,
      Value<DateTime?> readAt,
      Value<DateTime> firstSyncedAt,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

class $$PartyNotificationReceiptsTableFilterComposer
    extends Composer<_$AccountDatabase, $PartyNotificationReceiptsTable> {
  $$PartyNotificationReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recruitmentId => $composableBuilder(
    column: $table.recruitmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cycleKey => $composableBuilder(
    column: $table.cycleKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get raidId => $composableBuilder(
    column: $table.raidId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficultyId => $composableBuilder(
    column: $table.difficultyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterNameSnapshot => $composableBuilder(
    column: $table.characterNameSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSyncedAt => $composableBuilder(
    column: $table.firstSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PartyNotificationReceiptsTableOrderingComposer
    extends Composer<_$AccountDatabase, $PartyNotificationReceiptsTable> {
  $$PartyNotificationReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recruitmentId => $composableBuilder(
    column: $table.recruitmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycleKey => $composableBuilder(
    column: $table.cycleKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get raidId => $composableBuilder(
    column: $table.raidId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficultyId => $composableBuilder(
    column: $table.difficultyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterNameSnapshot => $composableBuilder(
    column: $table.characterNameSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSyncedAt => $composableBuilder(
    column: $table.firstSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PartyNotificationReceiptsTableAnnotationComposer
    extends Composer<_$AccountDatabase, $PartyNotificationReceiptsTable> {
  $$PartyNotificationReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get playerId =>
      $composableBuilder(column: $table.playerId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get recruitmentId => $composableBuilder(
    column: $table.recruitmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cycleKey =>
      $composableBuilder(column: $table.cycleKey, builder: (column) => column);

  GeneratedColumn<String> get raidId =>
      $composableBuilder(column: $table.raidId, builder: (column) => column);

  GeneratedColumn<String> get difficultyId => $composableBuilder(
    column: $table.difficultyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get characterNameSnapshot => $composableBuilder(
    column: $table.characterNameSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSyncedAt => $composableBuilder(
    column: $table.firstSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$PartyNotificationReceiptsTableTableManager
    extends
        RootTableManager<
          _$AccountDatabase,
          $PartyNotificationReceiptsTable,
          PartyNotificationReceipt,
          $$PartyNotificationReceiptsTableFilterComposer,
          $$PartyNotificationReceiptsTableOrderingComposer,
          $$PartyNotificationReceiptsTableAnnotationComposer,
          $$PartyNotificationReceiptsTableCreateCompanionBuilder,
          $$PartyNotificationReceiptsTableUpdateCompanionBuilder,
          (
            PartyNotificationReceipt,
            BaseReferences<
              _$AccountDatabase,
              $PartyNotificationReceiptsTable,
              PartyNotificationReceipt
            >,
          ),
          PartyNotificationReceipt,
          PrefetchHooks Function()
        > {
  $$PartyNotificationReceiptsTableTableManager(
    _$AccountDatabase db,
    $PartyNotificationReceiptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartyNotificationReceiptsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PartyNotificationReceiptsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PartyNotificationReceiptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> playerId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> recruitmentId = const Value.absent(),
                Value<String?> cycleKey = const Value.absent(),
                Value<String?> raidId = const Value.absent(),
                Value<String?> difficultyId = const Value.absent(),
                Value<String?> characterNameSnapshot = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<DateTime> firstSyncedAt = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartyNotificationReceiptsCompanion(
                eventId: eventId,
                playerId: playerId,
                type: type,
                recruitmentId: recruitmentId,
                cycleKey: cycleKey,
                raidId: raidId,
                difficultyId: difficultyId,
                characterNameSnapshot: characterNameSnapshot,
                occurredAt: occurredAt,
                expiresAt: expiresAt,
                readAt: readAt,
                firstSyncedAt: firstSyncedAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String playerId,
                required String type,
                required String recruitmentId,
                Value<String?> cycleKey = const Value.absent(),
                Value<String?> raidId = const Value.absent(),
                Value<String?> difficultyId = const Value.absent(),
                Value<String?> characterNameSnapshot = const Value.absent(),
                required DateTime occurredAt,
                required DateTime expiresAt,
                Value<DateTime?> readAt = const Value.absent(),
                required DateTime firstSyncedAt,
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => PartyNotificationReceiptsCompanion.insert(
                eventId: eventId,
                playerId: playerId,
                type: type,
                recruitmentId: recruitmentId,
                cycleKey: cycleKey,
                raidId: raidId,
                difficultyId: difficultyId,
                characterNameSnapshot: characterNameSnapshot,
                occurredAt: occurredAt,
                expiresAt: expiresAt,
                readAt: readAt,
                firstSyncedAt: firstSyncedAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PartyNotificationReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AccountDatabase,
      $PartyNotificationReceiptsTable,
      PartyNotificationReceipt,
      $$PartyNotificationReceiptsTableFilterComposer,
      $$PartyNotificationReceiptsTableOrderingComposer,
      $$PartyNotificationReceiptsTableAnnotationComposer,
      $$PartyNotificationReceiptsTableCreateCompanionBuilder,
      $$PartyNotificationReceiptsTableUpdateCompanionBuilder,
      (
        PartyNotificationReceipt,
        BaseReferences<
          _$AccountDatabase,
          $PartyNotificationReceiptsTable,
          PartyNotificationReceipt
        >,
      ),
      PartyNotificationReceipt,
      PrefetchHooks Function()
    >;
typedef $$CharacterWeeklyRaidDisplaysTableCreateCompanionBuilder =
    CharacterWeeklyRaidDisplaysCompanion Function({
      Value<int> characterId,
      required int displayCount,
      required String raidIdsCsv,
    });
typedef $$CharacterWeeklyRaidDisplaysTableUpdateCompanionBuilder =
    CharacterWeeklyRaidDisplaysCompanion Function({
      Value<int> characterId,
      Value<int> displayCount,
      Value<String> raidIdsCsv,
    });

final class $$CharacterWeeklyRaidDisplaysTableReferences
    extends
        BaseReferences<
          _$AccountDatabase,
          $CharacterWeeklyRaidDisplaysTable,
          CharacterWeeklyRaidDisplay
        > {
  $$CharacterWeeklyRaidDisplaysTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountCharactersTable _characterIdTable(_$AccountDatabase db) =>
      db.accountCharacters.createAlias(
        'character_weekly_raid_displays__character_id__account_characters__id',
      );

  $$AccountCharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$AccountCharactersTableTableManager(
      $_db,
      $_db.accountCharacters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CharacterWeeklyRaidDisplaysTableFilterComposer
    extends Composer<_$AccountDatabase, $CharacterWeeklyRaidDisplaysTable> {
  $$CharacterWeeklyRaidDisplaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get displayCount => $composableBuilder(
    column: $table.displayCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get raidIdsCsv => $composableBuilder(
    column: $table.raidIdsCsv,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountCharactersTableFilterComposer get characterId {
    final $$AccountCharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.accountCharacters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountCharactersTableFilterComposer(
            $db: $db,
            $table: $db.accountCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharacterWeeklyRaidDisplaysTableOrderingComposer
    extends Composer<_$AccountDatabase, $CharacterWeeklyRaidDisplaysTable> {
  $$CharacterWeeklyRaidDisplaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get displayCount => $composableBuilder(
    column: $table.displayCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get raidIdsCsv => $composableBuilder(
    column: $table.raidIdsCsv,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountCharactersTableOrderingComposer get characterId {
    final $$AccountCharactersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.accountCharacters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountCharactersTableOrderingComposer(
            $db: $db,
            $table: $db.accountCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharacterWeeklyRaidDisplaysTableAnnotationComposer
    extends Composer<_$AccountDatabase, $CharacterWeeklyRaidDisplaysTable> {
  $$CharacterWeeklyRaidDisplaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get displayCount => $composableBuilder(
    column: $table.displayCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get raidIdsCsv => $composableBuilder(
    column: $table.raidIdsCsv,
    builder: (column) => column,
  );

  $$AccountCharactersTableAnnotationComposer get characterId {
    final $$AccountCharactersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.characterId,
          referencedTable: $db.accountCharacters,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AccountCharactersTableAnnotationComposer(
                $db: $db,
                $table: $db.accountCharacters,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$CharacterWeeklyRaidDisplaysTableTableManager
    extends
        RootTableManager<
          _$AccountDatabase,
          $CharacterWeeklyRaidDisplaysTable,
          CharacterWeeklyRaidDisplay,
          $$CharacterWeeklyRaidDisplaysTableFilterComposer,
          $$CharacterWeeklyRaidDisplaysTableOrderingComposer,
          $$CharacterWeeklyRaidDisplaysTableAnnotationComposer,
          $$CharacterWeeklyRaidDisplaysTableCreateCompanionBuilder,
          $$CharacterWeeklyRaidDisplaysTableUpdateCompanionBuilder,
          (
            CharacterWeeklyRaidDisplay,
            $$CharacterWeeklyRaidDisplaysTableReferences,
          ),
          CharacterWeeklyRaidDisplay,
          PrefetchHooks Function({bool characterId})
        > {
  $$CharacterWeeklyRaidDisplaysTableTableManager(
    _$AccountDatabase db,
    $CharacterWeeklyRaidDisplaysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharacterWeeklyRaidDisplaysTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CharacterWeeklyRaidDisplaysTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CharacterWeeklyRaidDisplaysTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> characterId = const Value.absent(),
                Value<int> displayCount = const Value.absent(),
                Value<String> raidIdsCsv = const Value.absent(),
              }) => CharacterWeeklyRaidDisplaysCompanion(
                characterId: characterId,
                displayCount: displayCount,
                raidIdsCsv: raidIdsCsv,
              ),
          createCompanionCallback:
              ({
                Value<int> characterId = const Value.absent(),
                required int displayCount,
                required String raidIdsCsv,
              }) => CharacterWeeklyRaidDisplaysCompanion.insert(
                characterId: characterId,
                displayCount: displayCount,
                raidIdsCsv: raidIdsCsv,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CharacterWeeklyRaidDisplaysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
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
                    if (characterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.characterId,
                                referencedTable:
                                    $$CharacterWeeklyRaidDisplaysTableReferences
                                        ._characterIdTable(db),
                                referencedColumn:
                                    $$CharacterWeeklyRaidDisplaysTableReferences
                                        ._characterIdTable(db)
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

typedef $$CharacterWeeklyRaidDisplaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AccountDatabase,
      $CharacterWeeklyRaidDisplaysTable,
      CharacterWeeklyRaidDisplay,
      $$CharacterWeeklyRaidDisplaysTableFilterComposer,
      $$CharacterWeeklyRaidDisplaysTableOrderingComposer,
      $$CharacterWeeklyRaidDisplaysTableAnnotationComposer,
      $$CharacterWeeklyRaidDisplaysTableCreateCompanionBuilder,
      $$CharacterWeeklyRaidDisplaysTableUpdateCompanionBuilder,
      (
        CharacterWeeklyRaidDisplay,
        $$CharacterWeeklyRaidDisplaysTableReferences,
      ),
      CharacterWeeklyRaidDisplay,
      PrefetchHooks Function({bool characterId})
    >;

class $AccountDatabaseManager {
  final _$AccountDatabase _db;
  $AccountDatabaseManager(this._db);
  $$GameAccountsTableTableManager get gameAccounts =>
      $$GameAccountsTableTableManager(_db, _db.gameAccounts);
  $$AccountCharactersTableTableManager get accountCharacters =>
      $$AccountCharactersTableTableManager(_db, _db.accountCharacters);
  $$CharacterBuildSnapshotsTableTableManager get characterBuildSnapshots =>
      $$CharacterBuildSnapshotsTableTableManager(
        _db,
        _db.characterBuildSnapshots,
      );
  $$RaidHistoryEntriesTableTableManager get raidHistoryEntries =>
      $$RaidHistoryEntriesTableTableManager(_db, _db.raidHistoryEntries);
  $$PartyNotificationReceiptsTableTableManager get partyNotificationReceipts =>
      $$PartyNotificationReceiptsTableTableManager(
        _db,
        _db.partyNotificationReceipts,
      );
  $$CharacterWeeklyRaidDisplaysTableTableManager
  get characterWeeklyRaidDisplays =>
      $$CharacterWeeklyRaidDisplaysTableTableManager(
        _db,
        _db.characterWeeklyRaidDisplays,
      );
}
