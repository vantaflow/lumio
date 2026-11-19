// ignore_for_file: sort_child_properties_last
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/common/tv_screen.dart' show TvTileText;
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// La diffusion DLNA dépend de la multidiffusion (SSDP) : Android et bureau
/// seulement (pas iOS ni le web).
bool get castPlatformSupported =>
    !kIsWeb &&
    (Platform.isAndroid ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux);

/// Ouvre la liste des appareils trouvés par [discover] ; renvoie celui choisi,
/// ou `null` (fermé). Aucun appareil : « Aucun appareil trouvé » + Réessayer.
Future<CastDevice?> showCastPicker(
  BuildContext context, {
  Stream<CastDevice> Function()? discover,
}) => showTvPanel<CastDevice>(
  context,
  builder: (_) =>
      CastPickerDialog(discover: discover ?? () => discoverDevices()),
);

Stream<CastDevice> discoverDevices() => discover();

class CastPickerDialog extends StatefulWidget {
  const CastPickerDialog({required this.discover, super.key});

  final Stream<CastDevice> Function() discover;

  @override
  State<CastPickerDialog> createState() => _CastPickerDialogState();
}

class _CastPickerDialogState extends State<CastPickerDialog> {
  final _devices = <CastDevice>[];
  StreamSubscription<CastDevice>? _sub;
  bool _searching = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  void _search() {
    _sub?.cancel();
    setState(() {
      _devices.clear();
      _searching = true;
    });
    void done() {
      if (mounted) setState(() => _searching = false);
    }

    _sub = widget.discover().listen(
      (d) {
        if (mounted && _devices.every((x) => x.usn != d.usn)) {
          setState(() => _devices.add(d));
        }
      },
      onError: (Object _) => done(),
      onDone: done,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.lumio;
    final empty = !_searching && _devices.isEmpty;
    // Maquette P03 : panneau de 820, lignes de 92 (fond #0E1116, #2A3340 au
    // focus), recherche avec pastille, boutons gris à droite.
    return TvPanel(
      title: l.castChooseDevice,
      width: 820,
      onBack: () => Navigator.pop(context),
      fitActions: true,
      contentPadding: EdgeInsets.zero,
      gap: 20,
      actionsGap: 32,
      children: [
        for (var i = 0; i < _devices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TvFocusTile(
              key: ValueKey('cast:device:$i'),
              minHeight: 92,
              autofocus: i == 0,
              idleColor: colors.bg,
              semanticLabel: _devices[i].friendlyName,
              onSelect: () => Navigator.pop(context, _devices[i]),
              child: Row(
                children: [
                  LumioIconView(
                    LumioIcon.monitor,
                    size: 40,
                    color: colors.secondary,
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: TvTileText(title: _devices[i].friendlyName)),
                ],
              ),
            ),
          ),
        if (_searching)
          Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: colors.accent,
                    backgroundColor: colors.outline,
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l.castSearching,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 28,
                        height: 1.4,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l.castNoDevice,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 36,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l.castNoDeviceHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 28,
                    height: 1.4,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
      actions: [
        if (empty)
          TvButton(
            key: const ValueKey('cast:retry'),
            autofocus: true,
            label: l.retry,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            onPressed: _search,
          ),
        TvButton(
          key: const ValueKey('cast:close'),
          kind: TvButtonKind.secondary,
          label: l.close,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// Barre affichée pendant un cast à la place des commandes locales :
/// appareil, ∓10 s, lecture/pause et « Arrêter la diffusion ».
class CastBar extends StatelessWidget {
  const CastBar({
    required this.title,
    required this.deviceName,
    required this.paused,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onStop,
    super.key,
  });

  final String title;
  final String deviceName;
  final bool paused;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<LumioColors>() ?? LumioColors.dark;
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cast_connected, size: 72, color: colors.accent),
              const SizedBox(height: LumioSpacing.md),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.text,
                ),
              ),
              const SizedBox(height: LumioSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  l.castPlayingOn(deviceName),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: LumioSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: LumioSpacing.md,
                runSpacing: LumioSpacing.md,
                children: [
                  FocusRing(
                    child: IconButton.filledTonal(
                      key: const ValueKey('cast:back10'),
                      tooltip: l.seekBack10,
                      iconSize: 32,
                      onPressed: onSeekBack,
                      icon: const Icon(Icons.replay_10),
                    ),
                  ),
                  FocusRing(
                    child: IconButton.filled(
                      key: const ValueKey('cast:playPause'),
                      autofocus: true,
                      tooltip: paused ? l.play : l.pause,
                      iconSize: 40,
                      onPressed: onPlayPause,
                      icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                    ),
                  ),
                  FocusRing(
                    child: IconButton.filledTonal(
                      key: const ValueKey('cast:forward10'),
                      tooltip: l.seekForward10,
                      iconSize: 32,
                      onPressed: onSeekForward,
                      icon: const Icon(Icons.forward_10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LumioSpacing.md),
              FocusRing(
                child: OutlinedButton.icon(
                  key: const ValueKey('cast:stop'),
                  onPressed: onStop,
                  icon: const Icon(Icons.cast),
                  label: Text(l.castStop),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
