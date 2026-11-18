import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Retour (touche Retour / Échap / bouton B de manette).
class BackIntent extends Intent {
  const BackIntent();
}

/// Lecture / pause (touches média de la télécommande).
class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

/// Raccourcis Android TV communs : le centre du D-pad (Select/Enter/A) reste
/// géré par `ActivateIntent` de Flutter ; ici Retour et lecture/pause.
const Map<ShortcutActivator, Intent> tvShortcuts = {
  SingleActivator(LogicalKeyboardKey.goBack): BackIntent(),
  SingleActivator(LogicalKeyboardKey.escape): BackIntent(),
  SingleActivator(LogicalKeyboardKey.gameButtonB): BackIntent(),
  SingleActivator(LogicalKeyboardKey.mediaPlayPause): PlayPauseIntent(),
  SingleActivator(LogicalKeyboardKey.mediaPlay): PlayPauseIntent(),
  SingleActivator(LogicalKeyboardKey.mediaPause): PlayPauseIntent(),
};

/// Racine d'écran TV : raccourcis + actions cohérents pour tous les écrans.
/// [onBack] remplace le retour par défaut (`Navigator.maybePop`).
class TvScaffold extends StatelessWidget {
  const TvScaffold({
    super.key,
    required this.child,
    this.onBack,
    this.onPlayPause,
  });

  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onPlayPause;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: tvShortcuts,
      child: Actions(
        actions: {
          BackIntent: CallbackAction<BackIntent>(
            onInvoke: (_) {
              if (onBack != null) {
                onBack!();
              } else {
                Navigator.maybeOf(context)?.maybePop();
              }
              return null;
            },
          ),
          if (onPlayPause != null)
            PlayPauseIntent: CallbackAction<PlayPauseIntent>(
              onInvoke: (_) {
                onPlayPause!();
                return null;
              },
            ),
        },
        child: FocusScope(child: child),
      ),
    );
  }
}

/// Gère le retour système pour un panneau/superposition : tant que
/// [isOpen], Retour appelle [onClose] au lieu de quitter l'écran.
class BackGuard extends StatelessWidget {
  const BackGuard({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.child,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isOpen) onClose();
      },
      child: child,
    );
  }
}

/// Vrai pour une disposition télévision : grand écran (plus petit côté
/// >= 720 dp), hors ordinateur, sans souris branchée. [override] sert aux
/// tests.
bool isTvLayout(BuildContext context, {bool? override}) {
  if (override != null) return override;
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux) {
    return false;
  }
  if (MediaQuery.sizeOf(context).shortestSide < 720) return false;
  return !RendererBinding.instance.mouseTracker.mouseIsConnected;
}
