import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/theme.dart';

/// Rangée horizontale de cartes (titre + liste défilante paresseuse).
///
/// Le focus focalisé est recentré/rendu entièrement visible ; l'index est
/// mémorisé par route + [restorationId] et rendu au retour sur la route.
/// Haut/bas quittent la rangée vers la voisine (traversée par défaut).
class TvRow extends ConsumerStatefulWidget {
  const TvRow({
    super.key,
    required this.title,
    required this.items,
    this.restorationId = 'row',
    this.itemExtent,
    this.height = 194,
    this.gap = LumioSpacing.lg,
    this.horizontalPadding = 96,
  });

  final String title;
  final List<Widget> items;
  final String restorationId;

  /// Largeur fixe des éléments (optionnelle) : permet de restaurer le focus
  /// sur un élément éloigné de la fenêtre initiale.
  final double? itemExtent;

  /// Hauteur de la rangée (carte + 2 x 12 de marge pour l'anneau).
  final double height;
  final double gap;
  final double horizontalPadding;

  @override
  ConsumerState<TvRow> createState() => _TvRowState();
}

class _TvRowState extends ConsumerState<TvRow> {
  ScrollController? _controller;
  final _restoreNode = FocusNode(
    skipTraversal: true,
    canRequestFocus: false,
    debugLabel: 'TvRow.restore',
  );
  int? _restoreAt;
  bool _restorePending = false;
  String _route = '/';
  bool _initialized = false;

  int? _readMemory() {
    final key = ref.read(focusMemoryProvider.notifier).restore(_route);
    final prefix = '${widget.restorationId}#';
    if (key == null || !key.startsWith(prefix)) return null;
    final i = int.tryParse(key.substring(prefix.length));
    return (i != null && i >= 0 && i < widget.items.length) ? i : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context)?.settings.name ?? '/';
    if (_initialized) return;
    _initialized = true;
    _restoreAt = _readMemory();
    final extent = widget.itemExtent;
    _controller = ScrollController(
      initialScrollOffset: _restoreAt != null && extent != null
          ? _restoreAt! * (extent + widget.gap)
          : 0,
    );
    if (_restoreAt != null) {
      _restorePending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_restorePending) return;
        _restorePending = false;
        for (final n in _restoreNode.descendants) {
          if (n.canRequestFocus && !n.skipTraversal) {
            n.requestFocus();
            return;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _restoreNode.dispose();
    super.dispose();
  }

  void _onItemFocus(int index, BuildContext itemContext, bool focused) {
    if (!focused) return;
    ref
        .read(focusMemoryProvider.notifier)
        .remember(_route, '${widget.restorationId}#$index');
    final reduce = MediaQuery.maybeDisableAnimationsOf(itemContext) ?? false;
    Scrollable.ensureVisible(
      itemContext,
      alignment: 0.5,
      duration: reduce ? Duration.zero : LumioMotion.focus,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
          child: Semantics(
            header: true,
            child: Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: lumio.text),
            ),
          ),
        ),
        const SizedBox(height: LumioSpacing.sm),
        // 12 de marge verticale : l'anneau et l'échelle ne sont jamais rognés.
        SizedBox(
          height: widget.height,
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: widget.items.length,
            itemExtent: widget.itemExtent == null
                ? null
                : widget.itemExtent! + widget.gap,
            padding: EdgeInsets.symmetric(
              horizontal: widget.horizontalPadding,
              vertical: 12,
            ),
            itemBuilder: (context, i) {
              Widget item = Padding(
                padding: EdgeInsets.only(right: widget.gap),
                child: widget.items[i],
              );
              item = Focus(
                skipTraversal: true,
                canRequestFocus: false,
                onFocusChange: (f) => _onItemFocus(i, context, f),
                child: item,
              );
              if (i == _restoreAt) {
                item = Focus(
                  focusNode: _restoreNode,
                  skipTraversal: true,
                  canRequestFocus: false,
                  child: item,
                );
              }
              return item;
            },
          ),
        ),
      ],
    );
  }
}
