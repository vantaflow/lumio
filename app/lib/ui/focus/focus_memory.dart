import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mémoire du dernier élément focalisé, par route (nom de route).
///
/// Une seule clé par route : la dernière focalisée. Le format de la clé est
/// libre pour l'appelant (ex. « rangée#index » pour [TvRow]).
final focusMemoryProvider = NotifierProvider<FocusMemory, Map<String, String>>(
  FocusMemory.new,
);

class FocusMemory extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void remember(String route, String key) {
    if (state[route] == key) return;
    state = {...state, route: key};
  }

  String? restore(String route) => state[route];

  void forget(String route) {
    if (!state.containsKey(route)) return;
    state = {...state}..remove(route);
  }
}
