import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/features/addons/add_addon_dialog.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/theme.dart';

/// Gestion des addons : liste ordonnable (l'ordre est la priorité des
/// sources), activation, suppression avec confirmation, ajout.
class AddonsScreen extends ConsumerWidget {
  const AddonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addons = ref.watch(addonsProvider);
    Future<void> add() => showAddAddonDialog(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.addonsTitle),
        actions: [
          if (addons.value?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: LumioSpacing.sm),
              child: FilledButton.icon(
                onPressed: add,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.addAddon),
              ),
            ),
        ],
      ),
      body: addons.when(
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
            : _AddonList(list: list),
      ),
    );
  }
}

class _AddonList extends ConsumerWidget {
  const _AddonList({required this.list});
  final List<InstalledAddon> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.read(addonsProvider.notifier);
    return ListView.separated(
      padding: const EdgeInsets.all(LumioSpacing.md),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: LumioSpacing.sm),
      itemBuilder: (context, i) {
        final a = list[i];
        return _AddonTile(
          key: ValueKey(a.id),
          addon: a,
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

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final c = context.lumio;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.removeAddonTitle),
        content: Text(ctx.l10n.removeAddonBody(name)),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: c.error),
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _AddonTile extends StatelessWidget {
  const _AddonTile({
    super.key,
    required this.addon,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggle,
    required this.onDelete,
  });

  final InstalledAddon addon;
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
    final types =
        m?.types.map((t) => contentTypeLabel(t, context.l10n)).join(' · ') ??
        '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LumioSpacing.md,
          vertical: LumioSpacing.sm,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: LumioSpacing.sm,
          runSpacing: LumioSpacing.xs,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AddonLogo(logo: addon.logo),
                const SizedBox(width: LumioSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 120,
                    maxWidth: 360,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addon.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        m == null
                            ? context.l10n.addonBroken
                            : '$types · v${m.version}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: m == null ? c.error : null,
                        ),
                      ),
                      if (!addon.enabled)
                        Text(
                          context.l10n.addonDisabled,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.warning,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m != null) ...[
                  IconButton(
                    tooltip: context.l10n.moveAddonUp(addon.name),
                    onPressed: canMoveUp ? onMoveUp : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: context.l10n.moveAddonDown(addon.name),
                    onPressed: canMoveDown ? onMoveDown : null,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  Semantics(
                    label: context.l10n.enableAddon(addon.name),
                    child: Switch(value: addon.enabled, onChanged: onToggle),
                  ),
                ],
                IconButton(
                  tooltip: context.l10n.deleteAddon(addon.name),
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: c.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
