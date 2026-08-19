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
  final String label;
  final bool isMain;
  final String lookupCharacterName;
  final int? representativeCharacterId;
  final int displayLimit;
  final DateTime createdAt;
  final DateTime updatedAt;
  const GameAccount({
    required this.id,
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
    String? label,
    bool? isMain,
    String? lookupCharacterName,
    Value<int?> representativeCharacterId = const Value.absent(),
    int? displayLimit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GameAccount(
    id: id ?? this.id,
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
  final Value<String> label;
  final Value<bool> isMain;
  final Value<String> lookupCharacterName;
  final Value<int?> representativeCharacterId;
  final Value<int> displayLimit;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const GameAccountsCompanion({
    this.id = const Value.absent(),
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
    accountId,
    serverName,
    characterName,
    characterLevel,
    characterClassName,
    itemLevel,
    combatPower,
    isVisible,
    displayOrder,
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
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
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
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
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
  final int accountId;
  final String serverName;
  final String characterName;
  final int characterLevel;
  final String characterClassName;
  final double? itemLevel;
  final double? combatPower;
  final bool isVisible;
  final int? displayOrder;
  final DateTime lastSummaryFetchedAt;
  const AccountCharacter({
    required this.id,
    required this.accountId,
    required this.serverName,
    required this.characterName,
    required this.characterLevel,
    required this.characterClassName,
    this.itemLevel,
    this.combatPower,
    required this.isVisible,
    this.displayOrder,
    required this.lastSummaryFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
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
    if (!nullToAbsent || displayOrder != null) {
      map['display_order'] = Variable<int>(displayOrder);
    }
    map['last_summary_fetched_at'] = Variable<DateTime>(lastSummaryFetchedAt);
    return map;
  }

  AccountCharactersCompanion toCompanion(bool nullToAbsent) {
    return AccountCharactersCompanion(
      id: Value(id),
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
      displayOrder: displayOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(displayOrder),
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
      displayOrder: serializer.fromJson<int?>(json['displayOrder']),
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
      'accountId': serializer.toJson<int>(accountId),
      'serverName': serializer.toJson<String>(serverName),
      'characterName': serializer.toJson<String>(characterName),
      'characterLevel': serializer.toJson<int>(characterLevel),
      'characterClassName': serializer.toJson<String>(characterClassName),
      'itemLevel': serializer.toJson<double?>(itemLevel),
      'combatPower': serializer.toJson<double?>(combatPower),
      'isVisible': serializer.toJson<bool>(isVisible),
      'displayOrder': serializer.toJson<int?>(displayOrder),
      'lastSummaryFetchedAt': serializer.toJson<DateTime>(lastSummaryFetchedAt),
    };
  }

  AccountCharacter copyWith({
    int? id,
    int? accountId,
    String? serverName,
    String? characterName,
    int? characterLevel,
    String? characterClassName,
    Value<double?> itemLevel = const Value.absent(),
    Value<double?> combatPower = const Value.absent(),
    bool? isVisible,
    Value<int?> displayOrder = const Value.absent(),
    DateTime? lastSummaryFetchedAt,
  }) => AccountCharacter(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    serverName: serverName ?? this.serverName,
    characterName: characterName ?? this.characterName,
    characterLevel: characterLevel ?? this.characterLevel,
    characterClassName: characterClassName ?? this.characterClassName,
    itemLevel: itemLevel.present ? itemLevel.value : this.itemLevel,
    combatPower: combatPower.present ? combatPower.value : this.combatPower,
    isVisible: isVisible ?? this.isVisible,
    displayOrder: displayOrder.present ? displayOrder.value : this.displayOrder,
    lastSummaryFetchedAt: lastSummaryFetchedAt ?? this.lastSummaryFetchedAt,
  );
  AccountCharacter copyWithCompanion(AccountCharactersCompanion data) {
    return AccountCharacter(
      id: data.id.present ? data.id.value : this.id,
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
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      lastSummaryFetchedAt: data.lastSummaryFetchedAt.present
          ? data.lastSummaryFetchedAt.value
          : this.lastSummaryFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountCharacter(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('serverName: $serverName, ')
          ..write('characterName: $characterName, ')
          ..write('characterLevel: $characterLevel, ')
          ..write('characterClassName: $characterClassName, ')
          ..write('itemLevel: $itemLevel, ')
          ..write('combatPower: $combatPower, ')
          ..write('isVisible: $isVisible, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('lastSummaryFetchedAt: $lastSummaryFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    serverName,
    characterName,
    characterLevel,
    characterClassName,
    itemLevel,
    combatPower,
    isVisible,
    displayOrder,
    lastSummaryFetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountCharacter &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.serverName == this.serverName &&
          other.characterName == this.characterName &&
          other.characterLevel == this.characterLevel &&
          other.characterClassName == this.characterClassName &&
          other.itemLevel == this.itemLevel &&
          other.combatPower == this.combatPower &&
          other.isVisible == this.isVisible &&
          other.displayOrder == this.displayOrder &&
          other.lastSummaryFetchedAt == this.lastSummaryFetchedAt);
}

class AccountCharactersCompanion extends UpdateCompanion<AccountCharacter> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<String> serverName;
  final Value<String> characterName;
  final Value<int> characterLevel;
  final Value<String> characterClassName;
  final Value<double?> itemLevel;
  final Value<double?> combatPower;
  final Value<bool> isVisible;
  final Value<int?> displayOrder;
  final Value<DateTime> lastSummaryFetchedAt;
  const AccountCharactersCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.serverName = const Value.absent(),
    this.characterName = const Value.absent(),
    this.characterLevel = const Value.absent(),
    this.characterClassName = const Value.absent(),
    this.itemLevel = const Value.absent(),
    this.combatPower = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.lastSummaryFetchedAt = const Value.absent(),
  });
  AccountCharactersCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required String serverName,
    required String characterName,
    required int characterLevel,
    required String characterClassName,
    this.itemLevel = const Value.absent(),
    this.combatPower = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.displayOrder = const Value.absent(),
    required DateTime lastSummaryFetchedAt,
  }) : accountId = Value(accountId),
       serverName = Value(serverName),
       characterName = Value(characterName),
       characterLevel = Value(characterLevel),
       characterClassName = Value(characterClassName),
       lastSummaryFetchedAt = Value(lastSummaryFetchedAt);
  static Insertable<AccountCharacter> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<String>? serverName,
    Expression<String>? characterName,
    Expression<int>? characterLevel,
    Expression<String>? characterClassName,
    Expression<double>? itemLevel,
    Expression<double>? combatPower,
    Expression<bool>? isVisible,
    Expression<int>? displayOrder,
    Expression<DateTime>? lastSummaryFetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (serverName != null) 'server_name': serverName,
      if (characterName != null) 'character_name': characterName,
      if (characterLevel != null) 'character_level': characterLevel,
      if (characterClassName != null)
        'character_class_name': characterClassName,
      if (itemLevel != null) 'item_level': itemLevel,
      if (combatPower != null) 'combat_power': combatPower,
      if (isVisible != null) 'is_visible': isVisible,
      if (displayOrder != null) 'display_order': displayOrder,
      if (lastSummaryFetchedAt != null)
        'last_summary_fetched_at': lastSummaryFetchedAt,
    });
  }

  AccountCharactersCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<String>? serverName,
    Value<String>? characterName,
    Value<int>? characterLevel,
    Value<String>? characterClassName,
    Value<double?>? itemLevel,
    Value<double?>? combatPower,
    Value<bool>? isVisible,
    Value<int?>? displayOrder,
    Value<DateTime>? lastSummaryFetchedAt,
  }) {
    return AccountCharactersCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      serverName: serverName ?? this.serverName,
      characterName: characterName ?? this.characterName,
      characterLevel: characterLevel ?? this.characterLevel,
      characterClassName: characterClassName ?? this.characterClassName,
      itemLevel: itemLevel ?? this.itemLevel,
      combatPower: combatPower ?? this.combatPower,
      isVisible: isVisible ?? this.isVisible,
      displayOrder: displayOrder ?? this.displayOrder,
      lastSummaryFetchedAt: lastSummaryFetchedAt ?? this.lastSummaryFetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
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
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
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
          ..write('accountId: $accountId, ')
          ..write('serverName: $serverName, ')
          ..write('characterName: $characterName, ')
          ..write('characterLevel: $characterLevel, ')
          ..write('characterClassName: $characterClassName, ')
          ..write('itemLevel: $itemLevel, ')
          ..write('combatPower: $combatPower, ')
          ..write('isVisible: $isVisible, ')
          ..write('displayOrder: $displayOrder, ')
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

abstract class _$AccountDatabase extends GeneratedDatabase {
  _$AccountDatabase(QueryExecutor e) : super(e);
  $AccountDatabaseManager get managers => $AccountDatabaseManager(this);
  late final $GameAccountsTable gameAccounts = $GameAccountsTable(this);
  late final $AccountCharactersTable accountCharacters =
      $AccountCharactersTable(this);
  late final $CharacterBuildSnapshotsTable characterBuildSnapshots =
      $CharacterBuildSnapshotsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    gameAccounts,
    accountCharacters,
    characterBuildSnapshots,
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
  ]);
}

typedef $$GameAccountsTableCreateCompanionBuilder =
    GameAccountsCompanion Function({
      Value<int> id,
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
                Value<String> label = const Value.absent(),
                Value<bool> isMain = const Value.absent(),
                Value<String> lookupCharacterName = const Value.absent(),
                Value<int?> representativeCharacterId = const Value.absent(),
                Value<int> displayLimit = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GameAccountsCompanion(
                id: id,
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
                required String label,
                Value<bool> isMain = const Value.absent(),
                required String lookupCharacterName,
                Value<int?> representativeCharacterId = const Value.absent(),
                Value<int> displayLimit = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => GameAccountsCompanion.insert(
                id: id,
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
      required int accountId,
      required String serverName,
      required String characterName,
      required int characterLevel,
      required String characterClassName,
      Value<double?> itemLevel,
      Value<double?> combatPower,
      Value<bool> isVisible,
      Value<int?> displayOrder,
      required DateTime lastSummaryFetchedAt,
    });
typedef $$AccountCharactersTableUpdateCompanionBuilder =
    AccountCharactersCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<String> serverName,
      Value<String> characterName,
      Value<int> characterLevel,
      Value<String> characterClassName,
      Value<double?> itemLevel,
      Value<double?> combatPower,
      Value<bool> isVisible,
      Value<int?> displayOrder,
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

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
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

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
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

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
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
                Value<int> accountId = const Value.absent(),
                Value<String> serverName = const Value.absent(),
                Value<String> characterName = const Value.absent(),
                Value<int> characterLevel = const Value.absent(),
                Value<String> characterClassName = const Value.absent(),
                Value<double?> itemLevel = const Value.absent(),
                Value<double?> combatPower = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<int?> displayOrder = const Value.absent(),
                Value<DateTime> lastSummaryFetchedAt = const Value.absent(),
              }) => AccountCharactersCompanion(
                id: id,
                accountId: accountId,
                serverName: serverName,
                characterName: characterName,
                characterLevel: characterLevel,
                characterClassName: characterClassName,
                itemLevel: itemLevel,
                combatPower: combatPower,
                isVisible: isVisible,
                displayOrder: displayOrder,
                lastSummaryFetchedAt: lastSummaryFetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required String serverName,
                required String characterName,
                required int characterLevel,
                required String characterClassName,
                Value<double?> itemLevel = const Value.absent(),
                Value<double?> combatPower = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<int?> displayOrder = const Value.absent(),
                required DateTime lastSummaryFetchedAt,
              }) => AccountCharactersCompanion.insert(
                id: id,
                accountId: accountId,
                serverName: serverName,
                characterName: characterName,
                characterLevel: characterLevel,
                characterClassName: characterClassName,
                itemLevel: itemLevel,
                combatPower: combatPower,
                isVisible: isVisible,
                displayOrder: displayOrder,
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
              ({accountId = false, characterBuildSnapshotsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (characterBuildSnapshotsRefs) db.characterBuildSnapshots,
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
      PrefetchHooks Function({bool accountId, bool characterBuildSnapshotsRefs})
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
}
