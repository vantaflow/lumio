import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/focus/focus_return.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/theme.dart';

/// Rangée de la mémoire de focus qui retient laquelle des rangées de l'écran a
/// été focalisée en dernier (sa valeur est l'identifiant de rangée).
const lastFocusedRowKey = '#derniere-rangee';

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
    required this.restorationId,
    this.routeKey,
    this.itemExtent,
    this.estimatedExtent = 300,
    this.height = 194,
    this.gap = LumioSpacing.lg,
    this.horizontalPadding = 96,
    this.verticalPadding = 12,
    this.autofocusFirst = false,
    this.titleGap = LumioSpacing.xs,
    this.titleHeight,
  });

  final String title;
  final List<Widget> items;
  final String restorationId;

  /// Clé d'écran pour la mémoire du focus ; par défaut le nom de la route.
  /// À fournir quand l'écran n'est pas une route nommée.
  final String? routeKey;

  /// Largeur fixe des éléments (optionnelle). Sans elle, la restauration d'un
  /// index éloigné utilise [estimatedExtent] pour se positionner.
  final double? itemExtent;

  /// Largeur estimée d'un élément (poster 300 dp) quand [itemExtent] est nul.
  final double estimatedExtent;

  /// Hauteur de la rangée (carte + 2 x 12 de marge pour l'anneau).
  final double height;
  final double gap;
  final double horizontalPadding;
  final double verticalPadding;

  /// Sans focus mémorisé, donne le focus à la première carte si rien d'autre
  /// n'est focalisé (première rangée affichée : le focus initial de l'écran).
  final bool autofocusFirst;

  /// Espace entre le titre et les cartes (20 dans les maquettes TV05/TV44).
  final double titleGap;

  /// Interligne du titre (maquettes : 1,2).
  final double? titleHeight;

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
  String _route = 'unnamed';
  bool _initialized = false;

  /// Focus automatique : abandonné si l'utilisateur a déjà focalisé autre
  /// chose.
  bool _onlyIfIdle = false;

  int? _readMemory() {
    final key = ref
        .read(focusMemoryProvider.notifier)
        .restore(_route, row: widget.restorationId);
    if (key == null) return null;
    final i = int.tryParse(key);
    return (i != null && i >= 0 && i < widget.items.length) ? i : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route =
        widget.routeKey ?? ModalRoute.of(context)?.settings.name ?? 'unnamed';
    if (_initialized) return;
    _initialized = true;
    _restoreAt = _readMemory();
    if (_restoreAt == null &&
        widget.autofocusFirst &&
        widget.items.isNotEmpty) {
      _restoreAt = 0;
      _onlyIfIdle = true;
    }
    final extent = widget.itemExtent ?? widget.estimatedExtent;
    _controller = ScrollController(
      initialScrollOffset: _restoreAt != null
          ? _restoreAt! * (extent + widget.gap)
          : 0,
    );
    if (_restoreAt != null) _tryRestore(5);
    FocusReturn.register(this, _returnFocus);
  }

  /// Retour sur l'écran (fiche, recherche, Ma liste fermées) alors que la
  /// carte d'origine n'existe plus : si c'est cette rangée qui avait le focus
  /// en dernier, il revient sur sa carte mémorisée.
  bool _returnFocus(Route<dynamic> route) {
    if (!mounted || ModalRoute.of(context) != route) return false;
    final memory = ref.read(focusMemoryProvider.notifier);
    if (memory.restore(_route, row: lastFocusedRowKey) !=
        widget.restorationId) {
      return false;
    }
    final i = _readMemory();
    if (i == null) return false;
    final extent = widget.itemExtent ?? widget.estimatedExtent;
    final c = _controller;
    if (c != null && c.hasClients) {
      c.jumpTo(
        (i * (extent + widget.gap)).clamp(0.0, c.position.maxScrollExtent),
      );
    }
    setState(() => _restoreAt = i);
    _tryRestore(6);
    return true;
  }

  /// Rend le focus à l'élément mémorisé dès qu'il est construit (quelques
  /// images d'attente : la liste est paresseuse).
  void _tryRestore(int attempts) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_onlyIfIdle) {
        final f = FocusManager.instance.primaryFocus;
        if (f != null && f is! FocusScopeNode) return;
      }
      for (final n in _restoreNode.descendants) {
        if (n.canRequestFocus && !n.skipTraversal) {
          n.requestFocus();
          return;
        }
      }
      if (attempts > 1) _tryRestore(attempts - 1);
    });
  }

  @override
  void dispose() {
    FocusReturn.unregister(this);
    _controller?.dispose();
    _restoreNode.dispose();
    super.dispose();
  }

  void _onItemFocus(int index, BuildContext itemContext, bool focused) {
    if (!focused) return;
    ref
        .read(focusMemoryProvider.notifier)
        .remember(_route, '$index', row: widget.restorationId);
    ref
        .read(focusMemoryProvider.notifier)
        .remember(_route, widget.restorationId, row: lastFocusedRowKey);
    final reduce = MediaQuery.maybeDisableAnimationsOf(itemContext) ?? false;
    final duration = reduce ? Duration.zero : LumioMotion.focus;
    // Horizontal : centre la carte dans CETTE rangée seulement. (Un
    // `Scrollable.ensureVisible` remonte tous les défilements parents et
    // centrait aussi la page : rangées qui se chevauchent, audit D5.)
    final h = _controller;
    final ro = itemContext.findRenderObject();
    if (h != null && h.hasClients && ro != null) {
      h.position.ensureVisible(
        ro,
        alignment: 0.5,
        duration: duration,
        curve: Curves.easeOut,
      );
    }
    // Vertical : la rangée entière (titre compris) reste visible.
    final outer = Scrollable.maybeOf(context, axis: Axis.vertical);
    final rowRo = context.findRenderObject();
    if (outer != null && rowRo != null) {
      outer.position.ensureVisible(
        rowRo,
        alignment: 0.02,
        duration: duration,
        curve: Curves.easeOut,
      );
    }
  }

  /// Marge latérale : réduite sur téléphone (largeur < 720 dp).
  double _hPad(BuildContext context) => MediaQuery.sizeOf(context).width < 720
      ? LumioSpacing.md
      : widget.horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _hPad(context)),
          child: Semantics(
            header: true,
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: lumio.text,
                height: widget.titleHeight,
              ),
            ),
          ),
        ),
        SizedBox(height: widget.titleGap),
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
              horizontal: _hPad(context),
              vertical: widget.verticalPadding,
            ),
            itemBuilder: (context, i) {
              Widget item = Builder(
                builder: (itemContext) => Focus(
                  skipTraversal: true,
                  canRequestFocus: false,
                  onFocusChange: (f) => _onItemFocus(i, itemContext, f),
                  child: widget.items[i],
                ),
              );
              item = Padding(
                padding: EdgeInsets.only(right: widget.gap),
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
              return FocusableCardScale(scale: 1.08, child: item);
            },
          ),
        ),
      ],
    );
  }
}
