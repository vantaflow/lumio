import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/features/home/home_layout.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
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
      for (final s in specs) s.id: '${s.title} · ${s.addonName}',
    };
    final arranged = layout.arrange(titles.keys.toList());
    final controller = ref.read(homeLayoutProvider.notifier);

    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.customizeHome)),
        body: ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 96,
            vertical: LumioSpacing.md,
          ),
          itemCount: arranged.length,
          itemBuilder: (context, i) {
            final id = arranged[i];
            final hidden = layout.hidden.contains(id);
            return Padding(
              key: ValueKey('editor:$id'),
              padding: const EdgeInsets.symmetric(vertical: LumioSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titles[id]!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: hidden ? lumio.textMuted : lumio.text,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('up:$id'),
                    tooltip: context.l10n.moveUp,
                    onPressed: i == 0
                        ? null
                        : () => controller.move(id, -1, arranged),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    key: ValueKey('down:$id'),
                    tooltip: context.l10n.moveDown,
                    onPressed: i == arranged.length - 1
                        ? null
                        : () => controller.move(id, 1, arranged),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  TextButton(
                    key: ValueKey('toggle:$id'),
                    onPressed: () => controller.setHidden(id, !hidden),
                    child: Text(hidden ? context.l10n.show : context.l10n.hide),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
