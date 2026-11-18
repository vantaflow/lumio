import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mémoire du dernier élément focalisé : route -> rangée -> clé.
///
/// [row] distingue plusieurs zones d'une même route (ex. chaque [TvRow]) ;
/// sans [row], une zone unique par route.
final focusMemoryProvider =
    NotifierProvider<FocusMemory, Map<String, Map<String, String>>>(
      FocusMemory.new,
    );

class FocusMemory extends Notifier<Map<String, Map<String, String>>> {
  @override
  Map<String, Map<String, String>> build() => const {};

  void remember(String route, String key, {String row = ''}) {
    if (state[route]?[row] == key) return;
    state = {
      ...state,
      route: {...?state[route], row: key},
    };
  }

  String? restore(String route, {String row = ''}) => state[route]?[row];

  void forget(String route) {
    if (!state.containsKey(route)) return;
    state = {...state}..remove(route);
  }
}
