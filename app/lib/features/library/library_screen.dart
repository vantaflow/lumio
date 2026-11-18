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
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 256,
          mainAxisExtent: 450,
          crossAxisSpacing: 28,
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
      subtitle: items.isEmpty ? null : context.l10n.libraryCount(items.length),
      child: body,
    );
  }
}
