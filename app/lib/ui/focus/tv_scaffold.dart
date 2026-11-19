import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/ui/focus/tv_detection.dart';

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
        // Le relâchement de Retour est absorbé : sinon Android le renvoie au
        // système (onBackPressed) APRÈS que l'appui a déjà fermé l'écran, et
        // un second retour part (la fiche ouverte depuis la recherche ramenait
        // à l'accueil, un retour sur l'accueil proposait « Quitter Lumio ? »).
        child: FocusScope(
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, event) =>
                event is KeyUpEvent && _backKeys.contains(event.logicalKey)
                ? KeyEventResult.handled
                : KeyEventResult.ignored,
            child: child,
          ),
        ),
      ),
    );
  }
}

final _backKeys = {
  LogicalKeyboardKey.goBack,
  LogicalKeyboardKey.escape,
  LogicalKeyboardKey.gameButtonB,
};

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

/// Vrai pour une disposition télévision : l'appareil est un Android TV
/// (`android.software.leanback`, voir [androidTvProvider]). Une tablette
/// tactile, même grande, n'est jamais une TV. [override] sert aux tests.
bool isTvLayout(BuildContext context, {bool? override}) {
  if (override != null) return override;
  final scope = context
      .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>();
  if (scope == null) return false;
  return ProviderScope.containerOf(
    context,
    listen: false,
  ).read(androidTvProvider);
}
