import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/home/home_screen.dart';
import 'package:lumio/features/search/search_providers.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

const searchRouteKey = 'search';

final _latinKeys = 'abcdefghijklmnopqrstuvwxyz0123456789'.split('');
final _arabicKeys =
    'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'
            'ءأإآةى0123456789'
        .split('');

enum _TypeFilter { all, movie, series }

/// Recherche unifiée (story 3.2) : clavier D-pad à gauche, résultats à droite.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.onOpenItem, this.tvLayout});

  /// Force la disposition TV (tests) ; sinon détectée par `isTvLayout`.
  final bool? tvLayout;

  final void Function(MetaPreview item)? onOpenItem;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  var _arabic = false;
  var _filter = _TypeFilter.all;
  var _micAvailable = true;
  var _voiceReady = false;
  var _listening = false;
  late final VoiceInput _voice;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceInputProvider);
    _micAvailable = _voice.maySupport;
    _restoreId = ref.read(focusMemoryProvider.notifier).restore(searchRouteKey);
  }

  String? _restoreId;
  var _restoring = false;
  final _restoreNode = FocusNode(
    skipTraversal: true,
    canRequestFocus: false,
    debugLabel: 'Search.restore',
  );
  final _grid = ScrollController();

  @override
  void dispose() {
    if (_listening) unawaited(_voice.stop());
    _controller.dispose();
    _restoreNode.dispose();
    _grid.dispose();
    super.dispose();
  }

  void _setText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    ref.read(searchProvider.notifier).setQuery(text);
  }

  void _type(String s) => _setText(_controller.text + s);

  void _backspace() {
    final runes = _controller.text.runes.toList();
    if (runes.isEmpty) return;
    runes.removeLast();
    _setText(String.fromCharCodes(runes));
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      setState(() => _listening = false);
      await _voice.stop();
      return;
    }
    if (!_voiceReady) {
      // Première pression : c'est ici (et pas à l'ouverture) que l'autorisation
      // du micro peut être demandée.
      var ok = false;
      try {
        ok = await _voice.init();
      } on Object {
        ok = false;
      }
      if (!mounted) return;
      if (!ok) {
        setState(() => _micAvailable = false);
        return;
      }
      _voiceReady = true;
    }
    setState(() => _listening = true);
    await _voice.listen((text, done) {
      if (!mounted) return;
      _setText(text);
      if (done) setState(() => _listening = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final tv = isTvLayout(context, override: widget.tvLayout);
    return TvScaffold(
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: tv ? _onPhysicalKey : null,
        child: Scaffold(
          backgroundColor: lumio.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LumioSpacing.xl,
                vertical: LumioSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 520, child: _keyboardPane(context)),
                  const SizedBox(width: LumioSpacing.xl),
                  Expanded(child: _resultsPane(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Clavier physique (USB/BT) sur TV : lettres, chiffres, espace, retour
  /// arrière s'ajoutent à la requête.
  KeyEventResult _onPhysicalKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final c = event.character;
    if (c != null &&
        c.runes.length == 1 &&
        RegExp(r'^[\p{L}\p{N} ]$', unicode: true).hasMatch(c)) {
      _type(c);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _keyboardPane(BuildContext context) {
    final lumio = context.lumio;
    final keys = _arabic ? _arabicKeys : _latinKeys;
    final tv = isTvLayout(context, override: widget.tvLayout);
    return FocusTraversalGroup(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              // TV : simple affichage (saisie par le clavier à l'écran) ;
              // téléphone et bureau : champ normal (IME, clavier physique).
              readOnly: tv,
              canRequestFocus: !tv,
              showCursor: !tv,
              enableInteractiveSelection: !tv,
              onChanged: tv
                  ? null
                  : (t) => ref.read(searchProvider.notifier).setQuery(t),
              style: Theme.of(context).textTheme.titleLarge,
              decoration: InputDecoration(
                hintText: 'Rechercher un titre',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: lumio.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LumioRadius.md),
                ),
              ),
            ),
            const SizedBox(height: LumioSpacing.md),
            Wrap(
              spacing: LumioSpacing.sm,
              runSpacing: LumioSpacing.sm,
              children: [
                for (var i = 0; i < keys.length; i++)
                  _Key(
                    key: ValueKey('key-${keys[i]}'),
                    label: keys[i],
                    autofocus: i == 0,
                    onSelect: () => _type(keys[i]),
                  ),
              ],
            ),
            const SizedBox(height: LumioSpacing.md),
            Wrap(
              spacing: LumioSpacing.sm,
              runSpacing: LumioSpacing.sm,
              children: [
                _Key(
                  key: const ValueKey('key-space'),
                  label: 'Espace',
                  wide: true,
                  semantic: 'Espace',
                  onSelect: () => _type(' '),
                ),
                _Key(
                  key: const ValueKey('key-backspace'),
                  icon: Icons.backspace_outlined,
                  semantic: 'Effacer',
                  onSelect: _backspace,
                ),
                _Key(
                  key: const ValueKey('key-clear'),
                  label: 'Tout',
                  semantic: 'Tout effacer',
                  onSelect: () => _setText(''),
                ),
                _Key(
                  key: const ValueKey('key-layout'),
                  label: _arabic ? 'ABC' : 'ع',
                  semantic: _arabic ? 'Clavier latin' : 'Clavier arabe',
                  onSelect: () => setState(() => _arabic = !_arabic),
                ),
                if (_micAvailable)
                  _Key(
                    key: const ValueKey('key-mic'),
                    icon: _listening ? Icons.mic : Icons.mic_none,
                    semantic: _listening
                        ? 'Arrêter la dictée'
                        : 'Dictée vocale',
                    highlighted: _listening,
                    onSelect: _toggleMic,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Rend le focus au résultat mémorisé dès qu'il est construit (la grille
  /// est paresseuse : on s'en approche d'abord par défilement estimé).
  void _scheduleRestore(int index, int attempts) {
    if (_restoring) return;
    _restoring = true;
    void step(int left) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final n in _restoreNode.descendants) {
          if (n.canRequestFocus && !n.skipTraversal) {
            n.requestFocus();
            _restoreId = null;
            return;
          }
        }
        if (left > 1) {
          if (_grid.hasClients && _restoreNode.context == null) {
            const per = 4; // colonnes estimées (écran TV 1920)
            _grid.jumpTo(
              (index ~/ per * 364.0).clamp(0, _grid.position.maxScrollExtent),
            );
          }
          step(left - 1);
        } else {
          _restoreId = null;
        }
      });
    }

    step(attempts);
  }

  Widget _resultsPane(BuildContext context) {
    final s = ref.watch(searchProvider);
    final profile = ref.watch(currentProfileProvider);
    final priv = ref.watch(searchPrivateSourcesProvider);
    final visible = visibleItems(s.results, profile)
        .where(
          (m) => switch (_filter) {
            _TypeFilter.all => true,
            _TypeFilter.movie => m.type == 'movie',
            _TypeFilter.series => m.type == 'series',
          },
        )
        .toList();

    Widget body;
    if (!s.hasQuery) {
      body = const StateView.empty(
        message: 'Tapez un titre pour lancer la recherche',
      );
    } else if (s.noSearchAddon) {
      body = const StateView.empty(
        message: 'Aucun addon actif ne propose la recherche',
      );
    } else if (visible.isEmpty && s.searching) {
      body = const StateView.loading();
    } else if (visible.isEmpty) {
      body = const StateView.empty(message: 'Aucun résultat');
    } else {
      final restoreIndex = _restoreId == null
          ? -1
          : visible.indexWhere((m) => m.id == _restoreId);
      if (restoreIndex >= 0) _scheduleRestore(restoreIndex, 5);
      body = GridView.builder(
        controller: _grid,
        padding: const EdgeInsets.all(LumioSpacing.md),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 340,
          crossAxisSpacing: LumioSpacing.lg,
          mainAxisSpacing: LumioSpacing.lg,
        ),
        itemCount: visible.length,
        itemBuilder: (context, i) {
          final m = visible[i];
          Widget card = Focus(
            skipTraversal: true,
            canRequestFocus: false,
            onFocusChange: (f) {
              if (!f) return;
              ref
                  .read(focusMemoryProvider.notifier)
                  .remember(searchRouteKey, m.id);
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: LumioMotion.focus,
              );
            },
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: PosterCard(
                key: ValueKey('result-${m.id}'),
                item: m,
                allowPrivate: priv.contains(m.sourceAddonId),
                onSelect: () => widget.onOpenItem?.call(m),
              ),
            ),
          );
          if (i == restoreIndex) {
            card = Focus(
              focusNode: _restoreNode,
              skipTraversal: true,
              canRequestFocus: false,
              child: card,
            );
          }
          return card;
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final f in _TypeFilter.values) ...[
              _FilterChip(
                key: ValueKey('filter-${f.name}'),
                label: switch (f) {
                  _TypeFilter.all => 'Tout',
                  _TypeFilter.movie => 'Films',
                  _TypeFilter.series => 'Séries',
                },
                selected: _filter == f,
                onSelect: () => setState(() => _filter = f),
              ),
              const SizedBox(width: LumioSpacing.sm),
            ],
            if (s.searching && visible.isNotEmpty)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: LumioSpacing.md),
        Expanded(child: body),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    this.label,
    this.icon,
    this.semantic,
    this.autofocus = false,
    this.wide = false,
    this.highlighted = false,
    required this.onSelect,
  });

  final String? label;
  final IconData? icon;
  final String? semantic;
  final bool autofocus;
  final bool wide;
  final bool highlighted;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final fg = highlighted ? lumio.onAccent : lumio.text;
    return SizedBox(
      width: wide ? 180 : 64,
      height: 56,
      child: FocusableCard(
        autofocus: autofocus,
        scale: 1.06,
        borderRadius: BorderRadius.circular(LumioRadius.sm),
        semanticLabel: semantic ?? label,
        onSelect: onSelect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highlighted ? lumio.accent : lumio.surfaceRaised,
            borderRadius: BorderRadius.circular(LumioRadius.sm),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: fg)
                : Text(
                    label!,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: fg),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    return FocusableCard(
      scale: 1.04,
      borderRadius: BorderRadius.circular(LumioRadius.pill),
      semanticLabel: label,
      onSelect: onSelect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? lumio.accent : lumio.surfaceRaised,
          borderRadius: BorderRadius.circular(LumioRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: selected ? lumio.onAccent : lumio.text,
            ),
          ),
        ),
      ),
    );
  }
}
