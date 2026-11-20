// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ageLimitMeta = const VerificationMeta(
    'ageLimit',
  );
  @override
  late final GeneratedColumn<int> ageLimit = GeneratedColumn<int>(
    'age_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _isKidMeta = const VerificationMeta('isKid');
  @override
  late final GeneratedColumn<bool> isKid = GeneratedColumn<bool>(
    'is_kid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_kid" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    ageLimit,
    isKid,
    locked,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('age_limit')) {
      context.handle(
        _ageLimitMeta,
        ageLimit.isAcceptableOrUnknown(data['age_limit']!, _ageLimitMeta),
      );
    }
    if (data.containsKey('is_kid')) {
      context.handle(
        _isKidMeta,
        isKid.isAcceptableOrUnknown(data['is_kid']!, _isKidMeta),
      );
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      ageLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age_limit'],
      )!,
      isKid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_kid'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}locked'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final String id;
  final String name;
  final int createdAt;

  /// Limite d'âge (index de `AgeLimit`, v4) ; 4 = adulte, sans filtre.
  final int ageLimit;

  /// Profil enfant (v4) : ni réglages ni changement de profil sans le PIN.
  final bool isKid;

  /// Profil verrouillé (v4) : le PIN parent est demandé pour l'ouvrir.
  final bool locked;
  const Profile({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.ageLimit,
    required this.isKid,
    required this.locked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    map['age_limit'] = Variable<int>(ageLimit);
    map['is_kid'] = Variable<bool>(isKid);
    map['locked'] = Variable<bool>(locked);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      ageLimit: Value(ageLimit),
      isKid: Value(isKid),
      locked: Value(locked),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      ageLimit: serializer.fromJson<int>(json['ageLimit']),
      isKid: serializer.fromJson<bool>(json['isKid']),
      locked: serializer.fromJson<bool>(json['locked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<int>(createdAt),
      'ageLimit': serializer.toJson<int>(ageLimit),
      'isKid': serializer.toJson<bool>(isKid),
      'locked': serializer.toJson<bool>(locked),
    };
  }

  Profile copyWith({
    String? id,
    String? name,
    int? createdAt,
    int? ageLimit,
    bool? isKid,
    bool? locked,
  }) => Profile(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    ageLimit: ageLimit ?? this.ageLimit,
    isKid: isKid ?? this.isKid,
    locked: locked ?? this.locked,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      ageLimit: data.ageLimit.present ? data.ageLimit.value : this.ageLimit,
      isKid: data.isKid.present ? data.isKid.value : this.isKid,
      locked: data.locked.present ? data.locked.value : this.locked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('ageLimit: $ageLimit, ')
          ..write('isKid: $isKid, ')
          ..write('locked: $locked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, ageLimit, isKid, locked);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.ageLimit == this.ageLimit &&
          other.isKid == this.isKid &&
          other.locked == this.locked);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<int> ageLimit;
  final Value<bool> isKid;
  final Value<bool> locked;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.ageLimit = const Value.absent(),
    this.isKid = const Value.absent(),
    this.locked = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String name,
    this.createdAt = const Value.absent(),
    this.ageLimit = const Value.absent(),
    this.isKid = const Value.absent(),
    this.locked = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Profile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<int>? ageLimit,
    Expression<bool>? isKid,
    Expression<bool>? locked,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (ageLimit != null) 'age_limit': ageLimit,
      if (isKid != null) 'is_kid': isKid,
      if (locked != null) 'locked': locked,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? createdAt,
    Value<int>? ageLimit,
    Value<bool>? isKid,
    Value<bool>? locked,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      ageLimit: ageLimit ?? this.ageLimit,
      isKid: isKid ?? this.isKid,
      locked: locked ?? this.locked,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (ageLimit.present) {
      map['age_limit'] = Variable<int>(ageLimit.value);
    }
    if (isKid.present) {
      map['is_kid'] = Variable<bool>(isKid.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('ageLimit: $ageLimit, ')
          ..write('isKid: $isKid, ')
          ..write('locked: $locked, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AddonsTable extends Addons with TableInfo<$AddonsTable, Addon> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AddonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileScopeMeta = const VerificationMeta(
    'profileScope',
  );
  @override
  late final GeneratedColumn<String> profileScope = GeneratedColumn<String>(
    'profile_scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _manifestJsonMeta = const VerificationMeta(
    'manifestJson',
  );
  @override
  late final GeneratedColumn<String> manifestJson = GeneratedColumn<String>(
    'manifest_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secretKeyMeta = const VerificationMeta(
    'secretKey',
  );
  @override
  late final GeneratedColumn<String> secretKey = GeneratedColumn<String>(
    'secret_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlHashMeta = const VerificationMeta(
    'urlHash',
  );
  @override
  late final GeneratedColumn<String> urlHash = GeneratedColumn<String>(
    'url_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileScope,
    position,
    enabled,
    manifestJson,
    secretKey,
    urlHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'addons';
  @override
  VerificationContext validateIntegrity(
    Insertable<Addon> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_scope')) {
      context.handle(
        _profileScopeMeta,
        profileScope.isAcceptableOrUnknown(
          data['profile_scope']!,
          _profileScopeMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('manifest_json')) {
      context.handle(
        _manifestJsonMeta,
        manifestJson.isAcceptableOrUnknown(
          data['manifest_json']!,
          _manifestJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manifestJsonMeta);
    }
    if (data.containsKey('secret_key')) {
      context.handle(
        _secretKeyMeta,
        secretKey.isAcceptableOrUnknown(data['secret_key']!, _secretKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_secretKeyMeta);
    }
    if (data.containsKey('url_hash')) {
      context.handle(
        _urlHashMeta,
        urlHash.isAcceptableOrUnknown(data['url_hash']!, _urlHashMeta),
      );
    } else if (isInserting) {
      context.missing(_urlHashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileScope, urlHash},
  ];
  @override
  Addon map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Addon(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_scope'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      manifestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_json'],
      )!,
      secretKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secret_key'],
      )!,
      urlHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_hash'],
      )!,
    );
  }

  @override
  $AddonsTable createAlias(String alias) {
    return $AddonsTable(attachedDatabase, alias);
  }
}

class Addon extends DataClass implements Insertable<Addon> {
  final String id;
  final String profileScope;
  final int position;
  final bool enabled;
  final String manifestJson;
  final String secretKey;
  final String urlHash;
  const Addon({
    required this.id,
    required this.profileScope,
    required this.position,
    required this.enabled,
    required this.manifestJson,
    required this.secretKey,
    required this.urlHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_scope'] = Variable<String>(profileScope);
    map['position'] = Variable<int>(position);
    map['enabled'] = Variable<bool>(enabled);
    map['manifest_json'] = Variable<String>(manifestJson);
    map['secret_key'] = Variable<String>(secretKey);
    map['url_hash'] = Variable<String>(urlHash);
    return map;
  }

  AddonsCompanion toCompanion(bool nullToAbsent) {
    return AddonsCompanion(
      id: Value(id),
      profileScope: Value(profileScope),
      position: Value(position),
      enabled: Value(enabled),
      manifestJson: Value(manifestJson),
      secretKey: Value(secretKey),
      urlHash: Value(urlHash),
    );
  }

  factory Addon.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Addon(
      id: serializer.fromJson<String>(json['id']),
      profileScope: serializer.fromJson<String>(json['profileScope']),
      position: serializer.fromJson<int>(json['position']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      manifestJson: serializer.fromJson<String>(json['manifestJson']),
      secretKey: serializer.fromJson<String>(json['secretKey']),
      urlHash: serializer.fromJson<String>(json['urlHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileScope': serializer.toJson<String>(profileScope),
      'position': serializer.toJson<int>(position),
      'enabled': serializer.toJson<bool>(enabled),
      'manifestJson': serializer.toJson<String>(manifestJson),
      'secretKey': serializer.toJson<String>(secretKey),
      'urlHash': serializer.toJson<String>(urlHash),
    };
  }

  Addon copyWith({
    String? id,
    String? profileScope,
    int? position,
    bool? enabled,
    String? manifestJson,
    String? secretKey,
    String? urlHash,
  }) => Addon(
    id: id ?? this.id,
    profileScope: profileScope ?? this.profileScope,
    position: position ?? this.position,
    enabled: enabled ?? this.enabled,
    manifestJson: manifestJson ?? this.manifestJson,
    secretKey: secretKey ?? this.secretKey,
    urlHash: urlHash ?? this.urlHash,
  );
  Addon copyWithCompanion(AddonsCompanion data) {
    return Addon(
      id: data.id.present ? data.id.value : this.id,
      profileScope: data.profileScope.present
          ? data.profileScope.value
          : this.profileScope,
      position: data.position.present ? data.position.value : this.position,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      manifestJson: data.manifestJson.present
          ? data.manifestJson.value
          : this.manifestJson,
      secretKey: data.secretKey.present ? data.secretKey.value : this.secretKey,
      urlHash: data.urlHash.present ? data.urlHash.value : this.urlHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Addon(')
          ..write('id: $id, ')
          ..write('profileScope: $profileScope, ')
          ..write('position: $position, ')
          ..write('enabled: $enabled, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('secretKey: $secretKey, ')
          ..write('urlHash: $urlHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileScope,
    position,
    enabled,
    manifestJson,
    secretKey,
    urlHash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Addon &&
          other.id == this.id &&
          other.profileScope == this.profileScope &&
          other.position == this.position &&
          other.enabled == this.enabled &&
          other.manifestJson == this.manifestJson &&
          other.secretKey == this.secretKey &&
          other.urlHash == this.urlHash);
}

class AddonsCompanion extends UpdateCompanion<Addon> {
  final Value<String> id;
  final Value<String> profileScope;
  final Value<int> position;
  final Value<bool> enabled;
  final Value<String> manifestJson;
  final Value<String> secretKey;
  final Value<String> urlHash;
  final Value<int> rowid;
  const AddonsCompanion({
    this.id = const Value.absent(),
    this.profileScope = const Value.absent(),
    this.position = const Value.absent(),
    this.enabled = const Value.absent(),
    this.manifestJson = const Value.absent(),
    this.secretKey = const Value.absent(),
    this.urlHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AddonsCompanion.insert({
    required String id,
    this.profileScope = const Value.absent(),
    required int position,
    this.enabled = const Value.absent(),
    required String manifestJson,
    required String secretKey,
    required String urlHash,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       position = Value(position),
       manifestJson = Value(manifestJson),
       secretKey = Value(secretKey),
       urlHash = Value(urlHash);
  static Insertable<Addon> custom({
    Expression<String>? id,
    Expression<String>? profileScope,
    Expression<int>? position,
    Expression<bool>? enabled,
    Expression<String>? manifestJson,
    Expression<String>? secretKey,
    Expression<String>? urlHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileScope != null) 'profile_scope': profileScope,
      if (position != null) 'position': position,
      if (enabled != null) 'enabled': enabled,
      if (manifestJson != null) 'manifest_json': manifestJson,
      if (secretKey != null) 'secret_key': secretKey,
      if (urlHash != null) 'url_hash': urlHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AddonsCompanion copyWith({
    Value<String>? id,
    Value<String>? profileScope,
    Value<int>? position,
    Value<bool>? enabled,
    Value<String>? manifestJson,
    Value<String>? secretKey,
    Value<String>? urlHash,
    Value<int>? rowid,
  }) {
    return AddonsCompanion(
      id: id ?? this.id,
      profileScope: profileScope ?? this.profileScope,
      position: position ?? this.position,
      enabled: enabled ?? this.enabled,
      manifestJson: manifestJson ?? this.manifestJson,
      secretKey: secretKey ?? this.secretKey,
      urlHash: urlHash ?? this.urlHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileScope.present) {
      map['profile_scope'] = Variable<String>(profileScope.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (manifestJson.present) {
      map['manifest_json'] = Variable<String>(manifestJson.value);
    }
    if (secretKey.present) {
      map['secret_key'] = Variable<String>(secretKey.value);
    }
    if (urlHash.present) {
      map['url_hash'] = Variable<String>(urlHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AddonsCompanion(')
          ..write('id: $id, ')
          ..write('profileScope: $profileScope, ')
          ..write('position: $position, ')
          ..write('enabled: $enabled, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('secretKey: $secretKey, ')
          ..write('urlHash: $urlHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryItemsTable extends LibraryItems
    with TableInfo<$LibraryItemsTable, LibraryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
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
  static const VerificationMeta _metaJsonMeta = const VerificationMeta(
    'metaJson',
  );
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
    'meta_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _certificationMeta = const VerificationMeta(
    'certification',
  );
  @override
  late final GeneratedColumn<String> certification = GeneratedColumn<String>(
    'certification',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    itemId,
    type,
    metaJson,
    addedAt,
    certification,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('meta_json')) {
      context.handle(
        _metaJsonMeta,
        metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('certification')) {
      context.handle(
        _certificationMeta,
        certification.isAcceptableOrUnknown(
          data['certification']!,
          _certificationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, itemId};
  @override
  LibraryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryItem(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      metaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_json'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      certification: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}certification'],
      ),
    );
  }

  @override
  $LibraryItemsTable createAlias(String alias) {
    return $LibraryItemsTable(attachedDatabase, alias);
  }
}

class LibraryItem extends DataClass implements Insertable<LibraryItem> {
  final String profileId;
  final String itemId;
  final String type;
  final String metaJson;
  final int addedAt;

  /// Certification d'âge du titre (v6), pour le filtre des profils enfants ;
  /// nulle si inconnue.
  final String? certification;
  const LibraryItem({
    required this.profileId,
    required this.itemId,
    required this.type,
    required this.metaJson,
    required this.addedAt,
    this.certification,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['item_id'] = Variable<String>(itemId);
    map['type'] = Variable<String>(type);
    map['meta_json'] = Variable<String>(metaJson);
    map['added_at'] = Variable<int>(addedAt);
    if (!nullToAbsent || certification != null) {
      map['certification'] = Variable<String>(certification);
    }
    return map;
  }

  LibraryItemsCompanion toCompanion(bool nullToAbsent) {
    return LibraryItemsCompanion(
      profileId: Value(profileId),
      itemId: Value(itemId),
      type: Value(type),
      metaJson: Value(metaJson),
      addedAt: Value(addedAt),
      certification: certification == null && nullToAbsent
          ? const Value.absent()
          : Value(certification),
    );
  }

  factory LibraryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryItem(
      profileId: serializer.fromJson<String>(json['profileId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      type: serializer.fromJson<String>(json['type']),
      metaJson: serializer.fromJson<String>(json['metaJson']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      certification: serializer.fromJson<String?>(json['certification']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'itemId': serializer.toJson<String>(itemId),
      'type': serializer.toJson<String>(type),
      'metaJson': serializer.toJson<String>(metaJson),
      'addedAt': serializer.toJson<int>(addedAt),
      'certification': serializer.toJson<String?>(certification),
    };
  }

  LibraryItem copyWith({
    String? profileId,
    String? itemId,
    String? type,
    String? metaJson,
    int? addedAt,
    Value<String?> certification = const Value.absent(),
  }) => LibraryItem(
    profileId: profileId ?? this.profileId,
    itemId: itemId ?? this.itemId,
    type: type ?? this.type,
    metaJson: metaJson ?? this.metaJson,
    addedAt: addedAt ?? this.addedAt,
    certification: certification.present
        ? certification.value
        : this.certification,
  );
  LibraryItem copyWithCompanion(LibraryItemsCompanion data) {
    return LibraryItem(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      type: data.type.present ? data.type.value : this.type,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      certification: data.certification.present
          ? data.certification.value
          : this.certification,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryItem(')
          ..write('profileId: $profileId, ')
          ..write('itemId: $itemId, ')
          ..write('type: $type, ')
          ..write('metaJson: $metaJson, ')
          ..write('addedAt: $addedAt, ')
          ..write('certification: $certification')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(profileId, itemId, type, metaJson, addedAt, certification);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryItem &&
          other.profileId == this.profileId &&
          other.itemId == this.itemId &&
          other.type == this.type &&
          other.metaJson == this.metaJson &&
          other.addedAt == this.addedAt &&
          other.certification == this.certification);
}

class LibraryItemsCompanion extends UpdateCompanion<LibraryItem> {
  final Value<String> profileId;
  final Value<String> itemId;
  final Value<String> type;
  final Value<String> metaJson;
  final Value<int> addedAt;
  final Value<String?> certification;
  final Value<int> rowid;
  const LibraryItemsCompanion({
    this.profileId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.type = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.certification = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryItemsCompanion.insert({
    this.profileId = const Value.absent(),
    required String itemId,
    required String type,
    this.metaJson = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.certification = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       type = Value(type);
  static Insertable<LibraryItem> custom({
    Expression<String>? profileId,
    Expression<String>? itemId,
    Expression<String>? type,
    Expression<String>? metaJson,
    Expression<int>? addedAt,
    Expression<String>? certification,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (itemId != null) 'item_id': itemId,
      if (type != null) 'type': type,
      if (metaJson != null) 'meta_json': metaJson,
      if (addedAt != null) 'added_at': addedAt,
      if (certification != null) 'certification': certification,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryItemsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? itemId,
    Value<String>? type,
    Value<String>? metaJson,
    Value<int>? addedAt,
    Value<String?>? certification,
    Value<int>? rowid,
  }) {
    return LibraryItemsCompanion(
      profileId: profileId ?? this.profileId,
      itemId: itemId ?? this.itemId,
      type: type ?? this.type,
      metaJson: metaJson ?? this.metaJson,
      addedAt: addedAt ?? this.addedAt,
      certification: certification ?? this.certification,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (certification.present) {
      map['certification'] = Variable<String>(certification.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryItemsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('itemId: $itemId, ')
          ..write('type: $type, ')
          ..write('metaJson: $metaJson, ')
          ..write('addedAt: $addedAt, ')
          ..write('certification: $certification, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressTable extends Progress
    with TableInfo<$ProgressTable, ProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _metaIdMeta = const VerificationMeta('metaId');
  @override
  late final GeneratedColumn<String> metaId = GeneratedColumn<String>(
    'meta_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _watchedMeta = const VerificationMeta(
    'watched',
  );
  @override
  late final GeneratedColumn<bool> watched = GeneratedColumn<bool>(
    'watched',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("watched" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _certificationMeta = const VerificationMeta(
    'certification',
  );
  @override
  late final GeneratedColumn<String> certification = GeneratedColumn<String>(
    'certification',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posterMeta = const VerificationMeta('poster');
  @override
  late final GeneratedColumn<String> poster = GeneratedColumn<String>(
    'poster',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamAddonIdMeta = const VerificationMeta(
    'streamAddonId',
  );
  @override
  late final GeneratedColumn<String> streamAddonId = GeneratedColumn<String>(
    'stream_addon_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamKeyMeta = const VerificationMeta(
    'streamKey',
  );
  @override
  late final GeneratedColumn<String> streamKey = GeneratedColumn<String>(
    'stream_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    itemId,
    positionMs,
    durationMs,
    updatedAt,
    metaId,
    watched,
    certification,
    title,
    poster,
    mediaType,
    season,
    episode,
    streamAddonId,
    streamKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('meta_id')) {
      context.handle(
        _metaIdMeta,
        metaId.isAcceptableOrUnknown(data['meta_id']!, _metaIdMeta),
      );
    }
    if (data.containsKey('watched')) {
      context.handle(
        _watchedMeta,
        watched.isAcceptableOrUnknown(data['watched']!, _watchedMeta),
      );
    }
    if (data.containsKey('certification')) {
      context.handle(
        _certificationMeta,
        certification.isAcceptableOrUnknown(
          data['certification']!,
          _certificationMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('poster')) {
      context.handle(
        _posterMeta,
        poster.isAcceptableOrUnknown(data['poster']!, _posterMeta),
      );
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    }
    if (data.containsKey('stream_addon_id')) {
      context.handle(
        _streamAddonIdMeta,
        streamAddonId.isAcceptableOrUnknown(
          data['stream_addon_id']!,
          _streamAddonIdMeta,
        ),
      );
    }
    if (data.containsKey('stream_key')) {
      context.handle(
        _streamKeyMeta,
        streamKey.isAcceptableOrUnknown(data['stream_key']!, _streamKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, itemId};
  @override
  ProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressData(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      metaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_id'],
      )!,
      watched: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}watched'],
      )!,
      certification: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}certification'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      poster: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster'],
      ),
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      ),
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      ),
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode'],
      ),
      streamAddonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_addon_id'],
      ),
      streamKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_key'],
      ),
    );
  }

  @override
  $ProgressTable createAlias(String alias) {
    return $ProgressTable(attachedDatabase, alias);
  }
}

class ProgressData extends DataClass implements Insertable<ProgressData> {
  final String profileId;
  final String itemId;
  final int positionMs;
  final int durationMs;
  final int updatedAt;

  /// Titre ou série d'appartenance de [itemId] (v3) ; vide pour les lignes
  /// antérieures.
  final String metaId;

  /// Marqué comme vu (≥ 90 %, v3).
  final bool watched;

  /// Certification d'âge du titre (v5), pour le filtre des profils enfants ;
  /// nulle si inconnue.
  final String? certification;

  /// Titre affiché dans « Continuer » (v12) : mémorisé au moment de la lecture
  /// pour ne jamais afficher un identifiant brut ; nul pour les anciennes
  /// lignes (repli sur une requête meta).
  final String? title;

  /// Adresse de l'affiche (v12).
  final String? poster;

  /// Type du titre : `movie`, `series`… (v12).
  final String? mediaType;

  /// Saison et épisode de [itemId] pour une série (v12).
  final int? season;
  final int? episode;

  /// Identifiant de stockage (opaque, interne) de l'addon dont venait le flux
  /// regardé (v13) ; nul pour les anciennes lignes.
  final String? streamAddonId;

  /// Identité NON sensible du flux regardé (v13) : `t:<infoHash>:<fileIdx>`
  /// ou `u:<SHA-256 de l'URL normalisée>`. Jamais l'URL (clé d'addon).
  final String? streamKey;
  const ProgressData({
    required this.profileId,
    required this.itemId,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
    required this.metaId,
    required this.watched,
    this.certification,
    this.title,
    this.poster,
    this.mediaType,
    this.season,
    this.episode,
    this.streamAddonId,
    this.streamKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['item_id'] = Variable<String>(itemId);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['updated_at'] = Variable<int>(updatedAt);
    map['meta_id'] = Variable<String>(metaId);
    map['watched'] = Variable<bool>(watched);
    if (!nullToAbsent || certification != null) {
      map['certification'] = Variable<String>(certification);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || poster != null) {
      map['poster'] = Variable<String>(poster);
    }
    if (!nullToAbsent || mediaType != null) {
      map['media_type'] = Variable<String>(mediaType);
    }
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<int>(season);
    }
    if (!nullToAbsent || episode != null) {
      map['episode'] = Variable<int>(episode);
    }
    if (!nullToAbsent || streamAddonId != null) {
      map['stream_addon_id'] = Variable<String>(streamAddonId);
    }
    if (!nullToAbsent || streamKey != null) {
      map['stream_key'] = Variable<String>(streamKey);
    }
    return map;
  }

  ProgressCompanion toCompanion(bool nullToAbsent) {
    return ProgressCompanion(
      profileId: Value(profileId),
      itemId: Value(itemId),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      updatedAt: Value(updatedAt),
      metaId: Value(metaId),
      watched: Value(watched),
      certification: certification == null && nullToAbsent
          ? const Value.absent()
          : Value(certification),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      poster: poster == null && nullToAbsent
          ? const Value.absent()
          : Value(poster),
      mediaType: mediaType == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaType),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      episode: episode == null && nullToAbsent
          ? const Value.absent()
          : Value(episode),
      streamAddonId: streamAddonId == null && nullToAbsent
          ? const Value.absent()
          : Value(streamAddonId),
      streamKey: streamKey == null && nullToAbsent
          ? const Value.absent()
          : Value(streamKey),
    );
  }

  factory ProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressData(
      profileId: serializer.fromJson<String>(json['profileId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      metaId: serializer.fromJson<String>(json['metaId']),
      watched: serializer.fromJson<bool>(json['watched']),
      certification: serializer.fromJson<String?>(json['certification']),
      title: serializer.fromJson<String?>(json['title']),
      poster: serializer.fromJson<String?>(json['poster']),
      mediaType: serializer.fromJson<String?>(json['mediaType']),
      season: serializer.fromJson<int?>(json['season']),
      episode: serializer.fromJson<int?>(json['episode']),
      streamAddonId: serializer.fromJson<String?>(json['streamAddonId']),
      streamKey: serializer.fromJson<String?>(json['streamKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'itemId': serializer.toJson<String>(itemId),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'metaId': serializer.toJson<String>(metaId),
      'watched': serializer.toJson<bool>(watched),
      'certification': serializer.toJson<String?>(certification),
      'title': serializer.toJson<String?>(title),
      'poster': serializer.toJson<String?>(poster),
      'mediaType': serializer.toJson<String?>(mediaType),
      'season': serializer.toJson<int?>(season),
      'episode': serializer.toJson<int?>(episode),
      'streamAddonId': serializer.toJson<String?>(streamAddonId),
      'streamKey': serializer.toJson<String?>(streamKey),
    };
  }

  ProgressData copyWith({
    String? profileId,
    String? itemId,
    int? positionMs,
    int? durationMs,
    int? updatedAt,
    String? metaId,
    bool? watched,
    Value<String?> certification = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> poster = const Value.absent(),
    Value<String?> mediaType = const Value.absent(),
    Value<int?> season = const Value.absent(),
    Value<int?> episode = const Value.absent(),
    Value<String?> streamAddonId = const Value.absent(),
    Value<String?> streamKey = const Value.absent(),
  }) => ProgressData(
    profileId: profileId ?? this.profileId,
    itemId: itemId ?? this.itemId,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
    metaId: metaId ?? this.metaId,
    watched: watched ?? this.watched,
    certification: certification.present
        ? certification.value
        : this.certification,
    title: title.present ? title.value : this.title,
    poster: poster.present ? poster.value : this.poster,
    mediaType: mediaType.present ? mediaType.value : this.mediaType,
    season: season.present ? season.value : this.season,
    episode: episode.present ? episode.value : this.episode,
    streamAddonId: streamAddonId.present
        ? streamAddonId.value
        : this.streamAddonId,
    streamKey: streamKey.present ? streamKey.value : this.streamKey,
  );
  ProgressData copyWithCompanion(ProgressCompanion data) {
    return ProgressData(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      metaId: data.metaId.present ? data.metaId.value : this.metaId,
      watched: data.watched.present ? data.watched.value : this.watched,
      certification: data.certification.present
          ? data.certification.value
          : this.certification,
      title: data.title.present ? data.title.value : this.title,
      poster: data.poster.present ? data.poster.value : this.poster,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      streamAddonId: data.streamAddonId.present
          ? data.streamAddonId.value
          : this.streamAddonId,
      streamKey: data.streamKey.present ? data.streamKey.value : this.streamKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressData(')
          ..write('profileId: $profileId, ')
          ..write('itemId: $itemId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('metaId: $metaId, ')
          ..write('watched: $watched, ')
          ..write('certification: $certification, ')
          ..write('title: $title, ')
          ..write('poster: $poster, ')
          ..write('mediaType: $mediaType, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('streamAddonId: $streamAddonId, ')
          ..write('streamKey: $streamKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    itemId,
    positionMs,
    durationMs,
    updatedAt,
    metaId,
    watched,
    certification,
    title,
    poster,
    mediaType,
    season,
    episode,
    streamAddonId,
    streamKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressData &&
          other.profileId == this.profileId &&
          other.itemId == this.itemId &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.updatedAt == this.updatedAt &&
          other.metaId == this.metaId &&
          other.watched == this.watched &&
          other.certification == this.certification &&
          other.title == this.title &&
          other.poster == this.poster &&
          other.mediaType == this.mediaType &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.streamAddonId == this.streamAddonId &&
          other.streamKey == this.streamKey);
}

class ProgressCompanion extends UpdateCompanion<ProgressData> {
  final Value<String> profileId;
  final Value<String> itemId;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<int> updatedAt;
  final Value<String> metaId;
  final Value<bool> watched;
  final Value<String?> certification;
  final Value<String?> title;
  final Value<String?> poster;
  final Value<String?> mediaType;
  final Value<int?> season;
  final Value<int?> episode;
  final Value<String?> streamAddonId;
  final Value<String?> streamKey;
  final Value<int> rowid;
  const ProgressCompanion({
    this.profileId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.metaId = const Value.absent(),
    this.watched = const Value.absent(),
    this.certification = const Value.absent(),
    this.title = const Value.absent(),
    this.poster = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.streamAddonId = const Value.absent(),
    this.streamKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressCompanion.insert({
    this.profileId = const Value.absent(),
    required String itemId,
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.metaId = const Value.absent(),
    this.watched = const Value.absent(),
    this.certification = const Value.absent(),
    this.title = const Value.absent(),
    this.poster = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.streamAddonId = const Value.absent(),
    this.streamKey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId);
  static Insertable<ProgressData> custom({
    Expression<String>? profileId,
    Expression<String>? itemId,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<int>? updatedAt,
    Expression<String>? metaId,
    Expression<bool>? watched,
    Expression<String>? certification,
    Expression<String>? title,
    Expression<String>? poster,
    Expression<String>? mediaType,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<String>? streamAddonId,
    Expression<String>? streamKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (itemId != null) 'item_id': itemId,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (metaId != null) 'meta_id': metaId,
      if (watched != null) 'watched': watched,
      if (certification != null) 'certification': certification,
      if (title != null) 'title': title,
      if (poster != null) 'poster': poster,
      if (mediaType != null) 'media_type': mediaType,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (streamAddonId != null) 'stream_addon_id': streamAddonId,
      if (streamKey != null) 'stream_key': streamKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressCompanion copyWith({
    Value<String>? profileId,
    Value<String>? itemId,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<int>? updatedAt,
    Value<String>? metaId,
    Value<bool>? watched,
    Value<String?>? certification,
    Value<String?>? title,
    Value<String?>? poster,
    Value<String?>? mediaType,
    Value<int?>? season,
    Value<int?>? episode,
    Value<String?>? streamAddonId,
    Value<String?>? streamKey,
    Value<int>? rowid,
  }) {
    return ProgressCompanion(
      profileId: profileId ?? this.profileId,
      itemId: itemId ?? this.itemId,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      metaId: metaId ?? this.metaId,
      watched: watched ?? this.watched,
      certification: certification ?? this.certification,
      title: title ?? this.title,
      poster: poster ?? this.poster,
      mediaType: mediaType ?? this.mediaType,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      streamAddonId: streamAddonId ?? this.streamAddonId,
      streamKey: streamKey ?? this.streamKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (metaId.present) {
      map['meta_id'] = Variable<String>(metaId.value);
    }
    if (watched.present) {
      map['watched'] = Variable<bool>(watched.value);
    }
    if (certification.present) {
      map['certification'] = Variable<String>(certification.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (poster.present) {
      map['poster'] = Variable<String>(poster.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (streamAddonId.present) {
      map['stream_addon_id'] = Variable<String>(streamAddonId.value);
    }
    if (streamKey.present) {
      map['stream_key'] = Variable<String>(streamKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressCompanion(')
          ..write('profileId: $profileId, ')
          ..write('itemId: $itemId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('metaId: $metaId, ')
          ..write('watched: $watched, ')
          ..write('certification: $certification, ')
          ..write('title: $title, ')
          ..write('poster: $poster, ')
          ..write('mediaType: $mediaType, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('streamAddonId: $streamAddonId, ')
          ..write('streamKey: $streamKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TitleSettingsTableTable extends TitleSettingsTable
    with TableInfo<$TitleSettingsTableTable, TitleSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TitleSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metaIdMeta = const VerificationMeta('metaId');
  @override
  late final GeneratedColumn<String> metaId = GeneratedColumn<String>(
    'meta_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [profileId, metaId, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'title_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<TitleSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('meta_id')) {
      context.handle(
        _metaIdMeta,
        metaId.isAcceptableOrUnknown(data['meta_id']!, _metaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_metaIdMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, metaId};
  @override
  TitleSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TitleSettingsRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      metaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $TitleSettingsTableTable createAlias(String alias) {
    return $TitleSettingsTableTable(attachedDatabase, alias);
  }
}

class TitleSettingsRow extends DataClass
    implements Insertable<TitleSettingsRow> {
  final String profileId;
  final String metaId;
  final String json;
  const TitleSettingsRow({
    required this.profileId,
    required this.metaId,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['meta_id'] = Variable<String>(metaId);
    map['json'] = Variable<String>(json);
    return map;
  }

  TitleSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return TitleSettingsTableCompanion(
      profileId: Value(profileId),
      metaId: Value(metaId),
      json: Value(json),
    );
  }

  factory TitleSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TitleSettingsRow(
      profileId: serializer.fromJson<String>(json['profileId']),
      metaId: serializer.fromJson<String>(json['metaId']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'metaId': serializer.toJson<String>(metaId),
      'json': serializer.toJson<String>(json),
    };
  }

  TitleSettingsRow copyWith({
    String? profileId,
    String? metaId,
    String? json,
  }) => TitleSettingsRow(
    profileId: profileId ?? this.profileId,
    metaId: metaId ?? this.metaId,
    json: json ?? this.json,
  );
  TitleSettingsRow copyWithCompanion(TitleSettingsTableCompanion data) {
    return TitleSettingsRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      metaId: data.metaId.present ? data.metaId.value : this.metaId,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TitleSettingsRow(')
          ..write('profileId: $profileId, ')
          ..write('metaId: $metaId, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, metaId, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TitleSettingsRow &&
          other.profileId == this.profileId &&
          other.metaId == this.metaId &&
          other.json == this.json);
}

class TitleSettingsTableCompanion extends UpdateCompanion<TitleSettingsRow> {
  final Value<String> profileId;
  final Value<String> metaId;
  final Value<String> json;
  final Value<int> rowid;
  const TitleSettingsTableCompanion({
    this.profileId = const Value.absent(),
    this.metaId = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TitleSettingsTableCompanion.insert({
    required String profileId,
    required String metaId,
    required String json,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       metaId = Value(metaId),
       json = Value(json);
  static Insertable<TitleSettingsRow> custom({
    Expression<String>? profileId,
    Expression<String>? metaId,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (metaId != null) 'meta_id': metaId,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TitleSettingsTableCompanion copyWith({
    Value<String>? profileId,
    Value<String>? metaId,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return TitleSettingsTableCompanion(
      profileId: profileId ?? this.profileId,
      metaId: metaId ?? this.metaId,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (metaId.present) {
      map['meta_id'] = Variable<String>(metaId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TitleSettingsTableCompanion(')
          ..write('profileId: $profileId, ')
          ..write('metaId: $metaId, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFoldersTable extends LocalFolders
    with TableInfo<$LocalFoldersTable, LocalFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastScanAtMeta = const VerificationMeta(
    'lastScanAt',
  );
  @override
  late final GeneratedColumn<int> lastScanAt = GeneratedColumn<int>(
    'last_scan_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [path, addedAt, lastScanAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('last_scan_at')) {
      context.handle(
        _lastScanAtMeta,
        lastScanAt.isAcceptableOrUnknown(
          data['last_scan_at']!,
          _lastScanAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  LocalFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFolder(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      lastScanAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_scan_at'],
      )!,
    );
  }

  @override
  $LocalFoldersTable createAlias(String alias) {
    return $LocalFoldersTable(attachedDatabase, alias);
  }
}

class LocalFolder extends DataClass implements Insertable<LocalFolder> {
  final String path;
  final int addedAt;

  /// Dernière analyse réussie (ms) ; 0 si jamais.
  final int lastScanAt;
  const LocalFolder({
    required this.path,
    required this.addedAt,
    required this.lastScanAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['added_at'] = Variable<int>(addedAt);
    map['last_scan_at'] = Variable<int>(lastScanAt);
    return map;
  }

  LocalFoldersCompanion toCompanion(bool nullToAbsent) {
    return LocalFoldersCompanion(
      path: Value(path),
      addedAt: Value(addedAt),
      lastScanAt: Value(lastScanAt),
    );
  }

  factory LocalFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFolder(
      path: serializer.fromJson<String>(json['path']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      lastScanAt: serializer.fromJson<int>(json['lastScanAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'addedAt': serializer.toJson<int>(addedAt),
      'lastScanAt': serializer.toJson<int>(lastScanAt),
    };
  }

  LocalFolder copyWith({String? path, int? addedAt, int? lastScanAt}) =>
      LocalFolder(
        path: path ?? this.path,
        addedAt: addedAt ?? this.addedAt,
        lastScanAt: lastScanAt ?? this.lastScanAt,
      );
  LocalFolder copyWithCompanion(LocalFoldersCompanion data) {
    return LocalFolder(
      path: data.path.present ? data.path.value : this.path,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastScanAt: data.lastScanAt.present
          ? data.lastScanAt.value
          : this.lastScanAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFolder(')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScanAt: $lastScanAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, addedAt, lastScanAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFolder &&
          other.path == this.path &&
          other.addedAt == this.addedAt &&
          other.lastScanAt == this.lastScanAt);
}

class LocalFoldersCompanion extends UpdateCompanion<LocalFolder> {
  final Value<String> path;
  final Value<int> addedAt;
  final Value<int> lastScanAt;
  final Value<int> rowid;
  const LocalFoldersCompanion({
    this.path = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastScanAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFoldersCompanion.insert({
    required String path,
    this.addedAt = const Value.absent(),
    this.lastScanAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path);
  static Insertable<LocalFolder> custom({
    Expression<String>? path,
    Expression<int>? addedAt,
    Expression<int>? lastScanAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (addedAt != null) 'added_at': addedAt,
      if (lastScanAt != null) 'last_scan_at': lastScanAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFoldersCompanion copyWith({
    Value<String>? path,
    Value<int>? addedAt,
    Value<int>? lastScanAt,
    Value<int>? rowid,
  }) {
    return LocalFoldersCompanion(
      path: path ?? this.path,
      addedAt: addedAt ?? this.addedAt,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (lastScanAt.present) {
      map['last_scan_at'] = Variable<int>(lastScanAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFoldersCompanion(')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScanAt: $lastScanAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalItemsTable extends LocalItems
    with TableInfo<$LocalItemsTable, LocalItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleOverrideMeta = const VerificationMeta(
    'titleOverride',
  );
  @override
  late final GeneratedColumn<String> titleOverride = GeneratedColumn<String>(
    'title_override',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<int> modifiedAt = GeneratedColumn<int>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    folderPath,
    path,
    fileName,
    title,
    titleOverride,
    year,
    season,
    episode,
    sizeBytes,
    modifiedAt,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    } else if (isInserting) {
      context.missing(_folderPathMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('title_override')) {
      context.handle(
        _titleOverrideMeta,
        titleOverride.isAcceptableOrUnknown(
          data['title_override']!,
          _titleOverrideMeta,
        ),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      folderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_path'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_override'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      ),
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_at'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $LocalItemsTable createAlias(String alias) {
    return $LocalItemsTable(attachedDatabase, alias);
  }
}

class LocalItem extends DataClass implements Insertable<LocalItem> {
  final String id;
  final String folderPath;
  final String path;
  final String fileName;
  final String title;
  final String? titleOverride;
  final int? year;
  final int? season;
  final int? episode;
  final int sizeBytes;
  final int modifiedAt;
  final int addedAt;
  const LocalItem({
    required this.id,
    required this.folderPath,
    required this.path,
    required this.fileName,
    required this.title,
    this.titleOverride,
    this.year,
    this.season,
    this.episode,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['folder_path'] = Variable<String>(folderPath);
    map['path'] = Variable<String>(path);
    map['file_name'] = Variable<String>(fileName);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || titleOverride != null) {
      map['title_override'] = Variable<String>(titleOverride);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<int>(season);
    }
    if (!nullToAbsent || episode != null) {
      map['episode'] = Variable<int>(episode);
    }
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['modified_at'] = Variable<int>(modifiedAt);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  LocalItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalItemsCompanion(
      id: Value(id),
      folderPath: Value(folderPath),
      path: Value(path),
      fileName: Value(fileName),
      title: Value(title),
      titleOverride: titleOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(titleOverride),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      episode: episode == null && nullToAbsent
          ? const Value.absent()
          : Value(episode),
      sizeBytes: Value(sizeBytes),
      modifiedAt: Value(modifiedAt),
      addedAt: Value(addedAt),
    );
  }

  factory LocalItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalItem(
      id: serializer.fromJson<String>(json['id']),
      folderPath: serializer.fromJson<String>(json['folderPath']),
      path: serializer.fromJson<String>(json['path']),
      fileName: serializer.fromJson<String>(json['fileName']),
      title: serializer.fromJson<String>(json['title']),
      titleOverride: serializer.fromJson<String?>(json['titleOverride']),
      year: serializer.fromJson<int?>(json['year']),
      season: serializer.fromJson<int?>(json['season']),
      episode: serializer.fromJson<int?>(json['episode']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      modifiedAt: serializer.fromJson<int>(json['modifiedAt']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'folderPath': serializer.toJson<String>(folderPath),
      'path': serializer.toJson<String>(path),
      'fileName': serializer.toJson<String>(fileName),
      'title': serializer.toJson<String>(title),
      'titleOverride': serializer.toJson<String?>(titleOverride),
      'year': serializer.toJson<int?>(year),
      'season': serializer.toJson<int?>(season),
      'episode': serializer.toJson<int?>(episode),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'modifiedAt': serializer.toJson<int>(modifiedAt),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  LocalItem copyWith({
    String? id,
    String? folderPath,
    String? path,
    String? fileName,
    String? title,
    Value<String?> titleOverride = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<int?> season = const Value.absent(),
    Value<int?> episode = const Value.absent(),
    int? sizeBytes,
    int? modifiedAt,
    int? addedAt,
  }) => LocalItem(
    id: id ?? this.id,
    folderPath: folderPath ?? this.folderPath,
    path: path ?? this.path,
    fileName: fileName ?? this.fileName,
    title: title ?? this.title,
    titleOverride: titleOverride.present
        ? titleOverride.value
        : this.titleOverride,
    year: year.present ? year.value : this.year,
    season: season.present ? season.value : this.season,
    episode: episode.present ? episode.value : this.episode,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    addedAt: addedAt ?? this.addedAt,
  );
  LocalItem copyWithCompanion(LocalItemsCompanion data) {
    return LocalItem(
      id: data.id.present ? data.id.value : this.id,
      folderPath: data.folderPath.present
          ? data.folderPath.value
          : this.folderPath,
      path: data.path.present ? data.path.value : this.path,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      title: data.title.present ? data.title.value : this.title,
      titleOverride: data.titleOverride.present
          ? data.titleOverride.value
          : this.titleOverride,
      year: data.year.present ? data.year.value : this.year,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalItem(')
          ..write('id: $id, ')
          ..write('folderPath: $folderPath, ')
          ..write('path: $path, ')
          ..write('fileName: $fileName, ')
          ..write('title: $title, ')
          ..write('titleOverride: $titleOverride, ')
          ..write('year: $year, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    folderPath,
    path,
    fileName,
    title,
    titleOverride,
    year,
    season,
    episode,
    sizeBytes,
    modifiedAt,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalItem &&
          other.id == this.id &&
          other.folderPath == this.folderPath &&
          other.path == this.path &&
          other.fileName == this.fileName &&
          other.title == this.title &&
          other.titleOverride == this.titleOverride &&
          other.year == this.year &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.sizeBytes == this.sizeBytes &&
          other.modifiedAt == this.modifiedAt &&
          other.addedAt == this.addedAt);
}

class LocalItemsCompanion extends UpdateCompanion<LocalItem> {
  final Value<String> id;
  final Value<String> folderPath;
  final Value<String> path;
  final Value<String> fileName;
  final Value<String> title;
  final Value<String?> titleOverride;
  final Value<int?> year;
  final Value<int?> season;
  final Value<int?> episode;
  final Value<int> sizeBytes;
  final Value<int> modifiedAt;
  final Value<int> addedAt;
  final Value<int> rowid;
  const LocalItemsCompanion({
    this.id = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.path = const Value.absent(),
    this.fileName = const Value.absent(),
    this.title = const Value.absent(),
    this.titleOverride = const Value.absent(),
    this.year = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalItemsCompanion.insert({
    required String id,
    required String folderPath,
    required String path,
    required String fileName,
    required String title,
    this.titleOverride = const Value.absent(),
    this.year = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       folderPath = Value(folderPath),
       path = Value(path),
       fileName = Value(fileName),
       title = Value(title);
  static Insertable<LocalItem> custom({
    Expression<String>? id,
    Expression<String>? folderPath,
    Expression<String>? path,
    Expression<String>? fileName,
    Expression<String>? title,
    Expression<String>? titleOverride,
    Expression<int>? year,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<int>? sizeBytes,
    Expression<int>? modifiedAt,
    Expression<int>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderPath != null) 'folder_path': folderPath,
      if (path != null) 'path': path,
      if (fileName != null) 'file_name': fileName,
      if (title != null) 'title': title,
      if (titleOverride != null) 'title_override': titleOverride,
      if (year != null) 'year': year,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? folderPath,
    Value<String>? path,
    Value<String>? fileName,
    Value<String>? title,
    Value<String?>? titleOverride,
    Value<int?>? year,
    Value<int?>? season,
    Value<int?>? episode,
    Value<int>? sizeBytes,
    Value<int>? modifiedAt,
    Value<int>? addedAt,
    Value<int>? rowid,
  }) {
    return LocalItemsCompanion(
      id: id ?? this.id,
      folderPath: folderPath ?? this.folderPath,
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      title: title ?? this.title,
      titleOverride: titleOverride ?? this.titleOverride,
      year: year ?? this.year,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleOverride.present) {
      map['title_override'] = Variable<String>(titleOverride.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<int>(modifiedAt.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalItemsCompanion(')
          ..write('id: $id, ')
          ..write('folderPath: $folderPath, ')
          ..write('path: $path, ')
          ..write('fileName: $fileName, ')
          ..write('title: $title, ')
          ..write('titleOverride: $titleOverride, ')
          ..write('year: $year, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScrobbleQueueTableTable extends ScrobbleQueueTable
    with TableInfo<$ScrobbleQueueTableTable, ScrobbleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScrobbleQueueTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackerIdMeta = const VerificationMeta(
    'trackerId',
  );
  @override
  late final GeneratedColumn<String> trackerId = GeneratedColumn<String>(
    'tracker_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventJsonMeta = const VerificationMeta(
    'eventJson',
  );
  @override
  late final GeneratedColumn<String> eventJson = GeneratedColumn<String>(
    'event_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<int> nextAttemptAt = GeneratedColumn<int>(
    'next_attempt_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    trackerId,
    eventJson,
    attempts,
    nextAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scrobble_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScrobbleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('tracker_id')) {
      context.handle(
        _trackerIdMeta,
        trackerId.isAcceptableOrUnknown(data['tracker_id']!, _trackerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackerIdMeta);
    }
    if (data.containsKey('event_json')) {
      context.handle(
        _eventJsonMeta,
        eventJson.isAcceptableOrUnknown(data['event_json']!, _eventJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_eventJsonMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScrobbleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScrobbleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      trackerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tracker_id'],
      )!,
      eventJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_json'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at'],
      )!,
    );
  }

  @override
  $ScrobbleQueueTableTable createAlias(String alias) {
    return $ScrobbleQueueTableTable(attachedDatabase, alias);
  }
}

class ScrobbleRow extends DataClass implements Insertable<ScrobbleRow> {
  final int id;
  final String profileId;
  final String trackerId;

  /// `ScrobbleEvent.toJson` (identifiant IMDb et avancement, sans secret).
  final String eventJson;
  final int attempts;

  /// Prochain essai (ms depuis l'epoch).
  final int nextAttemptAt;
  const ScrobbleRow({
    required this.id,
    required this.profileId,
    required this.trackerId,
    required this.eventJson,
    required this.attempts,
    required this.nextAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['tracker_id'] = Variable<String>(trackerId);
    map['event_json'] = Variable<String>(eventJson);
    map['attempts'] = Variable<int>(attempts);
    map['next_attempt_at'] = Variable<int>(nextAttemptAt);
    return map;
  }

  ScrobbleQueueTableCompanion toCompanion(bool nullToAbsent) {
    return ScrobbleQueueTableCompanion(
      id: Value(id),
      profileId: Value(profileId),
      trackerId: Value(trackerId),
      eventJson: Value(eventJson),
      attempts: Value(attempts),
      nextAttemptAt: Value(nextAttemptAt),
    );
  }

  factory ScrobbleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScrobbleRow(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      trackerId: serializer.fromJson<String>(json['trackerId']),
      eventJson: serializer.fromJson<String>(json['eventJson']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<int>(json['nextAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<String>(profileId),
      'trackerId': serializer.toJson<String>(trackerId),
      'eventJson': serializer.toJson<String>(eventJson),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<int>(nextAttemptAt),
    };
  }

  ScrobbleRow copyWith({
    int? id,
    String? profileId,
    String? trackerId,
    String? eventJson,
    int? attempts,
    int? nextAttemptAt,
  }) => ScrobbleRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    trackerId: trackerId ?? this.trackerId,
    eventJson: eventJson ?? this.eventJson,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
  );
  ScrobbleRow copyWithCompanion(ScrobbleQueueTableCompanion data) {
    return ScrobbleRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      trackerId: data.trackerId.present ? data.trackerId.value : this.trackerId,
      eventJson: data.eventJson.present ? data.eventJson.value : this.eventJson,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScrobbleRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('trackerId: $trackerId, ')
          ..write('eventJson: $eventJson, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, profileId, trackerId, eventJson, attempts, nextAttemptAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScrobbleRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.trackerId == this.trackerId &&
          other.eventJson == this.eventJson &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt);
}

class ScrobbleQueueTableCompanion extends UpdateCompanion<ScrobbleRow> {
  final Value<int> id;
  final Value<String> profileId;
  final Value<String> trackerId;
  final Value<String> eventJson;
  final Value<int> attempts;
  final Value<int> nextAttemptAt;
  const ScrobbleQueueTableCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.trackerId = const Value.absent(),
    this.eventJson = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
  });
  ScrobbleQueueTableCompanion.insert({
    this.id = const Value.absent(),
    required String profileId,
    required String trackerId,
    required String eventJson,
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
  }) : profileId = Value(profileId),
       trackerId = Value(trackerId),
       eventJson = Value(eventJson);
  static Insertable<ScrobbleRow> custom({
    Expression<int>? id,
    Expression<String>? profileId,
    Expression<String>? trackerId,
    Expression<String>? eventJson,
    Expression<int>? attempts,
    Expression<int>? nextAttemptAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (trackerId != null) 'tracker_id': trackerId,
      if (eventJson != null) 'event_json': eventJson,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
    });
  }

  ScrobbleQueueTableCompanion copyWith({
    Value<int>? id,
    Value<String>? profileId,
    Value<String>? trackerId,
    Value<String>? eventJson,
    Value<int>? attempts,
    Value<int>? nextAttemptAt,
  }) {
    return ScrobbleQueueTableCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      trackerId: trackerId ?? this.trackerId,
      eventJson: eventJson ?? this.eventJson,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (trackerId.present) {
      map['tracker_id'] = Variable<String>(trackerId.value);
    }
    if (eventJson.present) {
      map['event_json'] = Variable<String>(eventJson.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScrobbleQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('trackerId: $trackerId, ')
          ..write('eventJson: $eventJson, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $AddonsTable addons = $AddonsTable(this);
  late final $LibraryItemsTable libraryItems = $LibraryItemsTable(this);
  late final $ProgressTable progress = $ProgressTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $TitleSettingsTableTable titleSettingsTable =
      $TitleSettingsTableTable(this);
  late final $LocalFoldersTable localFolders = $LocalFoldersTable(this);
  late final $LocalItemsTable localItems = $LocalItemsTable(this);
  late final $ScrobbleQueueTableTable scrobbleQueueTable =
      $ScrobbleQueueTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    addons,
    libraryItems,
    progress,
    settings,
    titleSettingsTable,
    localFolders,
    localItems,
    scrobbleQueueTable,
  ];
}

typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      required String id,
      required String name,
      Value<int> createdAt,
      Value<int> ageLimit,
      Value<bool> isKid,
      Value<bool> locked,
      Value<int> rowid,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> createdAt,
      Value<int> ageLimit,
      Value<bool> isKid,
      Value<bool> locked,
      Value<int> rowid,
    });

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ageLimit => $composableBuilder(
    column: $table.ageLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isKid => $composableBuilder(
    column: $table.isKid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ageLimit => $composableBuilder(
    column: $table.ageLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isKid => $composableBuilder(
    column: $table.isKid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get ageLimit =>
      $composableBuilder(column: $table.ageLimit, builder: (column) => column);

  GeneratedColumn<bool> get isKid =>
      $composableBuilder(column: $table.isKid, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
          Profile,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> ageLimit = const Value.absent(),
                Value<bool> isKid = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                ageLimit: ageLimit,
                isKid: isKid,
                locked: locked,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> createdAt = const Value.absent(),
                Value<int> ageLimit = const Value.absent(),
                Value<bool> isKid = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                ageLimit: ageLimit,
                isKid: isKid,
                locked: locked,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
      Profile,
      PrefetchHooks Function()
    >;
typedef $$AddonsTableCreateCompanionBuilder =
    AddonsCompanion Function({
      required String id,
      Value<String> profileScope,
      required int position,
      Value<bool> enabled,
      required String manifestJson,
      required String secretKey,
      required String urlHash,
      Value<int> rowid,
    });
typedef $$AddonsTableUpdateCompanionBuilder =
    AddonsCompanion Function({
      Value<String> id,
      Value<String> profileScope,
      Value<int> position,
      Value<bool> enabled,
      Value<String> manifestJson,
      Value<String> secretKey,
      Value<String> urlHash,
      Value<int> rowid,
    });

class $$AddonsTableFilterComposer
    extends Composer<_$AppDatabase, $AddonsTable> {
  $$AddonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileScope => $composableBuilder(
    column: $table.profileScope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secretKey => $composableBuilder(
    column: $table.secretKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlHash => $composableBuilder(
    column: $table.urlHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AddonsTableOrderingComposer
    extends Composer<_$AppDatabase, $AddonsTable> {
  $$AddonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileScope => $composableBuilder(
    column: $table.profileScope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secretKey => $composableBuilder(
    column: $table.secretKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlHash => $composableBuilder(
    column: $table.urlHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AddonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AddonsTable> {
  $$AddonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileScope => $composableBuilder(
    column: $table.profileScope,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secretKey =>
      $composableBuilder(column: $table.secretKey, builder: (column) => column);

  GeneratedColumn<String> get urlHash =>
      $composableBuilder(column: $table.urlHash, builder: (column) => column);
}

class $$AddonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AddonsTable,
          Addon,
          $$AddonsTableFilterComposer,
          $$AddonsTableOrderingComposer,
          $$AddonsTableAnnotationComposer,
          $$AddonsTableCreateCompanionBuilder,
          $$AddonsTableUpdateCompanionBuilder,
          (Addon, BaseReferences<_$AppDatabase, $AddonsTable, Addon>),
          Addon,
          PrefetchHooks Function()
        > {
  $$AddonsTableTableManager(_$AppDatabase db, $AddonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AddonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AddonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AddonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileScope = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> manifestJson = const Value.absent(),
                Value<String> secretKey = const Value.absent(),
                Value<String> urlHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AddonsCompanion(
                id: id,
                profileScope: profileScope,
                position: position,
                enabled: enabled,
                manifestJson: manifestJson,
                secretKey: secretKey,
                urlHash: urlHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> profileScope = const Value.absent(),
                required int position,
                Value<bool> enabled = const Value.absent(),
                required String manifestJson,
                required String secretKey,
                required String urlHash,
                Value<int> rowid = const Value.absent(),
              }) => AddonsCompanion.insert(
                id: id,
                profileScope: profileScope,
                position: position,
                enabled: enabled,
                manifestJson: manifestJson,
                secretKey: secretKey,
                urlHash: urlHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AddonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AddonsTable,
      Addon,
      $$AddonsTableFilterComposer,
      $$AddonsTableOrderingComposer,
      $$AddonsTableAnnotationComposer,
      $$AddonsTableCreateCompanionBuilder,
      $$AddonsTableUpdateCompanionBuilder,
      (Addon, BaseReferences<_$AppDatabase, $AddonsTable, Addon>),
      Addon,
      PrefetchHooks Function()
    >;
typedef $$LibraryItemsTableCreateCompanionBuilder =
    LibraryItemsCompanion Function({
      Value<String> profileId,
      required String itemId,
      required String type,
      Value<String> metaJson,
      Value<int> addedAt,
      Value<String?> certification,
      Value<int> rowid,
    });
typedef $$LibraryItemsTableUpdateCompanionBuilder =
    LibraryItemsCompanion Function({
      Value<String> profileId,
      Value<String> itemId,
      Value<String> type,
      Value<String> metaJson,
      Value<int> addedAt,
      Value<String?> certification,
      Value<int> rowid,
    });

class $$LibraryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get certification => $composableBuilder(
    column: $table.certification,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get certification => $composableBuilder(
    column: $table.certification,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get metaJson =>
      $composableBuilder(column: $table.metaJson, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get certification => $composableBuilder(
    column: $table.certification,
    builder: (column) => column,
  );
}

class $$LibraryItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryItemsTable,
          LibraryItem,
          $$LibraryItemsTableFilterComposer,
          $$LibraryItemsTableOrderingComposer,
          $$LibraryItemsTableAnnotationComposer,
          $$LibraryItemsTableCreateCompanionBuilder,
          $$LibraryItemsTableUpdateCompanionBuilder,
          (
            LibraryItem,
            BaseReferences<_$AppDatabase, $LibraryItemsTable, LibraryItem>,
          ),
          LibraryItem,
          PrefetchHooks Function()
        > {
  $$LibraryItemsTableTableManager(_$AppDatabase db, $LibraryItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> metaJson = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<String?> certification = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryItemsCompanion(
                profileId: profileId,
                itemId: itemId,
                type: type,
                metaJson: metaJson,
                addedAt: addedAt,
                certification: certification,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                required String itemId,
                required String type,
                Value<String> metaJson = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<String?> certification = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryItemsCompanion.insert(
                profileId: profileId,
                itemId: itemId,
                type: type,
                metaJson: metaJson,
                addedAt: addedAt,
                certification: certification,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryItemsTable,
      LibraryItem,
      $$LibraryItemsTableFilterComposer,
      $$LibraryItemsTableOrderingComposer,
      $$LibraryItemsTableAnnotationComposer,
      $$LibraryItemsTableCreateCompanionBuilder,
      $$LibraryItemsTableUpdateCompanionBuilder,
      (
        LibraryItem,
        BaseReferences<_$AppDatabase, $LibraryItemsTable, LibraryItem>,
      ),
      LibraryItem,
      PrefetchHooks Function()
    >;
typedef $$ProgressTableCreateCompanionBuilder =
    ProgressCompanion Function({
      Value<String> profileId,
      required String itemId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<int> updatedAt,
      Value<String> metaId,
      Value<bool> watched,
      Value<String?> certification,
      Value<String?> title,
      Value<String?> poster,
      Value<String?> mediaType,
      Value<int?> season,
      Value<int?> episode,
      Value<String?> streamAddonId,
      Value<String?> streamKey,
      Value<int> rowid,
    });
typedef $$ProgressTableUpdateCompanionBuilder =
    ProgressCompanion Function({
      Value<String> profileId,
      Value<String> itemId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<int> updatedAt,
      Value<String> metaId,
      Value<bool> watched,
      Value<String?> certification,
      Value<String?> title,
      Value<String?> poster,
      Value<String?> mediaType,
      Value<int?> season,
      Value<int?> episode,
      Value<String?> streamAddonId,
      Value<String?> streamKey,
      Value<int> rowid,
    });

class $$ProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ProgressTable> {
  $$ProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaId => $composableBuilder(
    column: $table.metaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get watched => $composableBuilder(
    column: $table.watched,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get certification => $composableBuilder(
    column: $table.certification,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get poster => $composableBuilder(
    column: $table.poster,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamAddonId => $composableBuilder(
    column: $table.streamAddonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamKey => $composableBuilder(
    column: $table.streamKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgressTable> {
  $$ProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaId => $composableBuilder(
    column: $table.metaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get watched => $composableBuilder(
    column: $table.watched,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get certification => $composableBuilder(
    column: $table.certification,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get poster => $composableBuilder(
    column: $table.poster,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamAddonId => $composableBuilder(
    column: $table.streamAddonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamKey => $composableBuilder(
    column: $table.streamKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgressTable> {
  $$ProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get metaId =>
      $composableBuilder(column: $table.metaId, builder: (column) => column);

  GeneratedColumn<bool> get watched =>
      $composableBuilder(column: $table.watched, builder: (column) => column);

  GeneratedColumn<String> get certification => $composableBuilder(
    column: $table.certification,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get poster =>
      $composableBuilder(column: $table.poster, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<String> get streamAddonId => $composableBuilder(
    column: $table.streamAddonId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streamKey =>
      $composableBuilder(column: $table.streamKey, builder: (column) => column);
}

class $$ProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgressTable,
          ProgressData,
          $$ProgressTableFilterComposer,
          $$ProgressTableOrderingComposer,
          $$ProgressTableAnnotationComposer,
          $$ProgressTableCreateCompanionBuilder,
          $$ProgressTableUpdateCompanionBuilder,
          (
            ProgressData,
            BaseReferences<_$AppDatabase, $ProgressTable, ProgressData>,
          ),
          ProgressData,
          PrefetchHooks Function()
        > {
  $$ProgressTableTableManager(_$AppDatabase db, $ProgressTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> metaId = const Value.absent(),
                Value<bool> watched = const Value.absent(),
                Value<String?> certification = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> poster = const Value.absent(),
                Value<String?> mediaType = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<String?> streamAddonId = const Value.absent(),
                Value<String?> streamKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressCompanion(
                profileId: profileId,
                itemId: itemId,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                metaId: metaId,
                watched: watched,
                certification: certification,
                title: title,
                poster: poster,
                mediaType: mediaType,
                season: season,
                episode: episode,
                streamAddonId: streamAddonId,
                streamKey: streamKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                required String itemId,
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> metaId = const Value.absent(),
                Value<bool> watched = const Value.absent(),
                Value<String?> certification = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> poster = const Value.absent(),
                Value<String?> mediaType = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<String?> streamAddonId = const Value.absent(),
                Value<String?> streamKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressCompanion.insert(
                profileId: profileId,
                itemId: itemId,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                metaId: metaId,
                watched: watched,
                certification: certification,
                title: title,
                poster: poster,
                mediaType: mediaType,
                season: season,
                episode: episode,
                streamAddonId: streamAddonId,
                streamKey: streamKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgressTable,
      ProgressData,
      $$ProgressTableFilterComposer,
      $$ProgressTableOrderingComposer,
      $$ProgressTableAnnotationComposer,
      $$ProgressTableCreateCompanionBuilder,
      $$ProgressTableUpdateCompanionBuilder,
      (
        ProgressData,
        BaseReferences<_$AppDatabase, $ProgressTable, ProgressData>,
      ),
      ProgressData,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$TitleSettingsTableTableCreateCompanionBuilder =
    TitleSettingsTableCompanion Function({
      required String profileId,
      required String metaId,
      required String json,
      Value<int> rowid,
    });
typedef $$TitleSettingsTableTableUpdateCompanionBuilder =
    TitleSettingsTableCompanion Function({
      Value<String> profileId,
      Value<String> metaId,
      Value<String> json,
      Value<int> rowid,
    });

class $$TitleSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $TitleSettingsTableTable> {
  $$TitleSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaId => $composableBuilder(
    column: $table.metaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TitleSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TitleSettingsTableTable> {
  $$TitleSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaId => $composableBuilder(
    column: $table.metaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TitleSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TitleSettingsTableTable> {
  $$TitleSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get metaId =>
      $composableBuilder(column: $table.metaId, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$TitleSettingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TitleSettingsTableTable,
          TitleSettingsRow,
          $$TitleSettingsTableTableFilterComposer,
          $$TitleSettingsTableTableOrderingComposer,
          $$TitleSettingsTableTableAnnotationComposer,
          $$TitleSettingsTableTableCreateCompanionBuilder,
          $$TitleSettingsTableTableUpdateCompanionBuilder,
          (
            TitleSettingsRow,
            BaseReferences<
              _$AppDatabase,
              $TitleSettingsTableTable,
              TitleSettingsRow
            >,
          ),
          TitleSettingsRow,
          PrefetchHooks Function()
        > {
  $$TitleSettingsTableTableTableManager(
    _$AppDatabase db,
    $TitleSettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TitleSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TitleSettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TitleSettingsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> metaId = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TitleSettingsTableCompanion(
                profileId: profileId,
                metaId: metaId,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String metaId,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => TitleSettingsTableCompanion.insert(
                profileId: profileId,
                metaId: metaId,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TitleSettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TitleSettingsTableTable,
      TitleSettingsRow,
      $$TitleSettingsTableTableFilterComposer,
      $$TitleSettingsTableTableOrderingComposer,
      $$TitleSettingsTableTableAnnotationComposer,
      $$TitleSettingsTableTableCreateCompanionBuilder,
      $$TitleSettingsTableTableUpdateCompanionBuilder,
      (
        TitleSettingsRow,
        BaseReferences<
          _$AppDatabase,
          $TitleSettingsTableTable,
          TitleSettingsRow
        >,
      ),
      TitleSettingsRow,
      PrefetchHooks Function()
    >;
typedef $$LocalFoldersTableCreateCompanionBuilder =
    LocalFoldersCompanion Function({
      required String path,
      Value<int> addedAt,
      Value<int> lastScanAt,
      Value<int> rowid,
    });
typedef $$LocalFoldersTableUpdateCompanionBuilder =
    LocalFoldersCompanion Function({
      Value<String> path,
      Value<int> addedAt,
      Value<int> lastScanAt,
      Value<int> rowid,
    });

class $$LocalFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalFoldersTable> {
  $$LocalFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalFoldersTable> {
  $$LocalFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalFoldersTable> {
  $$LocalFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => column,
  );
}

class $$LocalFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalFoldersTable,
          LocalFolder,
          $$LocalFoldersTableFilterComposer,
          $$LocalFoldersTableOrderingComposer,
          $$LocalFoldersTableAnnotationComposer,
          $$LocalFoldersTableCreateCompanionBuilder,
          $$LocalFoldersTableUpdateCompanionBuilder,
          (
            LocalFolder,
            BaseReferences<_$AppDatabase, $LocalFoldersTable, LocalFolder>,
          ),
          LocalFolder,
          PrefetchHooks Function()
        > {
  $$LocalFoldersTableTableManager(_$AppDatabase db, $LocalFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> lastScanAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFoldersCompanion(
                path: path,
                addedAt: addedAt,
                lastScanAt: lastScanAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                Value<int> addedAt = const Value.absent(),
                Value<int> lastScanAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFoldersCompanion.insert(
                path: path,
                addedAt: addedAt,
                lastScanAt: lastScanAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalFoldersTable,
      LocalFolder,
      $$LocalFoldersTableFilterComposer,
      $$LocalFoldersTableOrderingComposer,
      $$LocalFoldersTableAnnotationComposer,
      $$LocalFoldersTableCreateCompanionBuilder,
      $$LocalFoldersTableUpdateCompanionBuilder,
      (
        LocalFolder,
        BaseReferences<_$AppDatabase, $LocalFoldersTable, LocalFolder>,
      ),
      LocalFolder,
      PrefetchHooks Function()
    >;
typedef $$LocalItemsTableCreateCompanionBuilder =
    LocalItemsCompanion Function({
      required String id,
      required String folderPath,
      required String path,
      required String fileName,
      required String title,
      Value<String?> titleOverride,
      Value<int?> year,
      Value<int?> season,
      Value<int?> episode,
      Value<int> sizeBytes,
      Value<int> modifiedAt,
      Value<int> addedAt,
      Value<int> rowid,
    });
typedef $$LocalItemsTableUpdateCompanionBuilder =
    LocalItemsCompanion Function({
      Value<String> id,
      Value<String> folderPath,
      Value<String> path,
      Value<String> fileName,
      Value<String> title,
      Value<String?> titleOverride,
      Value<int?> year,
      Value<int?> season,
      Value<int?> episode,
      Value<int> sizeBytes,
      Value<int> modifiedAt,
      Value<int> addedAt,
      Value<int> rowid,
    });

class $$LocalItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalItemsTable> {
  $$LocalItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleOverride => $composableBuilder(
    column: $table.titleOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalItemsTable> {
  $$LocalItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleOverride => $composableBuilder(
    column: $table.titleOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalItemsTable> {
  $$LocalItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleOverride => $composableBuilder(
    column: $table.titleOverride,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$LocalItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalItemsTable,
          LocalItem,
          $$LocalItemsTableFilterComposer,
          $$LocalItemsTableOrderingComposer,
          $$LocalItemsTableAnnotationComposer,
          $$LocalItemsTableCreateCompanionBuilder,
          $$LocalItemsTableUpdateCompanionBuilder,
          (
            LocalItem,
            BaseReferences<_$AppDatabase, $LocalItemsTable, LocalItem>,
          ),
          LocalItem,
          PrefetchHooks Function()
        > {
  $$LocalItemsTableTableManager(_$AppDatabase db, $LocalItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> folderPath = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> titleOverride = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> modifiedAt = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalItemsCompanion(
                id: id,
                folderPath: folderPath,
                path: path,
                fileName: fileName,
                title: title,
                titleOverride: titleOverride,
                year: year,
                season: season,
                episode: episode,
                sizeBytes: sizeBytes,
                modifiedAt: modifiedAt,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String folderPath,
                required String path,
                required String fileName,
                required String title,
                Value<String?> titleOverride = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> modifiedAt = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalItemsCompanion.insert(
                id: id,
                folderPath: folderPath,
                path: path,
                fileName: fileName,
                title: title,
                titleOverride: titleOverride,
                year: year,
                season: season,
                episode: episode,
                sizeBytes: sizeBytes,
                modifiedAt: modifiedAt,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalItemsTable,
      LocalItem,
      $$LocalItemsTableFilterComposer,
      $$LocalItemsTableOrderingComposer,
      $$LocalItemsTableAnnotationComposer,
      $$LocalItemsTableCreateCompanionBuilder,
      $$LocalItemsTableUpdateCompanionBuilder,
      (LocalItem, BaseReferences<_$AppDatabase, $LocalItemsTable, LocalItem>),
      LocalItem,
      PrefetchHooks Function()
    >;
typedef $$ScrobbleQueueTableTableCreateCompanionBuilder =
    ScrobbleQueueTableCompanion Function({
      Value<int> id,
      required String profileId,
      required String trackerId,
      required String eventJson,
      Value<int> attempts,
      Value<int> nextAttemptAt,
    });
typedef $$ScrobbleQueueTableTableUpdateCompanionBuilder =
    ScrobbleQueueTableCompanion Function({
      Value<int> id,
      Value<String> profileId,
      Value<String> trackerId,
      Value<String> eventJson,
      Value<int> attempts,
      Value<int> nextAttemptAt,
    });

class $$ScrobbleQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $ScrobbleQueueTableTable> {
  $$ScrobbleQueueTableTableFilterComposer({
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

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackerId => $composableBuilder(
    column: $table.trackerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventJson => $composableBuilder(
    column: $table.eventJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScrobbleQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ScrobbleQueueTableTable> {
  $$ScrobbleQueueTableTableOrderingComposer({
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

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackerId => $composableBuilder(
    column: $table.trackerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventJson => $composableBuilder(
    column: $table.eventJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScrobbleQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScrobbleQueueTableTable> {
  $$ScrobbleQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get trackerId =>
      $composableBuilder(column: $table.trackerId, builder: (column) => column);

  GeneratedColumn<String> get eventJson =>
      $composableBuilder(column: $table.eventJson, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );
}

class $$ScrobbleQueueTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScrobbleQueueTableTable,
          ScrobbleRow,
          $$ScrobbleQueueTableTableFilterComposer,
          $$ScrobbleQueueTableTableOrderingComposer,
          $$ScrobbleQueueTableTableAnnotationComposer,
          $$ScrobbleQueueTableTableCreateCompanionBuilder,
          $$ScrobbleQueueTableTableUpdateCompanionBuilder,
          (
            ScrobbleRow,
            BaseReferences<
              _$AppDatabase,
              $ScrobbleQueueTableTable,
              ScrobbleRow
            >,
          ),
          ScrobbleRow,
          PrefetchHooks Function()
        > {
  $$ScrobbleQueueTableTableTableManager(
    _$AppDatabase db,
    $ScrobbleQueueTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScrobbleQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScrobbleQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScrobbleQueueTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> trackerId = const Value.absent(),
                Value<String> eventJson = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> nextAttemptAt = const Value.absent(),
              }) => ScrobbleQueueTableCompanion(
                id: id,
                profileId: profileId,
                trackerId: trackerId,
                eventJson: eventJson,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String profileId,
                required String trackerId,
                required String eventJson,
                Value<int> attempts = const Value.absent(),
                Value<int> nextAttemptAt = const Value.absent(),
              }) => ScrobbleQueueTableCompanion.insert(
                id: id,
                profileId: profileId,
                trackerId: trackerId,
                eventJson: eventJson,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScrobbleQueueTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScrobbleQueueTableTable,
      ScrobbleRow,
      $$ScrobbleQueueTableTableFilterComposer,
      $$ScrobbleQueueTableTableOrderingComposer,
      $$ScrobbleQueueTableTableAnnotationComposer,
      $$ScrobbleQueueTableTableCreateCompanionBuilder,
      $$ScrobbleQueueTableTableUpdateCompanionBuilder,
      (
        ScrobbleRow,
        BaseReferences<_$AppDatabase, $ScrobbleQueueTableTable, ScrobbleRow>,
      ),
      ScrobbleRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$AddonsTableTableManager get addons =>
      $$AddonsTableTableManager(_db, _db.addons);
  $$LibraryItemsTableTableManager get libraryItems =>
      $$LibraryItemsTableTableManager(_db, _db.libraryItems);
  $$ProgressTableTableManager get progress =>
      $$ProgressTableTableManager(_db, _db.progress);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$TitleSettingsTableTableTableManager get titleSettingsTable =>
      $$TitleSettingsTableTableTableManager(_db, _db.titleSettingsTable);
  $$LocalFoldersTableTableManager get localFolders =>
      $$LocalFoldersTableTableManager(_db, _db.localFolders);
  $$LocalItemsTableTableManager get localItems =>
      $$LocalItemsTableTableManager(_db, _db.localItems);
  $$ScrobbleQueueTableTableTableManager get scrobbleQueueTable =>
      $$ScrobbleQueueTableTableTableManager(_db, _db.scrobbleQueueTable);
}
