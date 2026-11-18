import 'dart:async';

import '../addons/addon_client.dart';
import '../addons/manifest.dart';
import '../addons/meta_preview.dart';
import '../net/http_fetcher.dart';

/// Verdict affiché pour un addon.
enum HealthLevel {
  /// Aucune mesure.
  unknown,

  /// Réponses correctes et rapides.
  reliable,

  /// Médiane au-dessus de [AddonHealth.slowThreshold].
  slow,

  /// Plus d'une réponse sur deux en échec ([AddonHealth.failing]).
  failing,
}

/// Mesures glissantes d'un addon.
class AddonHealth {
  const AddonHealth({
    required this.median,
    required this.successRate,
    required this.samples,
  });

  /// Aucune mesure.
  static const empty = AddonHealth(
    median: Duration.zero,
    successRate: 0,
    samples: 0,
  );

  /// Latence médiane des appels réussis.
  final Duration median;

  /// Part d'appels réussis, entre 0 et 1.
  final double successRate;

  /// Nombre de mesures dans la fenêtre.
  final int samples;

  /// Médiane au-delà de laquelle un addon est dit lent.
  static const slowThreshold = Duration(seconds: 3);

  /// Nombre minimal de mesures avant de conclure à une défaillance.
  static const minSamples = 10;

  /// Taux de réussite en dessous duquel un addon est défaillant.
  static const failingBelow = 0.5;

  /// Défaillant : taux de réussite < 0,5 sur au moins 10 mesures.
  bool get failing => samples >= minSamples && successRate < failingBelow;

  HealthLevel get level {
    if (samples == 0) return HealthLevel.unknown;
    if (failing) return HealthLevel.failing;
    if (median > slowThreshold) return HealthLevel.slow;
    return HealthLevel.reliable;
  }
}

class _Sample {
  const _Sample(this.ms, this.ok);
  final int ms;
  final bool ok;
}

/// Mesure locale de la fiabilité des addons : fenêtre glissante des
/// [window] derniers appels par addon. Les mesures restent sur l'appareil
/// (jamais envoyées, jamais synchronisées).
///
/// Les clés sont des identifiants de STOCKAGE d'addon (uniques), jamais
/// l'identifiant déclaré par le manifeste.
class HealthTracker {
  HealthTracker({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Reconstruit depuis [toJson] ; données illisibles ignorées.
  factory HealthTracker.fromJson(Object? json, {DateTime Function()? clock}) {
    final t = HealthTracker(clock: clock);
    if (json is Map) {
      for (final e in json.entries) {
        if (e.key is String) t.loadAddon(e.key as String, e.value);
      }
    }
    return t;
  }

  static const window = 50;

  final DateTime Function() _clock;
  final Map<String, List<_Sample>> _samples = {};
  final StreamController<String> _changes = StreamController.broadcast(
    sync: true,
  );

  /// Heure courante (horloge injectable).
  DateTime now() => _clock();

  /// Identifiant de l'addon dont les mesures viennent de changer.
  Stream<String> get changes => _changes.stream;

  /// Addons ayant au moins une mesure.
  List<String> get ids => [
    for (final e in _samples.entries)
      if (e.value.isNotEmpty) e.key,
  ];

  void record(String addonId, Duration d, bool ok) {
    final list = _samples.putIfAbsent(addonId, () => []);
    list.add(_Sample(d.inMilliseconds < 0 ? 0 : d.inMilliseconds, ok));
    if (list.length > window) list.removeRange(0, list.length - window);
    _changes.add(addonId);
  }

  AddonHealth stats(String addonId) {
    final list = _samples[addonId];
    if (list == null || list.isEmpty) return AddonHealth.empty;
    final okMs = [
      for (final s in list)
        if (s.ok) s.ms,
    ]..sort();
    return AddonHealth(
      median: Duration(milliseconds: _median(okMs)),
      successRate: okMs.length / list.length,
      samples: list.length,
    );
  }

  static int _median(List<int> sorted) {
    if (sorted.isEmpty) return 0;
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  /// Efface les mesures d'un addon (action « Réinitialiser »).
  void reset(String addonId) {
    if (_samples.remove(addonId) != null) _changes.add(addonId);
  }

  /// Oublie un addon désinstallé.
  void remove(String addonId) => reset(addonId);

  /// `{id: {'s': [[ms, 1|0], ...]}}`.
  Map<String, dynamic> toJson() => {for (final id in ids) id: toJsonFor(id)};

  /// Mesures d'un seul addon (clé de stockage dédiée) ; `null` si aucune.
  Map<String, dynamic>? toJsonFor(String addonId) {
    final list = _samples[addonId];
    if (list == null || list.isEmpty) return null;
    return {
      's': [
        for (final s in list) [s.ms, s.ok ? 1 : 0],
      ],
    };
  }

  /// Charge les mesures sauvegardées d'un addon ; elles précèdent celles
  /// déjà présentes en mémoire (plus anciennes).
  void loadAddon(String addonId, Object? json) {
    final raw = json is Map ? json['s'] : null;
    if (raw is! List) return;
    final loaded = <_Sample>[];
    for (final e in raw) {
      if (e is List && e.length >= 2 && e[0] is num && e[1] is num) {
        loaded.add(_Sample((e[0] as num).toInt(), (e[1] as num) != 0));
      }
    }
    if (loaded.isEmpty) return;
    final list = _samples.putIfAbsent(addonId, () => []);
    list.insertAll(0, loaded);
    if (list.length > window) list.removeRange(0, list.length - window);
    _changes.add(addonId);
  }

  void dispose() => _changes.close();
}

/// Décorateur de client : enregistre durée et issue de chaque appel dans un
/// [HealthTracker], sous la clé fournie par [keyFor] (identifiant de
/// stockage ; `null` = addon inconnu, rien d'enregistré).
///
/// Échec : délai dépassé, réseau, TLS, 5xx, refus HTTP, JSON invalide,
/// réponse trop grosse, redirection refusée. Un 404 est « aucun contenu »
/// (l'addon a répondu) : compté comme réussite. Un refus local d'adresse ou
/// une erreur inattendue n'est pas imputable à l'addon : rien d'enregistré.
class HealthRecordingAddonClient extends AddonClient {
  HealthRecordingAddonClient(this._inner, this._tracker, this._keyFor)
    : super(const _NoFetcher());

  final AddonClient _inner;
  final HealthTracker _tracker;
  final String? Function(AddonManifest) _keyFor;

  @override
  Future<AddonManifest> fetchManifest(Uri url) => _inner.fetchManifest(url);

  @override
  Future<List<MetaPreview>> catalog(
    AddonManifest a,
    String type,
    String id, {
    Map<String, String> extra = const {},
  }) => _measure(a, () => _inner.catalog(a, type, id, extra: extra));

  @override
  Future<Map<String, dynamic>?> rawMeta(
    AddonManifest a,
    String type,
    String id,
  ) => _measure(a, () => _inner.rawMeta(a, type, id));

  @override
  Future<List<Map<String, dynamic>>> rawStreams(
    AddonManifest a,
    String type,
    String id,
  ) => _measure(a, () => _inner.rawStreams(a, type, id));

  @override
  Future<List<Map<String, dynamic>>> rawSubtitles(
    AddonManifest a,
    String type,
    String id,
  ) => _measure(a, () => _inner.rawSubtitles(a, type, id));

  Future<T> _measure<T>(AddonManifest a, Future<T> Function() call) async {
    final key = _keyFor(a);
    final start = _tracker.now();
    try {
      final r = await call();
      if (key != null) {
        _tracker.record(key, _tracker.now().difference(start), true);
      }
      return r;
    } on AddonException catch (e) {
      if (key != null) {
        final took = _tracker.now().difference(start);
        switch (e.code) {
          case AddonErrorCode.notFound:
            _tracker.record(key, took, true);
          case AddonErrorCode.timeout ||
              AddonErrorCode.unreachable ||
              AddonErrorCode.tlsFailed ||
              AddonErrorCode.serverError ||
              AddonErrorCode.refused ||
              AddonErrorCode.tooLarge ||
              AddonErrorCode.invalidJson ||
              AddonErrorCode.redirect:
            _tracker.record(key, took, false);
          default:
            break;
        }
      }
      rethrow;
    }
  }
}

class _NoFetcher implements HttpFetcher {
  const _NoFetcher();

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) =>
      throw StateError('HealthRecordingAddonClient ne fait aucun appel direct');
}
