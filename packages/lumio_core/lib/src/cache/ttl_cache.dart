/// Cache mémoire à durée de vie limitée (30 min par défaut).
///
/// L'horloge est injectable pour les tests.
class TtlCache {
  TtlCache({this.ttl = const Duration(minutes: 30), DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Duration ttl;
  final DateTime Function() _now;
  final Map<String, _Entry> _entries = {};

  /// Valeur encore valide pour [k], sinon `null` (absente, expirée ou d'un
  /// autre type que [T]).
  T? get<T>(String k) {
    final e = _entries[k];
    if (e == null) return null;
    if (!_now().isBefore(e.expires)) {
      _entries.remove(k);
      return null;
    }
    final v = e.value;
    return v is T ? v as T : null;
  }

  void put(String k, Object v) {
    final t = _now();
    _entries.removeWhere((_, e) => !t.isBefore(e.expires));
    _entries[k] = _Entry(v, t.add(ttl));
  }

  void clear() => _entries.clear();
}

class _Entry {
  const _Entry(this.value, this.expires);
  final Object value;
  final DateTime expires;
}
