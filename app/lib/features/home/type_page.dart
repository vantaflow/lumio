import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/home/home_screen.dart' show CatalogRowView;
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart' show addonsProvider;
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/row_traversal.dart';
import 'package:lumio_core/lumio_core.dart';

/// Page « Films » ou « Séries » : les rangées des catalogues des addons de ce
/// type, comme l'accueil (mêmes cartes, même chargement par rangée).
class TypePageScreen extends ConsumerWidget {
  const TypePageScreen({super.key, required this.type, this.onOpenItem});

  /// `movie` ou `series`.
  final String type;
  final void Function(MetaPreview item)? onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final specs = ref.watch(
      homeRowsProvider.select(
        (s) => [
          for (final x in s.specs)
            if (x.catalog.type == type) x.id,
        ],
      ),
    );
    final loading = !ref.watch(addonsProvider).hasValue;
    return TvScreen(
      title: contentTypeLabel(type, l),
      padding: EdgeInsets.zero,
      child: loading
          ? const StateView.loading()
          : specs.isEmpty
          ? StateView.empty(
              message: type == 'series'
                  ? l.typePageNoSeries
                  : l.typePageNoMovies,
            )
          : RowTraversalGroup(
              child: ListView.builder(
                key: ValueKey('type-page-$type'),
                cacheExtent: 1500,
                padding: const EdgeInsets.only(bottom: 48),
                itemCount: specs.length,
                itemBuilder: (context, i) => KeyedSubtree(
                  key: ValueKey(specs[i]),
                  child: CatalogRowView(
                    rowId: specs[i],
                    onOpenItem: onOpenItem,
                  ),
                ),
              ),
            ),
    );
  }
}
