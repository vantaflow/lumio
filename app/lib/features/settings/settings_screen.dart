import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/data/stream_prefs.dart';
import 'package:lumio/debug/loop_debug.dart';
import 'package:lumio/debug/player_spike.dart';
import 'package:lumio/debug/torrent_spike.dart';
import 'package:lumio/data/sync_providers.dart';
import 'package:lumio/features/addons/addons_screen.dart';
import 'package:lumio/features/settings/account_screen.dart';
import 'package:lumio/features/settings/backup_section.dart';
import 'package:lumio/features/detail/playback_service.dart'
    show streamPrefsProvider;
import 'package:lumio/features/profiles/pin_dialog.dart' show requireParent;
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/features/settings/stremio_import_screen.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/torrent/torrent_providers.dart' show networkProbeProvider;
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart' show NetInterface, Quality;

/// Clé de la mémoire du focus et nom de route de l'écran.
const settingsRouteKey = 'settings';

/// Ouvre les réglages ; un profil enfant doit d'abord saisir le PIN parent.
Future<void> openSettings(BuildContext context, WidgetRef ref) async {
  if (!await requireParent(context, ref)) return;
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: settingsRouteKey),
      builder: (_) => const SettingsScreen(),
    ),
  );
}

/// Nombre d'appuis sur la version qui débloquent le menu debug.
const debugUnlockPresses = 7;

/// Langues proposées pour l'audio et les sous-titres (code, libellé).
List<(String, String)> languageChoices(AppLocalizations l) => [
  ('fr', l.langFrench),
  ('en', l.langEnglish),
  ('es', l.langSpanish),
  ('de', l.langGerman),
  ('it', l.langItalian),
  ('pt', l.langPortuguese),
  ('ar', l.langArabic),
];

String _langName(AppLocalizations l, String? code) {
  for (final (c, name) in languageChoices(l)) {
    if (c == code) return name;
  }
  return code ?? l.settingsNone;
}

String _qualityName(AppLocalizations l, Quality q) => switch (q) {
  Quality.sd => 'SD',
  Quality.hd720 => '720p',
  Quality.hd1080 => '1080p',
  Quality.uhd2160 => '4K',
  Quality.unknown => l.qualityAuto,
};

const _qualityChoices = [
  Quality.sd,
  Quality.hd720,
  Quality.hd1080,
  Quality.uhd2160,
];

/// Réglages (story 3.7) : addons, langues, qualité, torrents, version et
/// à-propos. Les profils enfants passent par le PIN parent avant d'arriver
/// ici (voir `openSettings`).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionPresses = 0;

  void _tellFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.settingSaveFailed)));
  }

  /// Applique une modification ; un échec d'écriture est signalé sans casser
  /// l'écran.
  Future<void> _save(Future<void> Function() op) async {
    try {
      await op();
    } on Object {
      _tellFailure();
    }
  }

  Future<T?> _choose<T>({
    required String title,
    required List<(T, String)> options,
    required T? current,
  }) => showDialog<T>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        for (final (i, (value, label)) in options.indexed)
          FocusRing(
            child: ListTile(
              key: ValueKey('choice:$label'),
              autofocus: value == current || (current == null && i == 0),
              selected: value == current,
              leading: Icon(
                value == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(label),
              onTap: () => Navigator.pop(ctx, value),
            ),
          ),
      ],
    ),
  );

  void _onVersionTap() {
    if (ref.read(debugMenuUnlockedProvider)) return;
    _versionPresses++;
    if (_versionPresses >= debugUnlockPresses) {
      ref.read(debugMenuUnlockedProvider.notifier).unlock();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.debugUnlocked)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = ref.watch(localeProvider);
    final prefs = ref.watch(streamPrefsProvider).value ?? const StreamPrefs();
    final subLang = ref.watch(defaultSubtitleLangProvider).value;
    final torrents = ref.watch(torrentSettingsProvider);
    final version = ref.watch(appVersionProvider).value ?? '';
    final unlocked = ref.watch(debugMenuUnlockedProvider);
    final editor = ref.read(profilePrefsEditorProvider);
    final audio = prefs.languages.isEmpty ? null : prefs.languages.first;

    final tiles = <Widget>[
      _Header(l.settingsAddons),
      _Tile(
        id: 'addons',
        icon: Icons.extension_outlined,
        title: l.settingsAddons,
        subtitle: l.settingsAddonsHint,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const AddonsScreen())),
      ),
      if (ref.watch(syncServiceProvider) != null) ...[
        _Header(l.settingsAccount),
        _Tile(
          id: 'account',
          icon: Icons.sync,
          title: l.settingsAccount,
          subtitle: l.accountSettingsHint,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
          ),
        ),
      ],
      _Header(l.settingsBackup),
      _Tile(
        id: 'backupExport',
        icon: Icons.file_upload_outlined,
        title: l.backupExport,
        subtitle: l.backupExportHint,
        onTap: () => BackupFlows(context, ref).export(),
      ),
      _Tile(
        id: 'backupImport',
        icon: Icons.file_download_outlined,
        title: l.backupImport,
        subtitle: l.backupImportHint,
        onTap: () => BackupFlows(context, ref).import(),
      ),
      _Tile(
        id: 'otherImport',
        icon: Icons.swap_horiz,
        title: l.otherImportTitle,
        subtitle: l.otherImportHint,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const StremioImportScreen()),
        ),
      ),
      _Header(l.settingsLanguage),
      _Tile(
        id: 'locale',
        icon: Icons.language,
        title: l.settingsLanguage,
        subtitle: locale.languageCode == 'en' ? l.langEnglish : l.langFrench,
        onTap: () async {
          final picked = await _choose<Locale>(
            title: l.settingsLanguage,
            options: [
              for (final loc in supportedUiLocales)
                (loc, loc.languageCode == 'en' ? l.langEnglish : l.langFrench),
            ],
            current: locale,
          );
          if (picked != null) {
            await _save(() => ref.read(localeProvider.notifier).set(picked));
          }
        },
      ),
      _Header(l.settingsPlayback),
      _Tile(
        id: 'audio',
        icon: Icons.record_voice_over_outlined,
        title: l.settingsAudioLang,
        subtitle: _langName(l, audio),
        onTap: () async {
          final picked = await _choose<String>(
            title: l.settingsAudioLang,
            options: [for (final (c, n) in languageChoices(l)) (c, n)],
            current: audio,
          );
          if (picked != null) await _save(() => editor.setAudioLang(picked));
        },
      ),
      _Tile(
        id: 'subtitles',
        icon: Icons.subtitles_outlined,
        title: l.settingsSubtitleLang,
        subtitle: subLang == null || subLang == 'off'
            ? l.subtitlesNone
            : _langName(l, subLang),
        onTap: () async {
          final picked = await _choose<String>(
            title: l.settingsSubtitleLang,
            options: [
              ('off', l.subtitlesNone),
              for (final (c, n) in languageChoices(l)) (c, n),
            ],
            current: subLang ?? 'off',
          );
          if (picked != null) {
            await _save(() => editor.setSubtitleLang(picked));
          }
        },
      ),
      _Tile(
        id: 'quality',
        icon: Icons.high_quality_outlined,
        title: l.settingsQuality,
        subtitle: _qualityName(l, prefs.maxQuality),
        onTap: () async {
          final picked = await _choose<Quality>(
            title: l.settingsQuality,
            options: [for (final q in _qualityChoices) (q, _qualityName(l, q))],
            current: prefs.maxQuality,
          );
          if (picked != null) await _save(() => editor.setQuality(picked));
        },
      ),
      _Header(l.settingsDownloads),
      _Tile(
        id: 'cache',
        icon: Icons.storage_outlined,
        title: l.settingsTorrentCache,
        subtitle: l.cacheGb(torrents.cacheGb),
        onTap: () async {
          final picked = await _choose<int>(
            title: l.settingsTorrentCache,
            options: [
              for (final g in TorrentSettings.cacheChoicesGb) (g, l.cacheGb(g)),
            ],
            current: torrents.cacheGb,
          );
          if (picked != null) {
            await _save(
              () =>
                  ref.read(torrentSettingsProvider.notifier).setCacheGb(picked),
            );
          }
        },
      ),
      _Tile(
        id: 'upload',
        icon: Icons.upload_outlined,
        title: l.settingsUpload,
        subtitle: torrents.uploadKbps == 0
            ? l.uploadOff
            : l.uploadKbps(torrents.uploadKbps),
        onTap: () async {
          final picked = await _choose<int>(
            title: l.settingsUpload,
            options: [
              for (final k in TorrentSettings.uploadChoicesKbps)
                (k, k == 0 ? l.uploadOff : l.uploadKbps(k)),
            ],
            current: torrents.uploadKbps,
          );
          if (picked != null) {
            await _save(
              () => ref
                  .read(torrentSettingsProvider.notifier)
                  .setUploadKbps(picked),
            );
          }
        },
      ),
      _Tile(
        id: 'clearCache',
        icon: Icons.cleaning_services_outlined,
        title: l.settingsClearCacheOnExit,
        subtitle: torrents.clearCacheOnExit ? l.optionYes : l.optionNo,
        onTap: () async {
          final picked = await _choose<bool>(
            title: l.settingsClearCacheOnExit,
            options: [(true, l.optionYes), (false, l.optionNo)],
            current: torrents.clearCacheOnExit,
          );
          if (picked != null) {
            await _save(
              () => ref
                  .read(torrentSettingsProvider.notifier)
                  .setClearCacheOnExit(picked),
            );
          }
        },
      ),
      _Tile(
        id: 'requireVpn',
        icon: Icons.vpn_lock_outlined,
        title: l.settingsRequireVpn,
        subtitle: torrents.requireVpn ? l.optionYes : l.optionNo,
        onTap: () async {
          final picked = await _choose<bool>(
            title: l.settingsRequireVpn,
            options: [(true, l.optionYes), (false, l.optionNo)],
            current: torrents.requireVpn,
          );
          if (picked != null) {
            await _save(
              () => ref
                  .read(torrentSettingsProvider.notifier)
                  .setRequireVpn(picked),
            );
          }
        },
      ),
      _Tile(
        id: 'vpnInterface',
        icon: Icons.lan_outlined,
        title: l.settingsVpnInterface,
        subtitle: torrents.vpnInterface == null
            ? l.vpnAny
            : l.vpnInterfaceRequired(torrents.vpnInterface!),
        onTap: () async {
          List<NetInterface> up;
          try {
            up = await ref.read(networkProbeProvider).upInterfaces();
          } on Object {
            up = const [];
          }
          if (!mounted) return;
          // Interfaces VPN nommées actuellement actives, plus celle déjà
          // choisie (même si elle est éteinte) ; « n'importe quel VPN » en tête.
          final names = <String>{
            for (final i in up)
              if (i.isVpn && !i.anonymousVpn) i.name,
            ?torrents.vpnInterface,
          };
          final picked = await _choose<String>(
            title: l.settingsVpnInterface,
            options: [('', l.vpnAny), for (final n in names) (n, n)],
            current: torrents.vpnInterface ?? '',
          );
          if (picked != null) {
            await _save(
              () => ref
                  .read(torrentSettingsProvider.notifier)
                  .setVpnInterface(picked.isEmpty ? null : picked),
            );
          }
        },
      ),
      _Header(l.settingsVersion),
      _Tile(
        id: 'version',
        icon: Icons.info_outline,
        title: l.settingsVersion,
        subtitle: l.versionValue(version),
        onTap: _onVersionTap,
      ),
      if (unlocked)
        _Tile(
          id: 'debug',
          icon: Icons.bug_report_outlined,
          title: l.debugMenuTitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DebugMenuScreen()),
          ),
        ),
      _Header(l.settingsAbout),
      _Tile(
        id: 'about',
        icon: Icons.gavel_outlined,
        title: l.settingsAbout,
        subtitle: l.aboutLicense,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
      ),
    ];

    return TvScaffold(
      onBack: () => Navigator.maybeOf(context)?.maybePop(),
      child: Scaffold(
        appBar: AppBar(title: Text(l.settingsTitle)),
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: LumioSpacing.xl,
                vertical: LumioSpacing.md,
              ),
              children: tiles,
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(
      top: LumioSpacing.lg,
      bottom: LumioSpacing.xs,
    ),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: context.lumio.secondary),
      ),
    ),
  );
}

/// Ligne de réglage focalisable à la télécommande ; le dernier élément
/// focalisé est mémorisé (route `settings`) et rendu au retour d'un sous-écran.
class _Tile extends ConsumerWidget {
  const _Tile({
    required this.id,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final String id;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.read(focusMemoryProvider.notifier);
    final remembered = memory.restore(settingsRouteKey);
    return FocusRing(
      child: ListTile(
        key: ValueKey('setting:$id'),
        autofocus: remembered == id || (remembered == null && id == 'addons'),
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onFocusChange: (f) {
          if (f) memory.remember(settingsRouteKey, id);
        },
        onTap: onTap,
      ),
    );
  }
}

/// Écrans de debug sélectionnables par `--dart-define` ; ici accessibles
/// après 7 appuis sur la version.
class DebugMenuScreen extends StatelessWidget {
  const DebugMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.debugMenuTitle)),
      body: ListView(
        children: [
          ListTile(
            key: const ValueKey('debug:torrent'),
            autofocus: true,
            leading: const Icon(Icons.downloading),
            title: Text(l.debugTorrent),
            subtitle: const Text('LUMIO_DEBUG_TORRENT=1'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TorrentSpikeScreen(),
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('debug:player'),
            leading: const Icon(Icons.play_circle_outline),
            title: Text(l.debugPlayer),
            subtitle: const Text('LUMIO_DEBUG_PLAYER=1'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PlayerSpikeScreen(),
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('debug:loop'),
            leading: const Icon(Icons.loop),
            title: Text(l.debugLoop),
            subtitle: const Text('LUMIO_DEBUG_LOOP=1'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LoopDebugScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// À propos : licence GPL-3.0, crédits, licences des dépendances.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAbout)),
      body: ListView(
        padding: const EdgeInsets.all(LumioSpacing.xl),
        children: [
          Text(l.gplTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: LumioSpacing.sm),
          Text(l.gplText, style: theme.textTheme.bodyLarge),
          const SizedBox(height: LumioSpacing.lg),
          Text(l.aboutCredits, style: theme.textTheme.titleMedium),
          const SizedBox(height: LumioSpacing.xs),
          Text(l.creditsLibmpv),
          Text(l.creditsMediaKit),
          Text(l.creditsLibtorrent),
          Text(l.creditsFonts),
          const SizedBox(height: LumioSpacing.lg),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              key: const ValueKey('about:licenses'),
              autofocus: true,
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'Lumio'),
              child: Text(l.openSourceLicenses),
            ),
          ),
        ],
      ),
    );
  }
}
