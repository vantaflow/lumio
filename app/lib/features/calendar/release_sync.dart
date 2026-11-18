import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/calendar/calendar_providers.dart';
import 'package:lumio/features/calendar/calendar_screen.dart';
import 'package:lumio/features/calendar/release_notifier.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';

/// Vrai quand la dernière programmation de notifications a échoué (affiché
/// sur l'interrupteur du calendrier).
final releaseSyncErrorProvider = NotifierProvider<_ErrorFlag, bool>(
  _ErrorFlag.new,
);

class _ErrorFlag extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool v) => state = v;
}

/// Dernier profil synchronisé (pour annuler au changement de profil).
final _lastSyncedProfileProvider = Provider<List<String?>>((ref) => [null]);

/// Garde les notifications locales d'accord avec « Ma liste » du profil
/// actif, quel que soit l'écran ouvert : reprogrammation au démarrage, à
/// chaque changement de la liste, du réglage ou du profil. Désactivé, ou
/// profil changé : tout est annulé d'abord (aucune notification d'un autre
/// profil). À surveiller depuis la racine de l'application.
final releaseSyncProvider = Provider<void>((ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  final enabled = ref.watch(notifyReleasesProvider).value;
  final notifier = ref.read(releaseNotifierProvider);
  final error = ref.read(releaseSyncErrorProvider.notifier);
  final last = ref.read(_lastSyncedProfileProvider);
  final switched = last[0] != null && last[0] != profileId;
  last[0] = profileId;
  if (enabled == null) {
    if (switched) notifier.cancelAll();
    return;
  }
  if (!enabled) {
    notifier.cancelAll();
    Future.microtask(
      () => ref.read(releaseSyncErrorProvider.notifier).set(false),
    );
    return;
  }
  if (switched) notifier.cancelAll();
  final l = lookupAppLocalizations(ref.watch(localeProvider));
  ref.listen(calendarProvider, fireImmediately: true, (_, next) async {
    final data = next.value;
    if (data == null) return;
    final ok = await notifier.replaceAll(
      planReleases(
        data.entries,
        DateTime.now(),
        body: (e) => l.calendarNotifyBody(episodeLabel(l, e.video!)),
      ),
      l.calendarNotifyChannel,
    );
    error.set(!ok);
  });
});
