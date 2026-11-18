import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/debug/player_spike.dart';
import 'package:lumio/debug/torrent_spike.dart';
import 'package:lumio/features/addons/addons_screen.dart';
import 'package:lumio/features/profiles/pin_dialog.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart';
import 'package:lumio/features/update/update_banner.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/theme.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: LumioApp()));
  SchedulerBinding.instance.addPostFrameCallback((_) {
    // Lu par scripts/box-smoke.sh dans logcat.
    // ignore: avoid_print
    print('LUMIO_READY');
  });
}

const _debugTorrent = String.fromEnvironment('LUMIO_DEBUG_TORRENT') == '1';
const _debugPlayer = String.fromEnvironment('LUMIO_DEBUG_PLAYER') == '1';

class LumioApp extends StatelessWidget {
  const LumioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumio',
      debugShowCheckedModeBanner: false,
      theme: LumioTheme.dark(),
      darkTheme: LumioTheme.dark(),
      themeMode: ThemeMode.dark,
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        // Télécommande Android TV : OK/Entrée active l'élément ciblé.
        const SingleActivator(LogicalKeyboardKey.select):
            const ActivateIntent(),
      },
      home: _debugPlayer
          ? const PlayerSpikeScreen()
          : _debugTorrent
          ? const TorrentSpikeScreen()
          : const ProfileGate(child: RootScreen()),
    );
  }
}

class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      body: Column(
        children: [
          const UpdateBanner(),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                end: LumioSpacing.md,
                top: LumioSpacing.sm,
              ),
              child: TextButton.icon(
                onPressed: () async {
                  // Un profil enfant ne peut pas changer de profil sans le
                  // PIN parent.
                  if (!await requireParent(context, ref)) return;
                  ref.read(currentProfileProvider.notifier).select(null);
                },
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(profile?.name ?? 'Profil'),
              ),
            ),
          ),
          Expanded(
            child: StateView.empty(
              message: 'Lumio est prêt. Ajoutez un addon pour commencer.',
              actionLabel: 'Gérer les addons',
              onAction: () async {
                if (!await requireParent(context, ref)) return;
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AddonsScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
