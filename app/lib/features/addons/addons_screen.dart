import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/features/addons/add_addon_dialog.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/features/addons/health_pill.dart';
import 'package:lumio/features/addons/health_providers.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart' show AddonHealth;

/// Clé de la mémoire du focus de l'écran des addons.
const addonsRouteKey = 'addons';

/// Gestion des addons (maquettes TV10 Sources, P09) : liste ordonnable (l'ordre
/// est la priorité des sources), activation, suppression avec confirmation,
/// ajout.
class AddonsScreen extends ConsumerWidget {
  const AddonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addons = ref.watch(addonsProvider);
    Future<void> add() => showAddAddonDialog(context);
    var remembered = ref
        .read(focusMemoryProvider.notifier)
        .restore(addonsRouteKey);
    if (!(addons.value?.any((a) => a.id == remembered) ?? false)) {
      remembered = null;
    }
    return TvScreen(
      title: context.l10n.addonsTitle,
      subtitle: context.l10n.addonsPriorityHint,
      actions: [
        if (addons.value?.isNotEmpty ?? false)
          TvButton(
            key: const ValueKey('addons-add'),
            // Action principale : focus d'emblée, sauf si un addon était
            // focalisé avant (retour d'un sous-écran).
            autofocus: remembered == null,
            height: 76,
            fontSize: 28,
            label: '+ ${context.l10n.addAddon}',
            onPressed: add,
          ),
      ],
      child: addons.when(
        loading: () => const StateView.loading(),
        error: (_, _) => StateView.error(
          message: context.l10n.addonsLoadError,
          onRetry: () => ref.read(addonsProvider.notifier).reload(),
        ),
        data: (list) => list.isEmpty
            ? StateView.empty(
                message: context.l10n.addonsEmpty,
                actionLabel: context.l10n.addAddon,
                onAction: add,
              )
            : _AddonList(list: list, remembered: remembered),
      ),
    );
  }
}

class _AddonList extends ConsumerWidget {
  const _AddonList({required this.list, required this.remembered});
  final List<InstalledAddon> list;
  final String? remembered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.read(addonsProvider.notifier);
    final health =
        ref.watch(healthSnapshotProvider).value ??
        const <String, AddonHealth>{};
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 24),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final a = list[i];
        return _AddonTile(
          key: ValueKey(a.id),
          addon: a,
          health: health[a.id] ?? AddonHealth.empty,
          onResetHealth: () => ref.read(addonHealthServiceProvider).reset(a.id),
          autofocus: a.id == remembered,
          onFocus: () => ref
              .read(focusMemoryProvider.notifier)
              .remember(addonsRouteKey, a.id),
          canMoveUp: i > 0,
          canMoveDown: i < list.length - 1,
          onMoveUp: () => _run(context, ref, () => ctl.move(a.id, -1)),
          onMoveDown: () => _run(context, ref, () => ctl.move(a.id, 1)),
          onToggle: (v) => _run(context, ref, () => ctl.setEnabled(a.id, v)),
          onDelete: () async {
            if (await _confirmDelete(context, a.name) && context.mounted) {
              await _run(context, ref, () => ctl.remove(a.id));
            }
          },
        );
      },
    );
  }

  /// Exécute une modification ; en cas d'échec, affiche un message français
  /// au lieu de laisser remonter une erreur asynchrone.
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() op,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.addonActionFailed;
    try {
      await op();
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failed)));
      // Resynchronise l'affichage avec la base.
      await ref.read(addonsProvider.notifier).refresh().catchError((_) {});
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String name) =>
      showTvConfirm(
        context,
        title: context.l10n.removeAddonTitle,
        body: context.l10n.removeAddonBody(name),
        confirmLabel: context.l10n.delete,
        destructive: true,
      );
}

class _AddonTile extends StatelessWidget {
  const _AddonTile({
    super.key,
    required this.addon,
    required this.health,
    required this.onResetHealth,
    required this.autofocus,
    required this.onFocus,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggle,
    required this.onDelete,
  });

  final InstalledAddon addon;

  /// Mesures de fiabilité de cet addon (locales).
  final AddonHealth health;
  final VoidCallback onResetHealth;

  /// Focus d'emblée (dernier addon focalisé avant un sous-écran).
  final bool autofocus;
  final VoidCallback onFocus;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final theme = Theme.of(context);
    final m = addon.manifest;
    final types = m == null
        ? ''
        : addonCapabilities(
            [for (final r in m.resources) r.name],
            m.catalogs.isNotEmpty,
            m.types,
            context.l10n,
          );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) {
        if (f) onFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            AddonLogo(logo: addon.logo, name: addon.name, size: 64),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    addon.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    m == null
                        ? context.l10n.addonBroken
                        : '$types · v${m.version}'
                              '${addon.enabled ? '' : ' · ${context.l10n.addonDisabled}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 24,
                      color: m == null ? c.error : c.textMuted,
                    ),
                  ),
                  if (m != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: HealthPill(health: health, showDetail: true),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (m != null) ...[
              TvIconButton(
                size: 64,
                label: context.l10n.moveAddonUp(addon.name),
                icon: Icons.arrow_upward,
                onPressed: canMoveUp ? onMoveUp : null,
              ),
              const SizedBox(width: 12),
              TvIconButton(
                size: 64,
                label: context.l10n.moveAddonDown(addon.name),
                icon: Icons.arrow_downward,
                onPressed: canMoveDown ? onMoveDown : null,
              ),
              if (health.samples > 0) ...[
                const SizedBox(width: 12),
                TvIconButton(
                  size: 64,
                  label: context.l10n.resetHealth(addon.name),
                  icon: Icons.restart_alt,
                  onPressed: onResetHealth,
                ),
              ],
              const SizedBox(width: 20),
              FocusableCard(
                key: ValueKey('addon-switch:${addon.id}'),
                autofocus: autofocus,
                scale: 1.06,
                borderRadius: BorderRadius.circular(30),
                semanticLabel: context.l10n.enableAddon(addon.name),
                onSelect: () => onToggle(!addon.enabled),
                child: Semantics(
                  toggled: addon.enabled,
                  child: TvSwitch(value: addon.enabled),
                ),
              ),
              const SizedBox(width: 20),
            ],
            TvIconButton(
              key: ValueKey('addon-delete:${addon.id}'),
              size: 64,
              label: context.l10n.deleteAddon(addon.name),
              icon: Icons.delete_outline,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
