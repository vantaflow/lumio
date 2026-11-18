import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/tracking_repository.dart' show traktId;
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

/// Réglages « Suivi (Trakt, Simkl) » du profil actif : état du compte,
/// connexion par code d'appareil, file d'envoi, autorisation parentale pour
/// un profil enfant.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final profileId = ref.read(currentProfileIdProvider);
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TraktDeviceAuthScreen(profileId: profileId),
      ),
    );
    ref.invalidate(trackingStatusProvider(profileId));
    if (ok == true && context.mounted) {
      _tell(context, context.l10n.trackingAuthDone);
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
    final status = ref.watch(trackingStatusProvider(profileId));
    final service = ref.read(trackingServiceProvider);
    final repo = ref.read(trackingRepositoryProvider);
    final kid = profile?.isKid ?? false;
    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(title: Text(l.trackingTitle)),
        body: status.when(
          loading: () => const StateView.loading(),
          error: (e, _) => StateView.error(
            message: l10nForError(l, e),
            onRetry: () => ref.invalidate(trackingStatusProvider(profileId)),
          ),
          data: (s) {
            final allowed = !kid || s.kidAllowed;
            return ListView(
              padding: const EdgeInsets.all(LumioSpacing.md),
              children: [
                Text(
                  l.trackingTrakt,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: LumioSpacing.xs),
                Text(
                  !s.configured
                      ? l.trackingNotConfigured
                      : s.reauthRequired
                      ? l.trackingReauth
                      : s.connected
                      ? l.trackingConnected
                      : l.trackingNotConnected,
                  key: const ValueKey('tracking-state'),
                ),
                const SizedBox(height: LumioSpacing.md),
                if (kid && s.configured)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LumioSpacing.md),
                    child: FocusRing(
                      child: SwitchListTile(
                        key: const ValueKey('tracking-kid'),
                        title: Text(l.trackingKidAllow),
                        subtitle: Text(l.trackingKidAllowHint),
                        value: s.kidAllowed,
                        onChanged: (v) async {
                          await repo.setKidAllowed(profileId, v);
                          ref.invalidate(trackingStatusProvider(profileId));
                        },
                      ),
                    ),
                  ),
                if (s.configured)
                  Wrap(
                    spacing: LumioSpacing.sm,
                    runSpacing: LumioSpacing.sm,
                    children: [
                      if (!s.connected || s.reauthRequired)
                        FilledButton.icon(
                          key: const ValueKey('tracking-connect'),
                          autofocus: true,
                          onPressed: allowed
                              ? () => _connect(context, ref)
                              : null,
                          icon: const Icon(Icons.link),
                          label: Text(l.trackingConnect),
                        ),
                      if (s.connected)
                        OutlinedButton.icon(
                          key: const ValueKey('tracking-disconnect'),
                          onPressed: () async {
                            await service.disconnect(profileId, traktId);
                            ref.invalidate(trackingStatusProvider(profileId));
                            if (context.mounted) {
                              _tell(context, l.trackingDisconnected);
                            }
                          },
                          icon: const Icon(Icons.link_off),
                          label: Text(l.trackingDisconnect),
                        ),
                      if (s.pending > 0)
                        OutlinedButton.icon(
                          key: const ValueKey('tracking-retry'),
                          onPressed: () async {
                            await service.flush();
                            ref.invalidate(trackingStatusProvider(profileId));
                            if (context.mounted) {
                              _tell(context, l.trackingRetried);
                            }
                          },
                          icon: const Icon(Icons.sync),
                          label: Text(l.trackingRetry),
                        ),
                    ],
                  ),
                if (s.configured) ...[
                  const SizedBox(height: LumioSpacing.md),
                  Text(
                    l.trackingPending(s.pending),
                    key: const ValueKey('tracking-pending'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Connexion par code d'appareil : adresse, code et QR de l'adresse, lisibles
/// à distance sur un téléviseur ; l'attente de l'accord se fait ici. Le code
/// n'est jamais journalisé.
class TraktDeviceAuthScreen extends ConsumerStatefulWidget {
  const TraktDeviceAuthScreen({super.key, required this.profileId});

  final String profileId;

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
      final code = await service.beginAuth(traktId);
      if (_cancelled || run != _run) return;
      setState(() => _code = code);
      await service.completeAuth(
        widget.profileId,
        traktId,
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
        appBar: AppBar(title: Text(l.trackingAuthTitle)),
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
