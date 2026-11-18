import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Anti-rebond de la frappe (story 3.2, AC #3).
const searchDebounce = Duration(milliseconds: 350);

/// Service de recherche ; le niveau de confiance réseau de chaque addon est
/// dérivé de l'URL INSTALLÉE (jamais de l'identifiant du manifeste).
final searchServiceProvider = Provider<SearchService>(
  (ref) => SearchService(
    (m) => defaultAddonClient(allowPrivate: isPrivateAddress(m.transportUrl)),
  ),
);

/// Dictée vocale : abstraction minimale pour pouvoir la simuler en test.
abstract class VoiceInput {
  /// Vrai si la reconnaissance est utilisable (micro et service présents).
  /// Ne lève jamais.
  Future<bool> init();

  /// Démarre l'écoute ; [onText] reçoit le texte reconnu ([done] à la fin).
  Future<void> listen(void Function(String text, bool done) onText);

  Future<void> stop();
}

class SpeechVoiceInput implements VoiceInput {
  final SpeechToText _stt = SpeechToText();

  @override
  Future<bool> init() async {
    try {
      return await _stt.initialize(onError: (_) {});
    } on Object {
      return false;
    }
  }

  @override
  Future<void> listen(void Function(String text, bool done) onText) async {
    try {
      await _stt.listen(
        onResult: (r) => onText(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(partialResults: true),
      );
    } on Object {
      // Micro indisponible en cours de route : on ne plante pas.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _stt.stop();
    } on Object {
      // rien à arrêter
    }
  }
}

final voiceInputProvider = Provider<VoiceInput>((ref) => SpeechVoiceInput());

@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.searching = false,
    this.noSearchAddon = false,
  });

  final String query;
  final List<MetaPreview> results;
  final bool searching;

  /// Aucun addon actif ne déclare la recherche.
  final bool noSearchAddon;

  bool get hasQuery => query.trim().isNotEmpty;

  /// Recherche terminée sans résultat (message « Aucun résultat »).
  bool get empty => hasQuery && !searching && results.isEmpty;
}

final searchProvider =
    NotifierProvider.autoDispose<SearchController, SearchState>(
      SearchController.new,
    );

class SearchController extends AutoDisposeNotifier<SearchState> {
  Timer? _timer;
  StreamSubscription<List<MetaPreview>>? _sub;
  int _token = 0;

  @override
  SearchState build() {
    ref.onDispose(() {
      _token++;
      _timer?.cancel();
      _sub?.cancel();
    });
    return const SearchState();
  }

  List<AddonManifest> _addons() => [
    for (final a in ref.read(addonsProvider).value ?? const <InstalledAddon>[])
      if (a.enabled && !a.broken) a.manifest!,
  ];

  /// Nouvelle saisie : annule la requête précédente (minuteur et flux) ;
  /// seules les émissions de la dernière requête sont prises en compte.
  void setQuery(String query) {
    _timer?.cancel();
    _sub?.cancel();
    _sub = null;
    final token = ++_token;
    if (query.trim().isEmpty) {
      state = SearchState(query: query);
      return;
    }
    state = SearchState(query: query, results: state.results, searching: true);
    _timer = Timer(searchDebounce, () => _run(query, token));
  }

  void _run(String query, int token) {
    final addons = _addons();
    final has = addons.any(
      (m) => m.catalogs.any((c) => c.extra.any((e) => e.name == 'search')),
    );
    if (!has) {
      state = SearchState(query: query, noSearchAddon: true);
      return;
    }
    var first = true;
    _sub = ref
        .read(searchServiceProvider)
        .search(addons, query)
        .listen(
          (items) {
            if (token != _token) return;
            first = false;
            state = SearchState(query: query, results: items, searching: true);
          },
          onError: (_) {
            if (token != _token) return;
            state = SearchState(query: query, results: const []);
          },
          onDone: () {
            if (token != _token) return;
            state = SearchState(
              query: query,
              results: first ? const [] : state.results,
            );
          },
        );
  }
}

/// Identifiants de manifeste dont TOUS les addons installés sont en réseau
/// privé (affiches autorisées en réseau privé) ; un identifiant partagé avec
/// un addon public est refusé par prudence.
final searchPrivateSourcesProvider = Provider<Set<String>>((ref) {
  final byId = <String, bool>{};
  for (final a in ref.watch(addonsProvider).value ?? const <InstalledAddon>[]) {
    final m = a.manifest;
    if (m == null) continue;
    final priv = isPrivateAddress(m.transportUrl);
    byId[m.id] = (byId[m.id] ?? true) && priv;
  }
  return {
    for (final e in byId.entries)
      if (e.value) e.key,
  };
});
