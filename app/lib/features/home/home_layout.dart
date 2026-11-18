import 'dart:convert';

import 'package:lumio/data/db.dart';

/// Identifiants des rangées fixes de l'accueil.
const continueRowId = 'continue';
const libraryRowId = 'library';
const localRowId = 'local';

/// Identifiant d'une rangée de catalogue.
String catalogRowId(String addonId, String type, String catalogId) =>
    'cat:$addonId|$type|$catalogId';

/// Personnalisation de l'accueil d'un profil : ordre et rangées masquées.
class HomeLayout {
  const HomeLayout({this.order = const [], this.hidden = const {}});

  /// Ordre voulu ; les rangées inconnues (nouvelles) viennent à la suite.
  final List<String> order;
  final Set<String> hidden;

  HomeLayout copyWith({List<String>? order, Set<String>? hidden}) =>
      HomeLayout(order: order ?? this.order, hidden: hidden ?? this.hidden);

  Map<String, Object?> toJson() => {'order': order, 'hidden': hidden.toList()};

  /// Lecture tolérante : un JSON illisible donne la disposition par défaut.
  static HomeLayout fromJson(Object? json) {
    if (json is! Map) return const HomeLayout();
    List<String> strings(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is String) e,
    ];
    return HomeLayout(
      order: strings(json['order']),
      hidden: strings(json['hidden']).toSet(),
    );
  }

  /// Toutes les rangées [natural] dans l'ordre voulu (masquées incluses).
  List<String> arrange(List<String> natural) {
    final known = natural.toSet();
    final seen = <String>{};
    return [
      for (final id in order)
        if (known.contains(id) && seen.add(id)) id,
      for (final id in natural)
        if (seen.add(id)) id,
    ];
  }

  /// Rangées à afficher : [arrange] sans les masquées.
  List<String> visible(List<String> natural) => [
    for (final id in arrange(natural))
      if (!hidden.contains(id)) id,
  ];
}

/// Persistance par profil dans la table `settings`.
class HomeLayoutStore {
  HomeLayoutStore(this._db);

  final AppDatabase _db;

  static String keyFor(String profileId) => 'home_layout:$profileId';

  Future<HomeLayout> load(String profileId) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(keyFor(profileId)))).getSingleOrNull();
    if (row == null) return const HomeLayout();
    try {
      return HomeLayout.fromJson(jsonDecode(row.value));
    } on FormatException {
      return const HomeLayout();
    }
  }

  Future<void> save(String profileId, HomeLayout layout) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: keyFor(profileId),
          value: jsonEncode(layout.toJson()),
        ),
      );
}
