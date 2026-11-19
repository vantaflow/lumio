import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/tracking_repository.dart' show trackerIds, traktId;
import 'package:lumio/features/tracking/tracking_providers.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/common/tv_guide.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
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

_Names _namesOf(AppLocalizations l, String trackerId) => _Names(
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

/// Clé d'un élément : celles de Trakt sont inchangées, un autre service
/// ajouterait un suffixe.
Key _key(String base, String trackerId) =>
    ValueKey(trackerId == traktId ? base : '$base-$trackerId');

/// Réglages « Suivi (Trakt) » du profil actif : une carte par service
/// (état du compte, connexion par code d'appareil), file d'envoi,
/// autorisation parentale pour un profil enfant.
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Maquette TV25 : en-tête de 152, cartes côte à côte (gap 32).
    return TvScreen(
      title: l.trackingTitle,
      subtitle: l.trackingHint,
      child: const TrackingBody(),
    );
  }
}

/// Contenu du suivi, partagé par l'écran [TrackingScreen] (TV25 : cartes côte
/// à côte) et par la page « Suivi » du rail des Réglages ([inPage], TV48 :
/// cartes empilées pleine largeur).
class TrackingBody extends ConsumerWidget {
  const TrackingBody({super.key, this.inPage = false});

  final bool inPage;

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

    Widget framed(Widget w) => inPage ? SizedBox(height: 360, child: w) : w;
    final failed = statuses.values.where((s) => s.hasError);
    if (failed.isNotEmpty) {
      return framed(
        StateView.error(
          message: l10nForError(l, failed.first.error!),
          onRetry: refresh,
        ),
      );
    }
    if (statuses.values.any((s) => !s.hasValue)) {
      return framed(const StateView.loading());
    }
    final all = {for (final e in statuses.entries) e.key: e.value.value!};
    final anyConfigured = all.values.any((s) => s.configured);
    // Réglage commun à tous les services : lu sur le premier.
    final shared = all.values.first;
    final allowed = !kid || shared.kidAllowed;
    Widget card(int i, String id) => _TrackerCard(
      trackerId: id,
      status: all[id]!,
      allowed: allowed,
      page: inPage,
      showKid: kid && anyConfigured && i == 0,
      onKid: (v) async {
        await repo.setKidAllowed(profileId, v);
        refresh();
      },
      pending: anyConfigured ? shared.pending : 0,
      onRetry: () async {
        await service.flush();
        refresh();
        if (context.mounted) _tell(context, l.trackingRetried);
      },
      autofocus: id == trackerIds.first || !all[trackerIds.first]!.configured,
      onConnect: () => _connect(context, ref, id),
      onDisconnect: () async {
        await service.disconnect(profileId, id);
        refresh();
        if (context.mounted) {
          _tell(context, _namesOf(l, id).disconnected);
        }
      },
    );
    if (inPage) {
      // Maquette TV48 : cartes empilées pleine largeur (gap 20), puis la
      // note d'absence de bouton quand rien n'est configuré.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, id) in trackerIds.indexed) ...[
            if (i > 0) const SizedBox(height: 20),
            card(i, id),
          ],
          if (!anyConfigured)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Text(
                l.trackingNoConnectHint,
                key: const ValueKey('tracking-no-connect'),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 24,
                  height: 1.35,
                  color: context.lumio.textMuted,
                ),
              ),
            ),
        ],
      );
    }
    return ListView(
      clipBehavior: Clip.none,
      padding: EdgeInsets.zero,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, id) in trackerIds.indexed) ...[
              if (i > 0) const SizedBox(width: 32),
              Expanded(child: card(i, id)),
            ],
            // Un seul service : la carte n'occupe que la moitié (TV25).
            if (trackerIds.length == 1) const Spacer(),
          ],
        ),
      ],
    );
  }
}

/// Carte d'un service (maquettes TV25 et TV48) : titre, état du compte,
/// envois en attente, réglage parental et boutons connecter / déconnecter.
class _TrackerCard extends StatelessWidget {
  const _TrackerCard({
    required this.trackerId,
    required this.status,
    required this.allowed,
    required this.autofocus,
    required this.onConnect,
    required this.onDisconnect,
    required this.showKid,
    required this.onKid,
    required this.pending,
    required this.onRetry,
    this.page = false,
  });

  /// Dans la page du rail des Réglages (TV48).
  final bool page;
  final String trackerId;
  final TrackingStatus status;
  final bool allowed;
  final bool autofocus;
  final bool showKid;
  final int pending;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRetry;
  final ValueChanged<bool> onKid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final n = _namesOf(l, trackerId);
    final s = status;
    final stateText = !s.configured
        ? n.notConfigured
        : s.reauthRequired
        ? n.reauth
        : s.connected
        ? n.connected
        : l.trackingNotConnected;
    final dotColor = s.connected && !s.reauthRequired
        ? const Color(0xFF5BD68A)
        : c.textMuted;
    final dotLabel = s.connected && !s.reauthRequired
        ? l.trackingConnectedShort
        : l.trackingNotConnected;
    const md = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 28,
      height: 1.4,
      color: Color(0xFFC9D0DA),
    );
    if (page && !s.configured) {
      // Maquette TV48 : titre 40, pastille d'état, texte 28 en 600.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    n.title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge!.copyWith(fontSize: 40),
                  ),
                ),
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceFocus,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    l.trackingNotConnected,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontVariations: [FontVariation.weight(700)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              stateText,
              key: _key('tracking-state', trackerId),
              style: md.copyWith(
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(600)],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  n.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge!.copyWith(fontSize: 44, height: 1.15),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                dotLabel,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation.weight(700)],
                  color: const Color(0xFFC9D0DA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Text(
              stateText,
              key: _key('tracking-state', trackerId),
              style: md,
            ),
          ),
          if (s.configured && pending > 0) ...[
            const SizedBox(height: 18),
            Text(
              l.trackingPending(pending),
              key: const ValueKey('tracking-pending'),
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 24,
                height: 1.35,
                color: c.accent,
              ),
            ),
          ],
          if (showKid) ...[
            const SizedBox(height: 18),
            _KidToggle(value: status.kidAllowed, onChanged: onKid),
          ],
          if (s.configured) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                if (s.connected && pending > 0)
                  TvButton(
                    key: const ValueKey('tracking-retry'),
                    label: l.trackingRetry,
                    kind: TvButtonKind.secondary,
                    height: 76,
                    fontSize: 28,
                    horizontalPadding: 40,
                    onPressed: onRetry,
                  ),
                if (!s.connected || s.reauthRequired)
                  TvButton(
                    key: _key('tracking-connect', trackerId),
                    autofocus: autofocus,
                    label: n.connect,
                    height: 76,
                    fontSize: 28,
                    horizontalPadding: 40,
                    icon: LumioIconView(
                      LumioIcon.linkOn,
                      size: 32,
                      color: c.onAccent,
                    ),
                    onPressed: allowed ? onConnect : null,
                  ),
                if (s.connected)
                  TvButton(
                    key: _key('tracking-disconnect', trackerId),
                    label: n.disconnect,
                    kind: TvButtonKind.secondary,
                    height: 76,
                    fontSize: 28,
                    horizontalPadding: 40,
                    icon: LumioIconView(
                      LumioIcon.linkOff,
                      size: 32,
                      color: c.text,
                    ),
                    onPressed: onDisconnect,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Réglage parental (TV25) : ligne #0E1116 de 96 avec interrupteur 84 x 46.
class _KidToggle extends StatelessWidget {
  const _KidToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    return TvTile(
      key: const ValueKey('tracking-kid'),
      minHeight: 96,
      color: c.bg,
      horizontalPadding: 24,
      semanticLabel: l.trackingKidAllow,
      onSelect: () => onChanged(!value),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.trackingKidAllow,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontVariations: [FontVariation.weight(700)],
                  ),
                ),
                Text(
                  l.trackingKidAllowHint,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 24,
                    height: 1.35,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 84,
            height: 46,
            decoration: BoxDecoration(
              color: value ? c.accent : c.outline,
              borderRadius: BorderRadius.circular(23),
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.text,
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            ),
          ),
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
    final c = context.lumio;
    const md = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 28,
      height: 1.4,
      color: Color(0xFFC9D0DA),
    );
    // Maquette TV26 : colonne de 760 et QR blanc, centrés (gap 120).
    return TvScreen(
      title: _namesOf(l, widget.trackerId).authTitle,
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10nForError(l, _error!),
                      key: const ValueKey('tracking-auth-error'),
                      textAlign: TextAlign.center,
                      style: md,
                    ),
                    const SizedBox(height: 24),
                    TvButton(
                      key: const ValueKey('tracking-auth-new'),
                      autofocus: true,
                      label: l.trackingAuthNewCode,
                      height: 76,
                      fontSize: 28,
                      horizontalPadding: 40,
                      onPressed: _start,
                    ),
                  ],
                )
              : code == null
              ? CircularProgressIndicator(color: c.accent)
              : Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // La colonne prend la largeur du cadre du code (864 pour 8
                      // caractères) : le texte reste borné à 760, le cadre ne
                      // passe plus sous le QR.
                      IntrinsicWidth(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 760),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 760,
                                ),
                                child: TvGuideSteps(
                                  key: const ValueKey('tracking-auth-steps'),
                                  compact: true,
                                  steps: [
                                    l.traktStep1,
                                    l.traktStep2,
                                    l.traktStep3,
                                    l.traktStep4,
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 760,
                                ),
                                child: SelectableText(
                                  code.verificationUrl.toString(),
                                  key: const ValueKey('tracking-auth-url'),
                                  style: text.titleLarge!.copyWith(
                                    fontSize: 48,
                                    height: 1.15,
                                    color: c.secondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Semantics(
                                label: code.userCode,
                                child: ExcludeSemantics(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 44,
                                      vertical: 36,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.surface,
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: Text(
                                      code.userCode,
                                      key: const ValueKey('tracking-auth-code'),
                                      style: text.titleLarge!.copyWith(
                                        fontSize: 132,
                                        height: 1,
                                        letterSpacing: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 760,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 4,
                                          color: c.accent,
                                          backgroundColor: c.outline,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Flexible(
                                      child: Text(
                                        l.trackingAuthWaiting,
                                        style: md,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              TvButton(
                                key: const ValueKey('tracking-auth-cancel'),
                                autofocus: true,
                                label: l.cancel,
                                kind: TvButtonKind.secondary,
                                height: 76,
                                fontSize: 28,
                                horizontalPadding: 40,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 120),
                      Semantics(
                        label: l.trackingQrSemantic,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: QrImageView(
                            key: const ValueKey('tracking-auth-qr'),
                            data: code.verificationUrl.toString(),
                            size: 225,
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
