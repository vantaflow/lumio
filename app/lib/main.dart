import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/debug/loop_debug.dart';
import 'package:lumio/debug/player_spike.dart';
import 'package:lumio/debug/torrent_spike.dart';
import 'package:lumio/features/addons/health_providers.dart';
import 'package:lumio/features/addons/install_link_handler.dart';
import 'package:lumio/features/calendar/release_sync.dart';
import 'package:lumio/features/home/home_screen.dart';
import 'package:lumio/features/onboarding/onboarding_flow.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio/ui/focus/focus_rescue.dart';
import 'package:lumio/ui/focus/tv_canvas.dart';
import 'package:lumio/ui/focus/tv_detection.dart';
import 'package:lumio/ui/theme.dart';
import 'package:media_kit/media_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final tv = await detectAndroidTv();
  final container = ProviderContainer(
    overrides: [androidTvProvider.overrideWithValue(tv)],
  );
  // Cache des torrents : orphelins supprimés au démarrage ; vidé à la
  // fermeture si le réglage est activé (voir CacheManager).
  final cache = container.read(cacheManagerProvider);
  unawaited(cache.cleanOnStart());
  AppLifecycleListener(
    onExitRequested: () async {
      await cache.cleanOnExit();
      return AppExitResponse.exit;
    },
    onDetach: () => unawaited(cache.cleanOnExit()),
  );
  // Mesures de santé des addons : écrites sans attendre quand l'appli passe
  // en arrière-plan ou se ferme (sinon, une session de moins de 30 s ne
  // serait jamais enregistrée).
  final health = container.read(addonHealthServiceProvider);
  AppLifecycleListener(
    onPause: () => unawaited(health.flush()),
    onHide: () => unawaited(health.flush()),
    onDetach: () => unawaited(health.flush()),
    onExitRequested: () async {
      await health.flush();
      return AppExitResponse.exit;
    },
  );
  _startPerfLog();
  runApp(
    UncontrolledProviderScope(container: container, child: const LumioApp()),
  );
  SchedulerBinding.instance.addPostFrameCallback((_) {
    // Lu par scripts/box-smoke.sh dans logcat.
    // ignore: avoid_print
    print('LUMIO_READY');
  });
}

/// `--dart-define=LUMIO_PERF=1` : écrit dans logcat (`LUMIO_PERF`) les images
/// de plus de 50 ms (construction / rastérisation) et les touches reçues, pour
/// mesurer la lenteur des transitions sur la box (audit D10).
const _perf = String.fromEnvironment('LUMIO_PERF') == '1';

void _startPerfLog() {
  if (!_perf) return;
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      if (t.totalSpan.inMilliseconds > 50) {
        // ignore: avoid_print
        print(
          'LUMIO_PERF frame build=${t.buildDuration.inMilliseconds}ms '
          'raster=${t.rasterDuration.inMilliseconds}ms '
          'total=${t.totalSpan.inMilliseconds}ms',
        );
      }
    }
  });
  ServicesBinding.instance.keyboard.addHandler((e) {
    if (e is KeyDownEvent) {
      // ignore: avoid_print
      print(
        'LUMIO_PERF key ${e.logicalKey.keyLabel} ${e.logicalKey.debugName}',
      );
    }
    return false;
  });
}

const _debugTorrent = String.fromEnvironment('LUMIO_DEBUG_TORRENT') == '1';
const _debugPlayer = String.fromEnvironment('LUMIO_DEBUG_PLAYER') == '1';
const _debugLoop = String.fromEnvironment('LUMIO_DEBUG_LOOP') == '1';

class LumioApp extends ConsumerWidget {
  const LumioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Notifications de sorties toujours d'accord avec « Ma liste ».
    ref.watch(releaseSyncProvider);
    return MaterialApp(
      title: 'Lumio',
      locale: ref.watch(localeProvider),
      supportedLocales: supportedUiLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      navigatorObservers: [FocusRescueObserver(), appRouteObserver],
      theme: LumioTheme.dark(),
      darkTheme: LumioTheme.dark(),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        final tv = ref.watch(androidTvProvider);
        // TV : tout est mis à l'échelle du canevas 1920 dp des maquettes.
        final themed = LumioThemeScope(tv: tv, child: child!);
        return tv ? TvCanvas(child: themed) : themed;
      },
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        // Télécommande Android TV : OK/Entrée active l'élément ciblé.
        const SingleActivator(LogicalKeyboardKey.select):
            const ActivateIntent(),
      },
      home: _debugLoop
          ? const LoopDebugScreen()
          : _debugPlayer
          ? const PlayerSpikeScreen()
          : _debugTorrent
          ? const TorrentSpikeScreen()
          : const OnboardingGate(child: ProfileGate(child: RootScreen())),
    );
  }
}

/// Contenu racine : l'accueil (derrière le choix de profil).
class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const InstallLinkHandler(child: HomeScreen());
}
