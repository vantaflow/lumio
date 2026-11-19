import 'package:flutter/material.dart';
import 'package:lumio/ui/common/tv_scroll_clip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/debug/loop_debug.dart';
import 'package:lumio/debug/player_spike.dart';
import 'package:lumio/debug/torrent_spike.dart';
import 'package:lumio/features/addons/add_addon_screen.dart';
import 'package:lumio/features/home/tv_home.dart' show LumioMark;
import 'package:lumio/features/phone/phone_providers.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart'
    show kidLabel, switchProfileFlow;
import 'package:lumio/features/party/party_providers.dart';
import 'package:lumio/features/party/party_screen.dart';
import 'package:lumio/features/settings/backup_section.dart';
import 'package:lumio/features/detail/playback_service.dart'
    show streamPrefsProvider;
import 'package:lumio/features/profiles/pin_dialog.dart' show requireParent;
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/features/settings/sources_page.dart';
import 'package:lumio/features/settings/stremio_import_screen.dart';
import 'package:lumio/features/tracking/tracking_screen.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/torrent/torrent_providers.dart'
    show cacheManagerProvider, networkProbeProvider;
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart'
    show NetInterface, Quality, StreamPrefs;

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

/// Octets utilisés par le cache torrents (0 si illisible).
final torrentCacheUsedProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    return await ref.read(cacheManagerProvider).usedBytes();
  } on Object {
    return 0;
  }
});

/// Interfaces réseau actives (vide si la sonde échoue).
final upInterfacesProvider = FutureProvider.autoDispose<List<NetInterface>>((
  ref,
) async {
  try {
    return await ref.read(networkProbeProvider).upInterfaces();
  } on Object {
    return const [];
  }
});

/// Catégories du rail des réglages (maquette TV10).
enum SettingsCategory {
  general,
  sources,
  playback,
  torrents,
  profiles,
  tracking,
  party,
  backup,
}

/// Réglages (maquettes TV10, TV14, TV15, TV47) : rail de catégories à gauche,
/// page de la catégorie à droite. Les profils enfants passent par le PIN
/// parent avant d'arriver ici (voir `openSettings`).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionPresses = 0;
  SettingsCategory _cat = SettingsCategory.general;

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
  }) => showTvChoice<T>(
    context,
    title: title,
    options: options,
    current: current,
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

  Future<void> _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  List<SettingsCategory> get _cats => [
    SettingsCategory.general,
    SettingsCategory.sources,
    SettingsCategory.playback,
    SettingsCategory.torrents,
    SettingsCategory.profiles,
    SettingsCategory.tracking,
    if (ref.watch(partyClientProvider) != null) SettingsCategory.party,
    SettingsCategory.backup,
  ];

  String _catLabel(AppLocalizations l, SettingsCategory c) => switch (c) {
    SettingsCategory.sources => l.settingsCatSources,
    SettingsCategory.playback => l.settingsCatPlayback,
    SettingsCategory.torrents => l.settingsCatTorrents,
    SettingsCategory.profiles => l.settingsCatProfiles,
    SettingsCategory.tracking => l.settingsCatTracking,
    SettingsCategory.party => l.partyTitle,
    SettingsCategory.backup => l.settingsCatBackup,
    SettingsCategory.general => l.settingsCatGeneral,
  };

  LumioIcon _catIcon(SettingsCategory c) => switch (c) {
    SettingsCategory.sources => LumioIcon.plus,
    SettingsCategory.playback => LumioIcon.play,
    SettingsCategory.torrents => LumioIcon.torrents,
    SettingsCategory.profiles => LumioIcon.user,
    SettingsCategory.tracking => LumioIcon.tracking,
    SettingsCategory.party => LumioIcon.group,
    SettingsCategory.backup => LumioIcon.download,
    SettingsCategory.general => LumioIcon.general,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final cats = _cats;
    final memory = ref.read(focusMemoryProvider.notifier);
    final rememberedCat = memory.restore(settingsRouteKey, row: 'rail');
    final narrow = MediaQuery.sizeOf(context).width < 960;
    final current = cats.contains(_cat) ? _cat : cats.first;
    Widget railItem(SettingsCategory cat) => _RailItem(
      key: ValueKey('rail:${cat.name}'),
      icon: _catIcon(cat),
      label: _catLabel(l, cat),
      selected: _cat == cat,
      autofocus: rememberedCat == null
          ? cat == SettingsCategory.general
          : rememberedCat == cat.name,
      onFocus: () {
        memory.remember(settingsRouteKey, cat.name, row: 'rail');
        if (_cat != cat) setState(() => _cat = cat);
      },
      onSelect: () => setState(() => _cat = cat),
    );
    final title = Semantics(
      header: true,
      child: Text(
        l.settingsTitle,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: narrow ? 28 : 44,
          height: 1.1,
        ),
      ),
    );
    return TvScaffold(
      onBack: () => Navigator.maybeOf(context)?.maybePop(),
      child: Scaffold(
        body: narrow
            ? SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: title,
                    ),
                    SizedBox(
                      height: 84,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final cat in cats)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SizedBox(width: 240, child: railItem(cat)),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _page(context, current),
                      ),
                    ),
                  ],
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 480,
                    color: c.bgAlt,
                    padding: const EdgeInsets.fromLTRB(64, 56, 32, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Row(
                            children: [
                              const LumioMark(size: 40),
                              const SizedBox(width: 16),
                              Expanded(child: title),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ProfileCard(
                          onChange: () => switchProfileFlow(
                            context,
                            ref,
                            beforeSelect: () => Navigator.of(
                              context,
                            ).popUntil((r) => r.isFirst),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: TvScrollClip(
                            child: SingleChildScrollView(
                              clipBehavior: Clip.none,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final cat in cats)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: railItem(cat),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _PhoneCard(
                          onOpen: () => showAddAddonScreen(
                            context,
                            initialTab: AddAddonTab.phone,
                            title: l.settingsManagePhone,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${l.versionValue(ref.watch(appVersionProvider).value ?? '')}'
                          ' · ${l.settingsBackHome}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 24, color: c.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(72, 72, 96, 0),
                      child: _page(context, current),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _page(BuildContext context, SettingsCategory cat) {
    return switch (cat) {
      SettingsCategory.sources => _sourcesPage(context),
      SettingsCategory.playback => _playbackPage(context),
      SettingsCategory.torrents => _torrentsPage(context),
      SettingsCategory.profiles => _profilesPage(context),
      SettingsCategory.tracking => _trackingPage(context),
      SettingsCategory.party => _partyPage(context),
      SettingsCategory.backup => _backupPage(context),
      SettingsCategory.general => _generalPage(context),
    };
  }

  // --- pages ---

  Widget _sourcesPage(BuildContext context) {
    final l = context.l10n;
    return _Page(
      key: const ValueKey('page:sources'),
      title: l.settingsCatSources,
      subtitle: l.settingsSourcesHint,
      headGap: 43,
      bleed: true,
      action: TvButton(
        key: const ValueKey('setting:addAddon'),
        label: '+ ${l.addAddon}',
        height: 72,
        fontSize: 28,
        onPressed: () => showAddAddonScreen(context),
      ),
      children: const [SourcesBody()],
    );
  }

  Widget _playbackPage(BuildContext context) {
    final l = context.l10n;
    final prefs = ref.watch(streamPrefsProvider).value ?? const StreamPrefs();
    final subLang = ref.watch(defaultSubtitleLangProvider).value;
    final editor = ref.read(profilePrefsEditorProvider);
    final audio = prefs.languages.isEmpty ? null : prefs.languages.first;
    final name = ref.watch(currentProfileProvider)?.name;
    return _Page(
      key: const ValueKey('page:playback'),
      title: l.settingsCatPlayback,
      subtitle: name == null ? null : l.settingsForProfile(name),
      headGap: 7,
      children: [
        _Section(l.secSourceChoice),
        _Tile(
          id: 'quality',
          minHeight: 104,
          title: l.settingsQuality,
          value: _qualityName(l, prefs.maxQuality),
          onTap: () async {
            final picked = await _choose<Quality>(
              title: l.settingsQuality,
              options: [
                for (final q in _qualityChoices) (q, _qualityName(l, q)),
              ],
              current: prefs.maxQuality,
            );
            if (picked != null) await _save(() => editor.setQuality(picked));
          },
        ),
        _SwitchTile(
          id: 'preferDirect',
          minHeight: 104,
          title: l.settingsPreferDirect,
          subtitle: l.preferDirectOn,
          value: prefs.preferDirect,
          onChanged: (v) => _save(() => editor.setPreferDirect(v)),
        ),
        _Section(l.secLanguages),
        _Tile(
          id: 'audio',
          minHeight: 104,
          title: l.settingsAudioLang,
          value: _langName(l, audio),
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
          minHeight: 104,
          title: l.settingsSubtitleLang,
          value: subLang == null || subLang == 'off'
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
      ],
    );
  }

  Widget _torrentsPage(BuildContext context) {
    final l = context.l10n;
    final torrents = ref.watch(torrentSettingsProvider);
    final ctl = ref.read(torrentSettingsProvider.notifier);
    return _Page(
      key: const ValueKey('page:torrents'),
      title: l.settingsCatTorrents,
      children: [
        _VpnCard(requireVpn: torrents.requireVpn),
        _Section(l.secProtection),
        _SwitchTile(
          id: 'requireVpn',
          title: l.settingsRequireVpn,
          value: torrents.requireVpn,
          onChanged: (v) => _save(() => ctl.setRequireVpn(v)),
        ),
        _Tile(
          id: 'vpnInterface',
          title: l.settingsVpnInterface,
          value: torrents.vpnInterface == null
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
                () => ctl.setVpnInterface(picked.isEmpty ? null : picked),
              );
            }
          },
        ),
        _Section(l.secStorage),
        _Tile(
          id: 'cache',
          title: l.settingsTorrentCache,
          gauge: _cacheGauge(torrents.cacheGb),
          valueNote: l.cacheUsedOf(_gbText(_cacheUsed(), l)),
          value: l.cacheGb(torrents.cacheGb),
          onTap: () async {
            final picked = await _choose<int>(
              title: l.settingsTorrentCache,
              options: [
                for (final g in TorrentSettings.cacheChoicesGb)
                  (g, l.cacheGb(g)),
              ],
              current: torrents.cacheGb,
            );
            if (picked != null) await _save(() => ctl.setCacheGb(picked));
          },
        ),
        _Tile(
          id: 'upload',
          title: l.settingsUpload,
          value: torrents.uploadKbps == 0
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
            if (picked != null) await _save(() => ctl.setUploadKbps(picked));
          },
        ),
        _SwitchTile(
          id: 'clearCache',
          title: l.settingsClearCacheOnExit,
          value: torrents.clearCacheOnExit,
          onChanged: (v) => _save(() => ctl.setClearCacheOnExit(v)),
        ),
      ],
    );
  }

  int _cacheUsed() => ref.watch(torrentCacheUsedProvider).value ?? 0;

  String _gbText(int bytes, AppLocalizations l) {
    final gb = bytes / (1024 * 1024 * 1024);
    final txt = NumberFormat('0.0', l.localeName).format(gb);
    return l.sizeGbDecimal(txt);
  }

  double _cacheGauge(int cacheGb) {
    if (cacheGb <= 0) return 0;
    return (_cacheUsed() / (cacheGb * 1024 * 1024 * 1024)).clamp(0.0, 1.0);
  }

  Widget _profilesPage(BuildContext context) {
    final l = context.l10n;
    final profiles = ref.watch(profilesProvider).value ?? const [];
    final name = ref.watch(currentProfileProvider)?.name;
    return _Page(
      key: const ValueKey('page:profiles'),
      title: l.settingsCatProfiles,
      subtitle: l.settingsProfilesHint,
      children: [
        _Section(l.secProfiles),
        _Tile(
          id: 'profiles',
          title: l.manageProfiles,
          subtitle: [
            l.settingsProfilesCount(profiles.length),
            ?name,
          ].join(' · '),
          onTap: () => switchProfileFlow(
            context,
            ref,
            beforeSelect: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
            manage: true,
          ),
        ),
      ],
    );
  }

  Widget _trackingPage(BuildContext context) {
    final l = context.l10n;
    return _Page(
      key: const ValueKey('page:tracking'),
      title: l.trackingTitle,
      subtitle: l.trackingHint,
      headGap: 42,
      children: const [TrackingBody(inPage: true)],
    );
  }

  Widget _partyPage(BuildContext context) {
    final l = context.l10n;
    return _Page(
      key: const ValueKey('page:party'),
      title: l.partyTitle,
      subtitle: l.partyHint,
      children: [
        _Tile(
          id: 'party',
          title: l.partyTitle,
          subtitle: l.partyHint,
          onTap: () => _push(const PartyScreen()),
        ),
      ],
    );
  }

  Widget _backupPage(BuildContext context) {
    final l = context.l10n;
    return _Page(
      key: const ValueKey('page:backup'),
      title: l.settingsCatBackup,
      children: [
        _Section(l.settingsBackup),
        _Tile(
          id: 'backupExport',
          icon: LumioIcon.upload,
          minHeight: 112,
          title: l.backupExport,
          subtitle: l.backupExportHint,
          onTap: () => BackupFlows(context, ref).export(),
        ),
        _Tile(
          id: 'backupImport',
          icon: LumioIcon.download,
          minHeight: 112,
          title: l.backupImport,
          subtitle: l.backupImportHint,
          onTap: () => BackupFlows(context, ref).import(),
        ),
        _Tile(
          id: 'otherImport',
          icon: LumioIcon.document,
          minHeight: 112,
          title: l.otherImportTitle,
          subtitle: l.otherImportHint,
          onTap: () => _push(const StremioImportScreen()),
        ),
      ],
    );
  }

  Widget _generalPage(BuildContext context) {
    final l = context.l10n;
    final locale = ref.watch(localeProvider);
    final version = ref.watch(appVersionProvider).value ?? '';
    final unlocked = ref.watch(debugMenuUnlockedProvider);
    return _Page(
      key: const ValueKey('page:general'),
      title: l.settingsCatGeneral,
      headGap: 41,
      children: [
        _Section(l.secInterfaceLanguage, top: 0),
        _Tile(
          id: 'locale',
          minHeight: 112,
          title: l.settingsLanguage,
          subtitle: locale.languageCode == 'en' ? l.langEnglish : l.langFrench,
          onTap: () async {
            final picked = await _choose<Locale>(
              title: l.settingsLanguage,
              options: [
                for (final loc in supportedUiLocales)
                  (
                    loc,
                    loc.languageCode == 'en' ? l.langEnglish : l.langFrench,
                  ),
              ],
              current: locale,
            );
            if (picked != null) {
              await _save(() => ref.read(localeProvider.notifier).set(picked));
            }
          },
        ),
        _Section(l.settingsVersion, top: 24),
        _Tile(
          id: 'version',
          minHeight: 112,
          title: l.settingsVersion,
          subtitle: l.versionValue(version),
          onTap: _onVersionTap,
        ),
        if (unlocked)
          _Tile(
            id: 'debug',
            title: l.debugMenuTitle,
            onTap: () => _push(const DebugMenuScreen()),
          ),
        _Section(l.settingsAbout, top: 24),
        _Tile(
          id: 'about',
          minHeight: 112,
          title: l.settingsAbout,
          subtitle: l.aboutLicense,
          onTap: () => _push(const AboutScreen()),
        ),
      ],
    );
  }
}

/// Carte d'état du VPN en tête de « Torrents et VPN » (maquette TV15).
class _VpnCard extends ConsumerWidget {
  const _VpnCard({required this.requireVpn});

  final bool requireVpn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lumio;
    final l = context.l10n;
    final up = ref.watch(upInterfacesProvider).value ?? const <NetInterface>[];
    final vpn = up.where((i) => i.isVpn).toList();
    final active = vpn.isNotEmpty;
    final named = vpn.where((i) => !i.anonymousVpn).toList();
    final name = (named.isNotEmpty ? named.first : vpn.firstOrNull)?.name ?? '';
    return Container(
      key: const ValueKey('settings-vpn-card'),
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          LumioIconView(
            LumioIcon.shield,
            size: 56,
            color: active ? c.success : c.accent,
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? l.vpnCardActive(name) : l.vpnNone,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    fontVariations: [FontVariation.weight(700)],
                  ),
                ),
                if (requireVpn)
                  Text(
                    l.vpnCardStopHint,
                    style: TextStyle(fontSize: 24, color: c.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.32,
            ),
            child: Text(
              l.vpnCardIpHint,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 24, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte « Gérer depuis le téléphone » en bas du rail (maquette TV10) : ouvre
/// l'onglet « Depuis le téléphone » ; l'adresse affichée est celle que la
/// page prendra (rien n'écoute tant que l'écran n'est pas ouvert).
class _PhoneCard extends ConsumerWidget {
  const _PhoneCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lumio;
    final l = context.l10n;
    final ip = ref.watch(lanAddressProvider).value;
    // Rien n'écoute tant que l'écran n'est pas ouvert : pas d'adresse ici
    // (elle ne répondrait pas), seulement l'invitation à ouvrir la page.
    final sub = ip == null
        ? l.settingsManagePhoneNoNetwork
        : l.settingsManagePhonePress;
    return FocusableCard(
      key: const ValueKey('settings-phone'),
      scale: 1.02,
      borderRadius: BorderRadius.circular(20),
      semanticLabel: '${l.settingsManagePhone}, $sub',
      onSelect: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: c.surfaceFocus, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CustomPaint(
              size: const Size(44, 44),
              painter: _QrGlyphPainter(c.secondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.settingsManagePhone,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontVariations: [FontVariation.weight(700)],
                      height: 1.3,
                    ),
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.3,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pictogramme QR de la maquette TV10 (viewBox 24, trait 2).
class _QrGlyphPainter extends CustomPainter {
  const _QrGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k;
    for (final (x, y) in const [(3.0, 3.0), (14.0, 3.0), (3.0, 14.0)]) {
      canvas.drawRect(Rect.fromLTWH(x * k, y * k, 7 * k, 7 * k), p);
    }
    canvas.drawRect(Rect.fromLTWH(14 * k, 14 * k, 3 * k, 3 * k), p);
    canvas.drawLine(Offset(20 * k, 14 * k), Offset(20 * k, 21 * k), p);
    canvas.drawLine(Offset(14 * k, 20 * k), Offset(17 * k, 20 * k), p);
  }

  @override
  bool shouldRepaint(_QrGlyphPainter old) => old.color != color;
}

/// Carte du profil actif en haut du rail (maquette TV10).
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.onChange});

  final VoidCallback onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lumio;
    final l = context.l10n;
    final p = ref.watch(currentProfileProvider);
    final name = (p?.name ?? '').trim();
    final kind = p == null ? '' : (p.isKid ? kidLabel(p, l) : l.profileAdult);
    return FocusableCard(
      key: const ValueKey('settings-profile'),
      scale: 1.02,
      borderRadius: BorderRadius.circular(20),
      semanticLabel: '$name, ${l.profileChange}',
      onSelect: onChange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.accent,
              ),
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation.weight(700)],
                  color: c.onAccent,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontVariations: [FontVariation.weight(700)],
                    ),
                  ),
                  Text(
                    kind,
                    style: TextStyle(fontSize: 24, color: c.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              l.profileChange,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(600)],
                color: c.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrée du rail : prend le focus = affiche sa page (maquette `.mi`).
class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.autofocus,
    required this.onFocus,
    required this.onSelect,
  });

  final LumioIcon icon;
  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onFocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return FocusableCard(
      autofocus: autofocus,
      scale: 1.02,
      borderRadius: BorderRadius.circular(16),
      semanticLabel: label,
      onFocusChange: (f) {
        if (f) onFocus();
      },
      onSelect: onSelect,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? c.surfaceFocus : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            LumioIconView(
              icon,
              size: 30,
              color: selected ? c.accent : c.textMuted,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation.weight(600)],
                    height: 1.2,
                    color: selected ? c.text : c.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page de catégorie : titre 56, sous-titre, action à droite, lignes.
class _Page extends StatelessWidget {
  const _Page({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.action,
    this.headGap = 0,
    this.bleed = false,
  });

  /// Contenu aligné sur la marge de la page (anneaux de focus visibles hors
  /// de la liste) : maquette TV10.
  final bool bleed;

  /// Espace entre l'en-tête et la première section (maquettes : 36 sur
  /// Général et Sources, 0 ailleurs).
  final double headGap;

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 960;
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: t.headlineLarge?.copyWith(
              fontSize: narrow ? 32 : 44,
              height: 1.1,
            ),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(fontSize: 24, color: c.textMuted),
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (narrow) ...[
          head,
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: action),
        ] else
          Row(
            children: [
              Expanded(child: head),
              if (action != null) ...[const SizedBox(width: 24), action!],
            ],
          ),
        SizedBox(height: headGap),
        Expanded(
          child: ListView(
            clipBehavior: bleed ? Clip.none : Clip.hardEdge,
            padding: EdgeInsets.only(
              bottom: 48,
              left: bleed ? 0 : 6,
              right: bleed ? 0 : 6,
            ),
            children: children,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text, {this.top = 28});
  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => TvSectionLabel(text, top: top);
}

/// Ligne de réglage (maquettes `.r`) : titre, description, valeur en pastille
/// ou chevron ; le dernier élément focalisé est mémorisé et rendu au retour
/// d'un sous-écran.
class _Tile extends ConsumerWidget {
  const _Tile({
    required this.id,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.gauge,
    this.valueNote,
    this.minHeight = 96,
    this.icon,
  });

  /// Icône ambre de tête de ligne (maquette TV33).
  final LumioIcon? icon;

  final double minHeight;

  final String id;
  final String title;
  final String? subtitle;
  final String? value;
  final double? gauge;
  final String? valueNote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.read(focusMemoryProvider.notifier);
    final remembered = memory.restore(settingsRouteKey);
    final c = context.lumio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TvTile(
        key: ValueKey('setting:$id'),
        autofocus: remembered == id,
        minHeight: minHeight,
        semanticLabel: [title, ?subtitle, ?value].join(', '),
        onFocusChange: (f) {
          if (f) memory.remember(settingsRouteKey, id);
        },
        onSelect: onTap,
        child: Row(
          children: [
            if (icon != null) ...[
              LumioIconView(icon!, size: 40, color: c.accent),
              const SizedBox(width: 24),
            ],
            Expanded(
              child: gauge == null
                  ? TvTileText(title: title, subtitle: subtitle)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TvTileText(title: title),
                        const SizedBox(height: 10),
                        Container(
                          key: const ValueKey('setting:cache:gauge'),
                          height: 10,
                          width: 520,
                          decoration: BoxDecoration(
                            color: c.outline,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: gauge,
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.accent,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (valueNote != null) ...[
              Text(
                valueNote!,
                style: TextStyle(fontSize: 24, color: c.textMuted),
              ),
              const SizedBox(width: 24),
            ] else
              const SizedBox(width: 24),
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: c.surfaceFocus,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            fontVariations: [FontVariation.weight(600)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      LumioIconView(
                        LumioIcon.chevron,
                        size: 20,
                        color: c.textMuted,
                        strokeWidth: 2.5,
                      ),
                    ],
                  ),
                ),
              )
            else
              LumioIconView(LumioIcon.chevronAlt, size: 32, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends ConsumerWidget {
  const _SwitchTile({
    required this.id,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.minHeight = 96,
  });

  final double minHeight;
  final String id;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.read(focusMemoryProvider.notifier);
    final remembered = memory.restore(settingsRouteKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TvSwitchTile(
        key: ValueKey('setting:$id'),
        autofocus: remembered == id,
        minHeight: minHeight,
        color: context.lumio.surface,
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
        onFocusChange: (f) {
          if (f) memory.remember(settingsRouteKey, id);
        },
      ),
    );
  }
}

/// Menu de debug (réservé au développement), après 7 appuis sur la version.
class DebugMenuScreen extends StatelessWidget {
  const DebugMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget item(
      String key,
      String title,
      String sub,
      Widget screen, {
      bool first = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TvTile(
        key: ValueKey(key),
        autofocus: first,
        onSelect: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => screen)),
        child: Row(
          children: [
            Expanded(
              child: TvTileText(title: title, subtitle: sub),
            ),
            LumioIconView(
              LumioIcon.chevronAlt,
              size: 32,
              color: context.lumio.textMuted,
            ),
          ],
        ),
      ),
    );
    return TvScreen(
      title: l.debugMenuTitle,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, left: 6, right: 6),
        children: [
          item(
            'debug:torrent',
            l.debugTorrent,
            'LUMIO_DEBUG_TORRENT=1',
            const TorrentSpikeScreen(),
            first: true,
          ),
          item(
            'debug:player',
            l.debugPlayer,
            'LUMIO_DEBUG_PLAYER=1',
            const PlayerSpikeScreen(),
          ),
          item(
            'debug:loop',
            l.debugLoop,
            'LUMIO_DEBUG_LOOP=1',
            const LoopDebugScreen(),
          ),
        ],
      ),
    );
  }
}

/// À propos (maquette TV34) : licence GPL-3.0, crédits, licences des
/// dépendances.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = context.lumio;
    TextStyle md() => theme.textTheme.bodyLarge!.copyWith(
      fontSize: 28,
      color: const Color(0xFFC9D0DA),
      height: 1.4,
    );
    // Maquette TV34 : colonne de 1500, titres 52 et 36, texte 30 puis 28.
    final lead = md().copyWith(fontSize: 30);
    final credit = md().copyWith(height: 1.7);
    return TvScreen(
      title: l.settingsAbout,
      child: TvScrollClip(
        child: ListView(
          padding: EdgeInsets.zero,
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1308),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.gplTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 52,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(l.gplText, style: lead),
                    const SizedBox(height: 34),
                    Text(
                      l.aboutCredits,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 36,
                        height: 1.15,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(l.creditsLibmpv, style: credit),
                    Text(l.creditsMediaKit, style: credit),
                    Text(l.creditsLibtorrent, style: credit),
                    Text(l.creditsFonts, style: credit),
                    const SizedBox(height: 34),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TvButton(
                        key: const ValueKey('about:licenses'),
                        autofocus: true,
                        kind: TvButtonKind.secondary,
                        height: 76,
                        fontSize: 28,
                        label: l.openSourceLicenses,
                        onPressed: () => showLicensePage(
                          context: context,
                          applicationName: 'Lumio',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
