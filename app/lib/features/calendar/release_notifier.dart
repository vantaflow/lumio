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

  /// Remplace toutes les notifications programmées par [items].
  Future<void> replaceAll(List<ScheduledRelease> items, String channelName);

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
  Future<void> replaceAll(
    List<ScheduledRelease> items,
    String channelName,
  ) async {
    if (!_supported) return;
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
    } on Object catch (e) {
      debugPrint('Notifications non programmées (${e.runtimeType})');
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

final releaseNotifierProvider = Provider<ReleaseNotifier>(
  (ref) => PluginReleaseNotifier(),
);
