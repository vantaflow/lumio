import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/features/addons/add_addon_dialog.dart' show AddonLogo;
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/features/addons/health_pill.dart';
import 'package:lumio/features/addons/health_providers.dart';
import 'package:lumio/features/jellyfin/jellyfin_providers.dart';
import 'package:lumio/features/jellyfin/jellyfin_screen.dart';
import 'package:lumio/features/local/local_providers.dart';
import 'package:lumio/features/local/local_screen.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart' show AddonHealth, HealthLevel;

/// Clé de la mémoire du focus des Réglages (partagée avec la page).
const _settingsKey = 'settings';

/// Contenu de « Réglages › Sources » (maquette TV10) : addons en ligne dans la
/// page (OK = menu d'actions, interrupteur à droite), puis deux cartes
/// « Dossiers locaux » et « Serveurs Jellyfin » côte à côte.
class SourcesBody extends ConsumerWidget {
  const SourcesBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final addons = ref.watch(addonsProvider).value ?? const <InstalledAddon>[];
    final health =
        ref.watch(healthSnapshotProvider).value ??
        const <String, AddonHealth>{};
    final folders = ref.watch(localFoldersProvider).value ?? const [];
    final servers = ref.watch(jellyfinServersProvider).value ?? const [];
    final memory = ref.read(focusMemoryProvider.notifier);
    final remembered = memory.restore(_settingsKey);
    Future<void> run(Future<void> Function() op) async {
      try {
        await op();
      } catch (_) {
        if (context.mounted) {
          showTvSnack(context, l.addonActionFailed, error: true);
        }
        await ref.read(addonsProvider.notifier).refresh().catchError((_) {});
      }
    }

    String ago(int ms) {
      final d = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ms),
      );
      if (d.inMinutes < 1) return l.agoMinutes(1);
      if (d.inHours < 1) return l.agoMinutes(d.inMinutes);
      if (d.inDays < 1) return l.agoHours(d.inHours);
      return l.agoDays(d.inDays);
    }

    final lastScan = folders.fold<int>(
      0,
      (m, f) => f.lastScanAt > m ? f.lastScanAt : m,
    );
    final folderSummary = [
      if (folders.isEmpty)
        l.localFoldersHint
      else
        folders.map((f) => f.path).join(' · '),
    ].join();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TvSectionLabel(l.secAddonsPriority, top: 0),
        const SizedBox(height: 2),
        for (var i = 0; i < addons.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
            child: _AddonRow(
              addon: addons[i],
              health: health[addons[i].id] ?? AddonHealth.empty,
              autofocus: remembered == 'addon:${addons[i].id}',
              onFocus: () =>
                  memory.remember(_settingsKey, 'addon:${addons[i].id}'),
              onToggle: (v) => run(
                () => ref
                    .read(addonsProvider.notifier)
                    .setEnabled(addons[i].id, v),
              ),
              onMenu: () => _openMenu(
                context,
                ref,
                addons[i],
                health[addons[i].id] ?? AddonHealth.empty,
                canMoveUp: i > 0,
                canMoveDown: i < addons.length - 1,
                run: run,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 12),
          child: Text(
            l.addonsMenuHint,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 24,
              height: 1.35,
              color: context.lumio.textMuted,
            ),
          ),
        ),
        TvSectionLabel(l.secPersonalSources, top: 28),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SourceCard(
                id: 'localFolders',
                autofocus: remembered == 'localFolders',
                title: l.localFolders,
                trailing: Text(
                  l.localFoldersCount(folders.length),
                  style: _muted(context),
                ),
                summary: [
                  folderSummary,
                  if (lastScan > 0) l.localLastScan(ago(lastScan)),
                ].join(' — '),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LocalFoldersScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _SourceCard(
                id: 'jellyfin',
                autofocus: remembered == 'jellyfin',
                title: l.jellyfinServers,
                trailing: Text(
                  l.jellyfinServersCount(servers.length),
                  style: _muted(context),
                ),
                summary: servers.isEmpty
                    ? l.jellyfinServersHint
                    : servers.map((s) => s.name).join(' · '),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const JellyfinServersScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static TextStyle _muted(BuildContext context) => TextStyle(
    fontFamily: 'Manrope',
    fontSize: 24,
    height: 1.35,
    color: context.lumio.textMuted,
  );

  /// Menu d'actions d'un addon (OK sur la ligne) : monter, descendre,
  /// réinitialiser les mesures, supprimer ; actions déjà utilisées par
  /// l'écran Addons.
  Future<void> _openMenu(
    BuildContext context,
    WidgetRef ref,
    InstalledAddon a,
    AddonHealth health, {
    required bool canMoveUp,
    required bool canMoveDown,
    required Future<void> Function(Future<void> Function()) run,
  }) async {
    final l = context.l10n;
    final ctl = ref.read(addonsProvider.notifier);
    final entries = <(String, LumioIcon, String, bool)>[
      if (a.manifest != null && canMoveUp)
        ('up', LumioIcon.arrowUp, l.menuMoveUp, false),
      if (a.manifest != null && canMoveDown)
        ('down', LumioIcon.arrowDown, l.menuMoveDown, false),
      if (a.manifest != null && health.samples > 0)
        ('reset', LumioIcon.refresh, l.menuResetHealth, false),
      ('delete', LumioIcon.trash, l.delete, true),
    ];
    final picked = await showTvPanel<String>(
      context,
      builder: (ctx) {
        final c = ctx.lumio;
        return TvPanel(
          width: 760,
          title: a.name,
          onBack: () => Navigator.of(ctx).pop(),
          children: [
            for (final (i, e) in entries.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TvTile(
                  key: ValueKey('addon-menu:${e.$1}'),
                  minHeight: 88,
                  autofocus: i == 0,
                  color: c.surfaceRaised,
                  semanticLabel: e.$3,
                  onSelect: () => Navigator.of(ctx).pop(e.$1),
                  child: Row(
                    children: [
                      LumioIconView(
                        e.$2,
                        size: 36,
                        color: e.$4 ? c.error : c.textMuted,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          e.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            fontVariations: const [FontVariation.weight(700)],
                            color: e.$4 ? c.error : c.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (picked == null || !context.mounted) return;
    switch (picked) {
      case 'up':
        await run(() => ctl.move(a.id, -1));
      case 'down':
        await run(() => ctl.move(a.id, 1));
      case 'reset':
        await ref.read(addonHealthServiceProvider).reset(a.id);
      case 'delete':
        final ok = await showTvConfirm(
          context,
          title: l.removeAddonTitle,
          body: l.removeAddonBody(a.name),
          confirmLabel: l.delete,
          destructive: true,
        );
        if (ok && context.mounted) await run(() => ctl.remove(a.id));
    }
  }
}

/// Ligne d'addon (maquette TV10 `.ar`) : logo 64, nom et capacités, santé,
/// interrupteur. OK ouvre le menu ; l'interrupteur est un second arrêt de
/// focus.
class _AddonRow extends StatelessWidget {
  const _AddonRow({
    required this.addon,
    required this.health,
    required this.autofocus,
    required this.onFocus,
    required this.onToggle,
    required this.onMenu,
  });

  final InstalledAddon addon;
  final AddonHealth health;
  final bool autofocus;
  final VoidCallback onFocus;
  final ValueChanged<bool> onToggle;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final l = context.l10n;
    final m = addon.manifest;
    final caps = m == null
        ? l.addonBroken
        : addonCapabilities(
            [for (final r in m.resources) r.name],
            m.catalogs.isNotEmpty,
            m.types,
            l,
          );
    final sub = [
      caps,
      if (m != null && !addon.enabled)
        l.addonDisabled.toLowerCase()
      else if (m != null && health.samples > 0)
        latencyLabel(health.median, l.localeName),
    ].join(' · ');
    final known = m != null && health.level != HealthLevel.unknown;
    final label = switch (health.level) {
      HealthLevel.reliable => l.healthShortGood,
      HealthLevel.slow => l.healthShortSlow,
      HealthLevel.failing => l.healthShortOffline,
      HealthLevel.unknown => '',
    };
    final dot = switch (health.level) {
      HealthLevel.reliable => c.success,
      HealthLevel.slow => c.accent,
      HealthLevel.failing => c.error,
      HealthLevel.unknown => c.textMuted,
    };
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: FocusableCard(
              key: ValueKey('addon-row:${addon.id}'),
              autofocus: autofocus,
              scale: 1.015,
              borderRadius: BorderRadius.circular(22),
              semanticLabel: [addon.name, sub, if (known) label].join(', '),
              onFocusChange: (f) {
                if (f) onFocus();
              },
              onSelect: onMenu,
              child: Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Row(
                  children: [
                    AddonLogo(logo: addon.logo, name: addon.name, size: 64),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            addon.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              fontVariations: [FontVariation.weight(700)],
                            ),
                          ),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 24,
                              height: 1.35,
                              color: m == null ? c.error : c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (known) ...[
                      const SizedBox(width: 24),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dot,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontVariations: [FontVariation.weight(700)],
                          color: Color(0xFFC9D0DA),
                        ),
                      ),
                    ],
                    const SizedBox(width: 24),
                  ],
                ),
              ),
            ),
          ),
          if (m != null)
            Padding(
              padding: const EdgeInsets.only(right: 32),
              child: FocusableCard(
                key: ValueKey('addon-switch:${addon.id}'),
                scale: 1.06,
                borderRadius: BorderRadius.circular(23),
                semanticLabel: l.enableAddon(addon.name),
                onSelect: () => onToggle(!addon.enabled),
                child: Semantics(
                  toggled: addon.enabled,
                  child: TvSwitch(value: addon.enabled),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Carte de source personnelle (maquette TV10 `.tile`) : 150 de haut, titre
/// et information à droite, résumé dessous ; OK ouvre la gestion.
class _SourceCard extends ConsumerWidget {
  const _SourceCard({
    required this.id,
    required this.title,
    required this.trailing,
    required this.summary,
    required this.onTap,
    required this.autofocus,
  });

  final String id;
  final String title;
  final Widget trailing;
  final String summary;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lumio;
    final memory = ref.read(focusMemoryProvider.notifier);
    return SizedBox(
      height: 150,
      child: FocusableCard(
        key: ValueKey('setting:$id'),
        autofocus: autofocus,
        scale: 1.015,
        borderRadius: BorderRadius.circular(22),
        semanticLabel: '$title, $summary',
        onFocusChange: (f) {
          if (f) memory.remember(_settingsKey, id);
        },
        onSelect: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        fontVariations: [FontVariation.weight(700)],
                      ),
                    ),
                  ),
                  trailing,
                ],
              ),
              Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 24,
                  height: 1.35,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
