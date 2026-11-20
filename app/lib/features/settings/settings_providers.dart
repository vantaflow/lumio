import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/features/detail/playback_service.dart'
    show streamPrefsProvider, streamPrefsStoreProvider;
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/focus/tv_detection.dart';
import 'package:lumio_core/lumio_core.dart' show Quality;
import 'package:package_info_plus/package_info_plus.dart';

final appSettingsStoreProvider = Provider<AppSettingsStore>(
  (ref) => AppSettingsStore(ref.watch(appDatabaseProvider)),
);

/// Langue de l'interface : français par défaut, relue depuis les réglages au
/// démarrage ; un changement s'applique aussitôt (sans redémarrage).
final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  bool _touched = false;

  @override
  Locale build() {
    _load();
    return supportedUiLocales.first;
  }

  Future<void> _load() async {
    try {
      final code = await ref
          .read(appSettingsStoreProvider)
          .read(AppSettingsStore.localeKey);
      if (_touched || code == null) return;
      final found = supportedUiLocales.where((l) => l.languageCode == code);
      if (found.isNotEmpty) state = found.first;
    } on Object {
      // Réglage illisible : français.
    }
  }

  /// Applique la langue puis la mémorise ; lève si l'écriture échoue (la
  /// langue reste appliquée pour la session).
  Future<void> set(Locale locale) async {
    _touched = true;
    state = locale;
    await ref
        .read(appSettingsStoreProvider)
        .write(AppSettingsStore.localeKey, locale.languageCode);
  }
}

/// Cache et débit des torrents (consommés par `CacheManager`).
final torrentSettingsProvider =
    NotifierProvider<TorrentSettingsController, TorrentSettings>(
      TorrentSettingsController.new,
    );

class TorrentSettingsController extends Notifier<TorrentSettings> {
  bool _touched = false;

  @override
  TorrentSettings build() {
    _load();
    // Sur TV le stockage est petit : cache vidé à la fermeture par défaut.
    return TorrentSettings(clearCacheOnExit: ref.read(androidTvProvider));
  }

  Future<void> _load() async {
    try {
      final store = ref.read(appSettingsStoreProvider);
      final cache = await store.readInt(AppSettingsStore.torrentCacheKey);
      final up = await store.readInt(AppSettingsStore.uploadKey);
      final clear = await store.read(AppSettingsStore.clearCacheOnExitKey);
      if (_touched) return;
      state = TorrentSettings(
        cacheGb: cache != null && cache > 0 ? cache : state.cacheGb,
        uploadKbps: up != null && up >= 0 ? up : state.uploadKbps,
        clearCacheOnExit: clear == null ? state.clearCacheOnExit : clear == '1',
      );
    } on Object {
      // Valeurs par défaut.
    }
  }

  Future<void> setCacheGb(int gb) async {
    _touched = true;
    state = state.copyWith(cacheGb: gb);
    await ref
        .read(appSettingsStoreProvider)
        .write(AppSettingsStore.torrentCacheKey, '$gb');
  }

  Future<void> setUploadKbps(int kbps) async {
    _touched = true;
    state = state.copyWith(uploadKbps: kbps);
    await ref
        .read(appSettingsStoreProvider)
        .write(AppSettingsStore.uploadKey, '$kbps');
  }

  Future<void> setClearCacheOnExit(bool value) async {
    _touched = true;
    state = state.copyWith(clearCacheOnExit: value);
    await ref
        .read(appSettingsStoreProvider)
        .write(AppSettingsStore.clearCacheOnExitKey, value ? '1' : '0');
  }
}

/// Langue de sous-titres par défaut du profil actif : code de langue, `off`
/// pour aucun sous-titre, `null` tant qu'elle n'est pas choisie.
final defaultSubtitleLangProvider = FutureProvider<String?>((ref) {
  final id = ref.watch(currentProfileIdProvider);
  return ref
      .watch(appSettingsStoreProvider)
      .read(AppSettingsStore.subtitleLangKey(id));
});

/// Langue audio par défaut du profil actif (première langue préférée).
final defaultAudioLangProvider = FutureProvider<String?>((ref) async {
  final p = await ref.watch(streamPrefsProvider.future);
  return p.languages.isEmpty ? null : p.languages.first;
});

/// Modifications des préférences du profil actif (flux et sous-titres).
class ProfilePrefsEditor {
  ProfilePrefsEditor(this._ref);
  final Ref _ref;

  Future<void> setAudioLang(String lang) async {
    final id = _ref.read(currentProfileIdProvider);
    final cur = await _ref.read(streamPrefsProvider.future);
    final next = cur.copyWith(
      languages: [lang, ...cur.languages.where((l) => l != lang)],
    );
    await _ref.read(streamPrefsStoreProvider).save(id, next);
    _ref.invalidate(streamPrefsProvider);
  }

  Future<void> setQuality(Quality q) async {
    final id = _ref.read(currentProfileIdProvider);
    final cur = await _ref.read(streamPrefsProvider.future);
    await _ref
        .read(streamPrefsStoreProvider)
        .save(id, cur.copyWith(maxQuality: q));
    _ref.invalidate(streamPrefsProvider);
  }

  Future<void> setPreferDirect(bool value) async {
    final id = _ref.read(currentProfileIdProvider);
    final cur = await _ref.read(streamPrefsProvider.future);
    await _ref
        .read(streamPrefsStoreProvider)
        .save(id, cur.copyWith(preferDirect: value));
    _ref.invalidate(streamPrefsProvider);
  }

  Future<void> setSubtitleLang(String lang) async {
    final id = _ref.read(currentProfileIdProvider);
    await _ref
        .read(appSettingsStoreProvider)
        .write(AppSettingsStore.subtitleLangKey(id), lang);
    _ref.invalidate(defaultSubtitleLangProvider);
  }
}

final profilePrefsEditorProvider = Provider<ProfilePrefsEditor>(
  ProfilePrefsEditor.new,
);

/// Version de l'application (vide si indisponible, ex. en test).
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } on Object {
    return '';
  }
});

/// Menu debug débloqué (7 appuis sur la version) pour cette session.
final debugMenuUnlockedProvider = NotifierProvider<_Unlocked, bool>(
  _Unlocked.new,
);

class _Unlocked extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;
}
