/// Réglages de lecture mémorisés pour un titre (film ou série).
class TitleSettings {
  const TitleSettings({
    this.audioLang,
    this.subtitleLang,
    this.subtitleDelayMs = 0,
    this.audioDelayMs = 0,
    this.aspect = 0,
  });

  factory TitleSettings.fromJson(Map<String, Object?> json) => TitleSettings(
    audioLang: json['audioLang'] as String?,
    subtitleLang: json['subtitleLang'] as String?,
    subtitleDelayMs: (json['subtitleDelayMs'] as num?)?.toInt() ?? 0,
    audioDelayMs: (json['audioDelayMs'] as num?)?.toInt() ?? 0,
    aspect: (json['aspect'] as num?)?.toDouble() ?? 0,
  );

  /// Langue audio choisie (code), `null` = pas de préférence.
  final String? audioLang;

  /// Langue des sous-titres ; `null` = pas de préférence, `'off'` = désactivés.
  final String? subtitleLang;
  final int subtitleDelayMs;
  final int audioDelayMs;

  /// Rapport d'image forcé ; 0 = automatique.
  final double aspect;

  TitleSettings copyWith({
    String? audioLang,
    String? subtitleLang,
    int? subtitleDelayMs,
    int? audioDelayMs,
    double? aspect,
  }) => TitleSettings(
    audioLang: audioLang ?? this.audioLang,
    subtitleLang: subtitleLang ?? this.subtitleLang,
    subtitleDelayMs: subtitleDelayMs ?? this.subtitleDelayMs,
    audioDelayMs: audioDelayMs ?? this.audioDelayMs,
    aspect: aspect ?? this.aspect,
  );

  Map<String, Object?> toJson() => {
    'audioLang': audioLang,
    'subtitleLang': subtitleLang,
    'subtitleDelayMs': subtitleDelayMs,
    'audioDelayMs': audioDelayMs,
    'aspect': aspect,
  };
}

/// Clé de mémorisation : un épisode `tt1:1:2` partage les réglages de sa
/// série `tt1` (partie avant le premier `:`).
String titleSettingsKey(String metaId) {
  final i = metaId.indexOf(':');
  return i < 0 ? metaId : metaId.substring(0, i);
}

/// Stockage des réglages par profil et par titre (clé par série).
abstract class TitleSettingsStore {
  TitleSettings forTitle(String profileId, String metaId);
  void save(String profileId, String metaId, TitleSettings s);
}

/// Implémentation en mémoire (tests, repli).
class InMemoryTitleSettingsStore implements TitleSettingsStore {
  final _map = <String, TitleSettings>{};

  String _k(String profileId, String metaId) =>
      '$profileId\u0000${titleSettingsKey(metaId)}';

  @override
  TitleSettings forTitle(String profileId, String metaId) =>
      _map[_k(profileId, metaId)] ?? const TitleSettings();

  @override
  void save(String profileId, String metaId, TitleSettings s) =>
      _map[_k(profileId, metaId)] = s;
}
