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
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    itemId,
    type,
    metaJson,
    addedAt,
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
  const LibraryItem({
    required this.profileId,
    required this.itemId,
    required this.type,
    required this.metaJson,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['item_id'] = Variable<String>(itemId);
    map['type'] = Variable<String>(type);
    map['meta_json'] = Variable<String>(metaJson);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  LibraryItemsCompanion toCompanion(bool nullToAbsent) {
    return LibraryItemsCompanion(
      profileId: Value(profileId),
      itemId: Value(itemId),
      type: Value(type),
      metaJson: Value(metaJson),
      addedAt: Value(addedAt),
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
    };
  }

  LibraryItem copyWith({
    String? profileId,
    String? itemId,
    String? type,
    String? metaJson,
    int? addedAt,
  }) => LibraryItem(
    profileId: profileId ?? this.profileId,
    itemId: itemId ?? this.itemId,
    type: type ?? this.type,
    metaJson: metaJson ?? this.metaJson,
    addedAt: addedAt ?? this.addedAt,
  );
  LibraryItem copyWithCompanion(LibraryItemsCompanion data) {
    return LibraryItem(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      type: data.type.present ? data.type.value : this.type,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryItem(')
          ..write('profileId: $profileId, ')
          ..write('itemId: $itemId, ')
          ..write('type: $type, ')
          ..write('metaJson: $metaJson, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, itemId, type, metaJson, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryItem &&
          other.profileId == this.profileId &&
          other.itemId == this.itemId &&
          other.type == this.type &&
          other.metaJson == this.metaJson &&
          other.addedAt == this.addedAt);
}

class LibraryItemsCompanion extends UpdateCompanion<LibraryItem> {
  final Value<String> profileId;
  final Value<String> itemId;
  final Value<String> type;
  final Value<String> metaJson;
  final Value<int> addedAt;
  final Value<int> rowid;
  const LibraryItemsCompanion({
    this.profileId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.type = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryItemsCompanion.insert({
    this.profileId = const Value.absent(),
    required String itemId,
    required String type,
    this.metaJson = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       type = Value(type);
  static Insertable<LibraryItem> custom({
    Expression<String>? profileId,
    Expression<String>? itemId,
    Expression<String>? type,
    Expression<String>? metaJson,
    Expression<int>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (itemId != null) 'item_id': itemId,
      if (type != null) 'type': type,
      if (metaJson != null) 'meta_json': metaJson,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryItemsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? itemId,
    Value<String>? type,
    Value<String>? metaJson,
    Value<int>? addedAt,
    Value<int>? rowid,
  }) {
    return LibraryItemsCompanion(
      profileId: profileId ?? this.profileId,
      itemId: itemId ?? this.itemId,
      type: type ?? this.type,
      metaJson: metaJson ?? this.metaJson,
      addedAt: addedAt ?? this.addedAt,
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
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    itemId,
    positionMs,
    durationMs,
    updatedAt,
    metaId,
    watched,
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
  const ProgressData({
    required this.profileId,
    required this.itemId,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
    required this.metaId,
    required this.watched,
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
  }) => ProgressData(
    profileId: profileId ?? this.profileId,
    itemId: itemId ?? this.itemId,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
    metaId: metaId ?? this.metaId,
    watched: watched ?? this.watched,
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
          ..write('watched: $watched')
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
          other.watched == this.watched);
}

class ProgressCompanion extends UpdateCompanion<ProgressData> {
  final Value<String> profileId;
  final Value<String> itemId;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<int> updatedAt;
  final Value<String> metaId;
  final Value<bool> watched;
  final Value<int> rowid;
  const ProgressCompanion({
    this.profileId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.metaId = const Value.absent(),
    this.watched = const Value.absent(),
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
      Value<int> rowid,
    });
typedef $$LibraryItemsTableUpdateCompanionBuilder =
    LibraryItemsCompanion Function({
      Value<String> profileId,
      Value<String> itemId,
      Value<String> type,
      Value<String> metaJson,
      Value<int> addedAt,
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
                Value<int> rowid = const Value.absent(),
              }) => LibraryItemsCompanion(
                profileId: profileId,
                itemId: itemId,
                type: type,
                metaJson: metaJson,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                required String itemId,
                required String type,
                Value<String> metaJson = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryItemsCompanion.insert(
                profileId: profileId,
                itemId: itemId,
                type: type,
                metaJson: metaJson,
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
                Value<int> rowid = const Value.absent(),
              }) => ProgressCompanion(
                profileId: profileId,
                itemId: itemId,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                metaId: metaId,
                watched: watched,
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
                Value<int> rowid = const Value.absent(),
              }) => ProgressCompanion.insert(
                profileId: profileId,
                itemId: itemId,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                metaId: metaId,
                watched: watched,
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
}
