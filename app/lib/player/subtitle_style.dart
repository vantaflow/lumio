import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:lumio/data/db.dart';
import 'package:media_kit_video/media_kit_video.dart'
    show SubtitleViewConfiguration;

/// Tailles de sous-titres proposées (S/M/L/XL).
enum SubtitleSize {
  s('S', 40),
  m('M', 55),
  l('L', 70),
  xl('XL', 90);

  const SubtitleSize(this.label, this.mpvFontSize);
  final String label;

  /// Valeur de la propriété libmpv `sub-font-size`.
  final int mpvFontSize;
}

/// Style des sous-titres : taille et fond opaque (lisibilité).
class SubtitleStyle {
  const SubtitleStyle({
    this.size = SubtitleSize.m,
    this.opaqueBackground = false,
  });

  factory SubtitleStyle.fromJson(Map<String, Object?> j) => SubtitleStyle(
    size: SubtitleSize.values.firstWhere(
      (s) => s.name == j['size'],
      orElse: () => SubtitleSize.m,
    ),
    opaqueBackground: j['opaqueBackground'] == true,
  );

  final SubtitleSize size;
  final bool opaqueBackground;

  SubtitleStyle copyWith({SubtitleSize? size, bool? opaqueBackground}) =>
      SubtitleStyle(
        size: size ?? this.size,
        opaqueBackground: opaqueBackground ?? this.opaqueBackground,
      );

  Map<String, Object?> toJson() => {
    'size': size.name,
    'opaqueBackground': opaqueBackground,
  };

  /// Configuration du rendu des sous-titres par Flutter (media_kit dessine
  /// lui-même le texte : les propriétés libmpv seules ne changent rien à
  /// l'écran). La taille moyenne vaut 32, les autres suivent le même rapport
  /// que `sub-font-size`.
  SubtitleViewConfiguration viewConfiguration() => SubtitleViewConfiguration(
    style: TextStyle(
      height: 1.4,
      fontSize: 32.0 * size.mpvFontSize / SubtitleSize.m.mpvFontSize,
      color: const Color(0xFFFFFFFF),
      backgroundColor: opaqueBackground ? const Color(0xFF000000) : null,
      shadows: const [
        Shadow(blurRadius: 4, color: Color(0xFF000000)),
        Shadow(offset: Offset(1.5, 1.5), color: Color(0xFF000000)),
      ],
    ),
  );

  /// Propriétés libmpv correspondantes.
  Map<String, String> get mpvProperties => {
    'sub-font-size': '${size.mpvFontSize}',
    'sub-border-style': opaqueBackground
        ? 'background-box'
        : 'outline-and-shadow',
    'sub-back-color': opaqueBackground ? '#FF000000' : '#00000000',
  };
}

/// Persistance du style dans la table `settings` (clé `subtitle_style`).
class SubtitleStyleStore {
  SubtitleStyleStore(this._db);
  final AppDatabase _db;
  static const _key = 'subtitle_style';

  Future<SubtitleStyle> load() async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(_key))).getSingleOrNull();
    if (row == null) return const SubtitleStyle();
    try {
      final j = jsonDecode(row.value);
      if (j is Map<String, Object?>) return SubtitleStyle.fromJson(j);
    } on FormatException {
      // Valeur illisible : style par défaut.
    }
    return const SubtitleStyle();
  }

  Future<void> save(SubtitleStyle s) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: _key, value: jsonEncode(s.toJson())),
      );
}
