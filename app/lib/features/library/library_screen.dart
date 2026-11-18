import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/home/home_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
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
        message: 'Impossible de lire votre liste.',
        onRetry: () => ref.invalidate(libraryProvider),
      );
    } else if (!lib.hasValue) {
      body = const StateView.loading();
    } else if (items.isEmpty) {
      body = const StateView.empty(
        message:
            'Votre liste est vide. Ouvrez la fiche d\'un titre puis '
            'choisissez « Ajouter à ma liste ».',
      );
    } else {
      body = GridView.builder(
        padding: const EdgeInsets.all(LumioSpacing.xl),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 360,
          crossAxisSpacing: LumioSpacing.lg,
          mainAxisSpacing: LumioSpacing.lg,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => PosterCard(
          key: ValueKey('${items[i].sourceAddonId}|${items[i].id}'),
          item: items[i],
          onSelect: () => onOpenItem?.call(items[i]),
        ),
      );
    }
    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ma liste'),
          backgroundColor: Colors.transparent,
        ),
        body: body,
      ),
    );
  }
}
