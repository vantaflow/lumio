import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/tracking_repository.dart'
    show simklId, trackerIds, traktId;
import 'package:lumio/features/tracking/tracking_providers.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Textes propres à un service de suivi.
class _Names {
  const _Names({
    required this.title,
    required this.notConfigured,
    required this.connected,
    required this.reauth,
    required this.connect,
    required this.disconnect,
    required this.disconnected,
    required this.authTitle,
    required this.authDone,
  });

  final String title;
  final String notConfigured;
  final String connected;
  final String reauth;
  final String connect;
  final String disconnect;
  final String disconnected;
  final String authTitle;
  final String authDone;
}

_Names _namesOf(AppLocalizations l, String trackerId) => trackerId == simklId
    ? _Names(
        title: l.trackingSimkl,
        notConfigured: l.trackingSimklNotConfigured,
        connected: l.trackingSimklConnected,
        reauth: l.trackingSimklReauth,
        connect: l.trackingSimklConnect,
        disconnect: l.trackingSimklDisconnect,
        disconnected: l.trackingSimklDisconnected,
        authTitle: l.trackingSimklAuthTitle,
        authDone: l.trackingSimklAuthDone,
      )
    : _Names(
        title: l.trackingTrakt,
        notConfigured: l.trackingNotConfigured,
        connected: l.trackingConnected,
        reauth: l.trackingReauth,
        connect: l.trackingConnect,
        disconnect: l.trackingDisconnect,
        disconnected: l.trackingDisconnected,
        authTitle: l.trackingAuthTitle,
        authDone: l.trackingAuthDone,
      );

/// Clé d'un élément : celles de Trakt sont inchangées, Simkl ajoute un suffixe.
Key _key(String base, String trackerId) =>
    ValueKey(trackerId == traktId ? base : '$base-$trackerId');

/// Réglages « Suivi (Trakt, Simkl) » du profil actif : une carte par service
/// (état du compte, connexion par code d'appareil), file d'envoi,
/// autorisation parentale pour un profil enfant.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  Future<void> _connect(
    BuildContext context,
    WidgetRef ref,
    String trackerId,
  ) async {
    final profileId = ref.read(currentProfileIdProvider);
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            TraktDeviceAuthScreen(profileId: profileId, trackerId: trackerId),
      ),
    );
    ref.invalidate(
      trackingStatusProvider((profileId: profileId, trackerId: trackerId)),
    );
    if (ok == true && context.mounted) {
      _tell(context, _namesOf(context.l10n, trackerId).authDone);
    }
  }

  void _tell(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(currentProfileProvider);
    final profileId = ref.watch(currentProfileIdProvider);
    final statuses = {
      for (final id in trackerIds)
        id: ref.watch(
          trackingStatusProvider((profileId: profileId, trackerId: id)),
        ),
    };
    final service = ref.read(trackingServiceProvider);
    final repo = ref.read(trackingRepositoryProvider);
    final kid = profile?.isKid ?? false;
    void refresh() {
      for (final id in trackerIds) {
        ref.invalidate(
          trackingStatusProvider((profileId: profileId, trackerId: id)),
        );
      }
    }

    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(title: Text(l.trackingTitle)),
        body: () {
          final failed = statuses.values.where((s) => s.hasError);
          if (failed.isNotEmpty) {
            return StateView.error(
              message: l10nForError(l, failed.first.error!),
              onRetry: refresh,
            );
          }
          if (statuses.values.any((s) => !s.hasValue)) {
            return const StateView.loading();
          }
          final all = {for (final e in statuses.entries) e.key: e.value.value!};
          final anyConfigured = all.values.any((s) => s.configured);
          // Réglage commun à tous les services : lu sur le premier.
          final shared = all.values.first;
          final allowed = !kid || shared.kidAllowed;
          return ListView(
            padding: const EdgeInsets.all(LumioSpacing.md),
            children: [
              if (kid && anyConfigured)
                Padding(
                  padding: const EdgeInsets.only(bottom: LumioSpacing.md),
                  child: FocusRing(
                    child: SwitchListTile(
                      key: const ValueKey('tracking-kid'),
                      title: Text(l.trackingKidAllow),
                      subtitle: Text(l.trackingKidAllowHint),
                      value: shared.kidAllowed,
                      onChanged: (v) async {
                        await repo.setKidAllowed(profileId, v);
                        refresh();
                      },
                    ),
                  ),
                ),
              for (final id in trackerIds)
                _TrackerCard(
                  trackerId: id,
                  status: all[id]!,
                  allowed: allowed,
                  autofocus:
                      id == trackerIds.first ||
                      !all[trackerIds.first]!.configured,
                  onConnect: () => _connect(context, ref, id),
                  onDisconnect: () async {
                    await service.disconnect(profileId, id);
                    refresh();
                    if (context.mounted) {
                      _tell(context, _namesOf(l, id).disconnected);
                    }
                  },
                ),
              if (anyConfigured) ...[
                if (shared.pending > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LumioSpacing.md),
                    child: OutlinedButton.icon(
                      key: const ValueKey('tracking-retry'),
                      onPressed: () async {
                        await service.flush();
                        refresh();
                        if (context.mounted) _tell(context, l.trackingRetried);
                      },
                      icon: const Icon(Icons.sync),
                      label: Text(l.trackingRetry),
                    ),
                  ),
                Text(
                  l.trackingPending(shared.pending),
                  key: const ValueKey('tracking-pending'),
                ),
              ],
            ],
          );
        }(),
      ),
    );
  }
}

/// Carte d'un service : état du compte et boutons connecter / déconnecter.
class _TrackerCard extends StatelessWidget {
  const _TrackerCard({
    required this.trackerId,
    required this.status,
    required this.allowed,
    required this.autofocus,
    required this.onConnect,
    required this.onDisconnect,
  });

  final String trackerId;
  final TrackingStatus status;
  final bool allowed;
  final bool autofocus;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = _namesOf(l, trackerId);
    final s = status;
    return Padding(
      padding: const EdgeInsets.only(bottom: LumioSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: LumioSpacing.xs),
          Text(
            !s.configured
                ? n.notConfigured
                : s.reauthRequired
                ? n.reauth
                : s.connected
                ? n.connected
                : l.trackingNotConnected,
            key: _key('tracking-state', trackerId),
          ),
          if (s.configured) ...[
            const SizedBox(height: LumioSpacing.md),
            Wrap(
              spacing: LumioSpacing.sm,
              runSpacing: LumioSpacing.sm,
              children: [
                if (!s.connected || s.reauthRequired)
                  FilledButton.icon(
                    key: _key('tracking-connect', trackerId),
                    autofocus: autofocus,
                    onPressed: allowed ? onConnect : null,
                    icon: const Icon(Icons.link),
                    label: Text(n.connect),
                  ),
                if (s.connected)
                  OutlinedButton.icon(
                    key: _key('tracking-disconnect', trackerId),
                    onPressed: onDisconnect,
                    icon: const Icon(Icons.link_off),
                    label: Text(n.disconnect),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Connexion par code d'appareil : adresse, code et QR de l'adresse, lisibles
/// à distance sur un téléviseur ; l'attente de l'accord se fait ici. Le code
/// n'est jamais journalisé.
class TraktDeviceAuthScreen extends ConsumerStatefulWidget {
  const TraktDeviceAuthScreen({
    super.key,
    required this.profileId,
    this.trackerId = traktId,
  });

  final String profileId;
  final String trackerId;

  @override
  ConsumerState<TraktDeviceAuthScreen> createState() => _AuthState();
}

class _AuthState extends ConsumerState<TraktDeviceAuthScreen> {
  DeviceCode? _code;
  Object? _error;
  bool _cancelled = false;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _start() async {
    final run = ++_run;
    setState(() {
      _code = null;
      _error = null;
    });
    final service = ref.read(trackingServiceProvider);
    final sleep = ref.read(trackingSleepProvider);
    try {
      final code = await service.beginAuth(widget.trackerId);
      if (_cancelled || run != _run) return;
      setState(() => _code = code);
      await service.completeAuth(
        widget.profileId,
        widget.trackerId,
        code,
        sleep: sleep,
        isCancelled: () => _cancelled || run != _run,
      );
      if (!mounted || _cancelled || run != _run) return;
      Navigator.of(context).pop(true);
    } on CancelledPoll {
      // Écran quitté ou nouveau code demandé.
    } on Object catch (e) {
      if (_cancelled || run != _run) return;
      setState(() {
        _code = null;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final code = _code;
    final text = Theme.of(context).textTheme;
    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(title: Text(_namesOf(l, widget.trackerId).authTitle)),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LumioSpacing.lg),
            child: _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10nForError(l, _error!),
                        key: const ValueKey('tracking-auth-error'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: LumioSpacing.md),
                      FilledButton(
                        key: const ValueKey('tracking-auth-new'),
                        autofocus: true,
                        onPressed: _start,
                        child: Text(l.trackingAuthNewCode),
                      ),
                    ],
                  )
                : code == null
                ? const CircularProgressIndicator()
                : Wrap(
                    spacing: LumioSpacing.xl,
                    runSpacing: LumioSpacing.lg,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.trackingAuthStep),
                            const SizedBox(height: LumioSpacing.sm),
                            SelectableText(
                              code.verificationUrl.toString(),
                              key: const ValueKey('tracking-auth-url'),
                              style: text.titleLarge,
                            ),
                            const SizedBox(height: LumioSpacing.md),
                            Semantics(
                              label: code.userCode,
                              child: ExcludeSemantics(
                                child: Text(
                                  code.userCode,
                                  key: const ValueKey('tracking-auth-code'),
                                  style: text.displayMedium?.copyWith(
                                    letterSpacing: 6,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: LumioSpacing.md),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: LumioSpacing.sm),
                                Flexible(child: Text(l.trackingAuthWaiting)),
                              ],
                            ),
                            const SizedBox(height: LumioSpacing.md),
                            FocusRing(
                              child: OutlinedButton(
                                key: const ValueKey('tracking-auth-cancel'),
                                autofocus: true,
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(l.cancel),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: l.trackingQrSemantic,
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(LumioSpacing.sm),
                          child: QrImageView(
                            key: const ValueKey('tracking-auth-qr'),
                            data: code.verificationUrl.toString(),
                            size: 220,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
