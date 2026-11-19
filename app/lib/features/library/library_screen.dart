import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/home/home_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio_core/lumio_core.dart';

const libraryRouteKey = 'library';

/// « Ma liste » en grille (story 3.4) ; vide : explique comment ajouter un
/// titre. Les titres non autorisés au profil enfant sont masqués.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, this.onOpenItem});

  final void Function(MetaPreview item)? onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    final items = visibleItems(
      lib.value ?? const [],
      ref.watch(currentProfileProvider),
    );
    final Widget body;
    if (lib.hasError) {
      body = StateView.error(
        message: context.l10n.libraryLoadError,
        onRetry: () => ref.invalidate(libraryProvider),
      );
    } else if (!lib.hasValue) {
      body = const StateView.loading();
    } else if (items.isEmpty) {
      body = StateView.empty(message: context.l10n.libraryEmpty);
    } else {
      // Maquette TV20 : 7 colonnes de 220, titres sous les affiches.
      body = GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisExtent: 432,
          crossAxisSpacing: 36,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => PosterCard(
          key: ValueKey('${items[i].sourceAddonId}|${items[i].id}'),
          item: items[i],
          width: 220,
          height: 330,
          onSelect: () => onOpenItem?.call(items[i]),
        ),
      );
    }
    return TvScreen(
      title: context.l10n.myList,
      subtitle: lib.hasValue && !lib.hasError
          ? context.l10n.libraryCount(items.length)
          : null,
      // Maquette TV20 : 7 × 220 + 6 × 36 = 1756 depuis x = 96 (dépasse de 28
      // dans la marge droite) ; 12 dp de réserve de chaque côté pour l'anneau.
      padding: items.isEmpty || lib.hasError || !lib.hasValue
          ? null
          : const EdgeInsets.fromLTRB(84, 0, 56, 48),
      child: body,
    );
  }
}
