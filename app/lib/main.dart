import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lumio/debug/torrent_spike.dart';
import 'package:lumio/features/update/update_banner.dart';
import 'package:lumio/ui/common/state_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LumioApp());
  SchedulerBinding.instance.addPostFrameCallback((_) {
    // Lu par scripts/box-smoke.sh dans logcat.
    // ignore: avoid_print
    print('LUMIO_READY');
  });
}

const _debugTorrent = String.fromEnvironment('LUMIO_DEBUG_TORRENT') == '1';

class LumioApp extends StatelessWidget {
  const LumioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        // Télécommande Android TV : OK/Entrée active l'élément ciblé.
        const SingleActivator(LogicalKeyboardKey.select):
            const ActivateIntent(),
      },
      home: _debugTorrent ? const TorrentSpikeScreen() : const RootScreen(),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          UpdateBanner(),
          Expanded(
            child: StateView.empty(
              message: 'Lumio est prêt. Ajoutez un addon pour commencer.',
            ),
          ),
        ],
      ),
    );
  }
}
