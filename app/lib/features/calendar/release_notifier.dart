import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:timezone/timezone.dart' as tz;

/// Nombre maximal de notifications programmées (Android limite les alarmes).
const maxScheduledReleases = 20;

/// Heure locale (9 h) à laquelle on prévient quand la date de sortie, souvent
/// donnée à minuit UTC, tombe au milieu de la nuit.
const _morningHour = 9;
const _nightUntilHour = 8;

/// Notification à programmer pour un épisode à venir.
@immutable
class ScheduledRelease {
  const ScheduledRelease({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });

  final int id;

  /// Instant d'affichage (UTC).
  final DateTime when;
  final String title;
  final String body;
}

/// Instant de notification d'une sortie : l'instant de sortie, ramené à 9 h
/// locales du même jour quand il tombe avant 8 h.
DateTime notifyInstant(DateTime release) {
  final u = release.toUtc();
  // Date sans heure (minuit UTC) : jour calendaire de la date, 9 h locales.
  if (u.hour == 0 && u.minute == 0 && u.second == 0) {
    return DateTime(u.year, u.month, u.day, _morningHour).toUtc();
  }
  final local = release.toLocal();
  if (local.hour >= _nightUntilHour) return release.toUtc();
  return DateTime(local.year, local.month, local.day, _morningHour).toUtc();
}

/// Les [max] prochaines notifications à programmer (entrées datées futures
/// seulement, déjà triées par date).
List<ScheduledRelease> planReleases(
  List<CalendarEntry> entries,
  DateTime now, {
  required String Function(CalendarEntry) body,
  int max = maxScheduledReleases,
}) {
  final out = <ScheduledRelease>[];
  final from = now.toUtc();
  for (final e in entries) {
    if (out.length >= max) break;
    final d = e.date;
    if (d == null) continue;
    final when = notifyInstant(d);
    if (!when.isAfter(from)) continue;
    out.add(
      ScheduledRelease(
        id: out.length + 1,
        when: when,
        title: e.series.name,
        body: body(e),
      ),
    );
  }
  out.sort((a, b) => a.when.compareTo(b.when));
  return out;
}

/// Notifications locales des sorties (désactivées tant que l'utilisateur ne
/// les active pas).
abstract class ReleaseNotifier {
  /// Demande l'autorisation de notifier (Android 13+) ; faux si refusée ou
  /// indisponible. Appelée seulement quand l'utilisateur active le réglage.
  Future<bool> requestPermission();

  /// Remplace toutes les notifications programmées par [items] ; renvoie
  /// faux si la programmation a échoué. [isCurrent] devient faux dès qu'une
  /// annulation ou un remplacement plus récent est demandé : l'implémentation
  /// l'interroge avant chaque programmation et s'arrête alors.
  Future<bool> replaceAll(
    List<ScheduledRelease> items,
    String channelName, {
    bool Function()? isCurrent,
  });

  Future<void> cancelAll();
}

/// Implémentation `flutter_local_notifications` (Android seulement ; sans
/// effet ailleurs).
class PluginReleaseNotifier implements ReleaseNotifier {
  PluginReleaseNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _ensureInit() => _init ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      await _ensureInit();
      return await _android?.requestNotificationsPermission() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> replaceAll(
    List<ScheduledRelease> items,
    String channelName, {
    bool Function()? isCurrent,
  }) async {
    if (!_supported) return true;
    try {
      await _ensureInit();
      await _plugin.cancelAllPendingNotifications();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'new_episodes',
          channelName,
          importance: Importance.defaultImportance,
        ),
      );
      for (final r in items) {
        if (isCurrent != null && !isCurrent()) return true;
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.when, tz.UTC),
          notificationDetails: details,
          // Heure approximative : pas besoin de l'autorisation d'alarme exacte.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      return true;
    } on Object catch (e) {
      debugPrint('Notifications non programmées (${e.runtimeType})');
      return false;
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      await _ensureInit();
      await _plugin.cancelAllPendingNotifications();
    } on Object {
      // Rien à annuler.
    }
  }
}

/// Sérialise les opérations d'un [ReleaseNotifier] (une seule en cours) :
/// une annulation ou un remplacement plus récent invalide aussitôt les
/// programmations en cours, qui s'arrêtent avant leur prochaine notification.
class QueuedReleaseNotifier implements ReleaseNotifier {
  QueuedReleaseNotifier(this._inner);

  final ReleaseNotifier _inner;
  Future<void> _tail = Future<void>.value();
  int _generation = 0;

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final done = _tail.then((_) => op());
    _tail = done.then<void>((_) {}, onError: (Object _) {});
    return done;
  }

  @override
  Future<bool> requestPermission() => _enqueue(_inner.requestPermission);

  @override
  Future<bool> replaceAll(
    List<ScheduledRelease> items,
    String channelName, {
    bool Function()? isCurrent,
  }) {
    final mine = ++_generation;
    return _enqueue(
      () => _inner.replaceAll(
        items,
        channelName,
        isCurrent: () => mine == _generation && (isCurrent?.call() ?? true),
      ),
    );
  }

  @override
  Future<void> cancelAll() {
    _generation++;
    return _enqueue(_inner.cancelAll);
  }
}

final releaseNotifierProvider = Provider<ReleaseNotifier>(
  (ref) => QueuedReleaseNotifier(PluginReleaseNotifier()),
);
