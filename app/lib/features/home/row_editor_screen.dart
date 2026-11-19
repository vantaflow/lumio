import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/features/home/home_layout.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/theme.dart';

/// Personnalisation de l'accueil : masquer et réordonner les rangées.
class RowEditorScreen extends ConsumerWidget {
  const RowEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lumio = context.lumio;
    final specs = ref.watch(homeRowsProvider.select((s) => s.specs));
    final layout = ref.watch(homeLayoutProvider).value ?? const HomeLayout();
    final titles = <String, String>{
      continueRowId: context.l10n.continueWatching,
      libraryRowId: context.l10n.myList,
      for (final s in specs)
        s.id:
            '${catalogRowTitle(s.catalog.type, s.title, context.l10n)} · ${s.addonName}',
    };
    final arranged = layout.arrange(titles.keys.toList());
    final controller = ref.read(homeLayoutProvider.notifier);

    return TvScreen(
      title: context.l10n.customizeHome,
      subtitle: context.l10n.customizeHomeHint,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: arranged.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final id = arranged[i];
          final hidden = layout.hidden.contains(id);
          return TvTile(
            key: ValueKey('editor:$id'),
            minHeight: 100,
            onSelect: null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titles[id]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation.weight(700)],
                      color: hidden ? lumio.textMuted : lumio.text,
                    ),
                  ),
                ),
                TvIconButton(
                  key: ValueKey('up:$id'),
                  label: context.l10n.moveUp,
                  icon: Icons.arrow_upward,
                  onPressed: i == 0
                      ? null
                      : () => controller.move(id, -1, arranged),
                ),
                const SizedBox(width: 16),
                TvIconButton(
                  key: ValueKey('down:$id'),
                  label: context.l10n.moveDown,
                  icon: Icons.arrow_downward,
                  onPressed: i == arranged.length - 1
                      ? null
                      : () => controller.move(id, 1, arranged),
                ),
                const SizedBox(width: 16),
                TvButton(
                  key: ValueKey('toggle:$id'),
                  kind: TvButtonKind.secondary,
                  height: 72,
                  fontSize: 28,
                  horizontalPadding: 36,
                  label: hidden ? context.l10n.show : context.l10n.hide,
                  onPressed: () => controller.setHidden(id, !hidden),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
