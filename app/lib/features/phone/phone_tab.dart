import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lumio/features/phone/phone_server.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Onglet « Depuis le téléphone » (maquette TV09) : QR (adresse + code),
/// adresse à taper, code de sécurité, état de la page.
class PhoneTab extends StatelessWidget {
  const PhoneTab({
    super.key,
    required this.session,
    required this.onRestart,
    this.portalQuery,
    this.portalName,
  });

  final PhoneSession session;
  final VoidCallback onRestart;

  /// Paramètre ajouté au lien du QR pour ouvrir la fiche d'un addon précis sur
  /// le portail (`addon=<id du site>` ou `reconf=<référence>`), et son nom.
  final String? portalQuery;
  final String? portalName;

  /// « 482913 » devient « 482 913 ».
  static String spaced(String code) =>
      code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<PhoneServerState>(
        valueListenable: session.state,
        builder: (context, s, _) {
          if (s.listening) {
            return _Pairing(
              state: s,
              portalQuery: portalQuery,
              portalName: portalName,
            );
          }
          return switch (s.status) {
            PhoneServerStatus.starting => const Center(
              child: CircularProgressIndicator(),
            ),
            PhoneServerStatus.noNetwork => _Notice(
              title: context.l10n.phoneNoNetworkTitle,
              body: context.l10n.phoneNoNetworkBody,
              onRestart: onRestart,
            ),
            PhoneServerStatus.error => _Notice(
              title: context.l10n.phoneNoNetworkTitle,
              body: context.l10n.phoneErrorBody,
              onRestart: onRestart,
            ),
            _ => _Notice(
              title: context.l10n.addonTabPhone,
              body: s.tooManyTries
                  ? context.l10n.phoneTooManyTries
                  : (s.idleStopped ? context.l10n.phoneIdleStopped : ''),
              onRestart: onRestart,
            ),
          };
        },
      );
}

class _Pairing extends StatefulWidget {
  const _Pairing({required this.state, this.portalQuery, this.portalName});

  final PhoneServerState state;
  final String? portalQuery;
  final String? portalName;

  @override
  State<_Pairing> createState() => _PairingState();
}

class _PairingState extends State<_Pairing> {
  Timer? _unlock;
  bool _expired = false;

  PhoneServerState get state => widget.state;

  String get _qrData => widget.portalQuery == null
      ? state.url
      : '${state.url}&${widget.portalQuery}';

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(_Pairing old) {
    super.didUpdateWidget(old);
    if (old.state.lockedUntil != state.lockedUntil) {
      _expired = false;
      _schedule();
    }
  }

  @override
  void dispose() {
    _unlock?.cancel();
    super.dispose();
  }

  /// Le verrou s'efface de l'écran à son échéance (le serveur ne notifie pas
  /// la fin du verrou).
  void _schedule() {
    _unlock?.cancel();
    final until = state.lockedUntil;
    if (until == null) return;
    final left = until.difference(DateTime.now());
    if (left <= Duration.zero) {
      _expired = true;
      return;
    }
    _unlock = Timer(left, () {
      if (mounted) setState(() => _expired = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    final until = state.lockedUntil;
    final locked = until != null && !_expired && until.isAfter(DateTime.now());
    Widget step(int n, String text) => Row(
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceFocus,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            '$n',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 30,
              fontWeight: FontWeight.w700,
              fontVariations: [FontVariation.weight(700)],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Text(
            text,
            style: t.bodyMedium?.copyWith(fontSize: 30, height: 1.3),
          ),
        ),
      ],
    );
    final status = locked
        ? l.phoneLocked
        : (state.connected ? l.phoneConnected : l.phoneLive);
    return Align(
      alignment: Alignment.topLeft,
      child: Row(
        key: const ValueKey('addtab:phone-body'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            label: l.phoneQrLabel,
            image: true,
            child: Container(
              key: const ValueKey('phone-qr'),
              width: 560,
              height: 560,
              padding: const EdgeInsets.all(44),
              decoration: BoxDecoration(
                color: c.text,
                borderRadius: BorderRadius.circular(36),
              ),
              child: QrImageView(
                key: ValueKey('qr:$_qrData'),
                data: _qrData,
                size: 472,
                padding: EdgeInsets.zero,
                backgroundColor: c.text,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: c.bg),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: c.bg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 96),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.portalName != null) ...[
                  Text(
                    l.portalAddonHint(widget.portalName!),
                    key: const ValueKey('portal-addon-hint'),
                    style: t.bodyMedium?.copyWith(
                      fontSize: 28,
                      height: 1.35,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                step(1, l.phoneStep1),
                const SizedBox(height: 32),
                step(2, l.phoneStep2),
                const SizedBox(height: 32),
                step(3, l.phoneStep3),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.phoneOrType,
                        style: t.bodySmall?.copyWith(
                          fontSize: 26,
                          height: 1.3,
                          color: c.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.address,
                        key: const ValueKey('phone-address'),
                        style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation.weight(700)],
                          color: c.accent,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        key: const ValueKey('phone-code'),
                        TextSpan(
                          children: [
                            TextSpan(text: '${l.phoneCodeLabel} '),
                            TextSpan(
                              text: PhoneTab.spaced(state.code),
                              style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w700,
                                fontVariations: const [
                                  FontVariation.weight(700),
                                ],
                                letterSpacing: 6,
                              ),
                            ),
                          ],
                        ),
                        style: t.bodySmall?.copyWith(
                          fontSize: 26,
                          height: 1.3,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: locked ? c.warning : c.success,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        status,
                        key: const ValueKey('phone-status'),
                        style: t.bodySmall?.copyWith(
                          fontSize: 24,
                          color: c.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body, this.onRestart});

  final String title;
  final String body;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Container(
          key: const ValueKey('addtab:phone-body'),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.headlineMedium?.copyWith(fontSize: 46)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  body,
                  style: t.bodyMedium?.copyWith(
                    fontSize: 28,
                    height: 1.4,
                    color: c.textMuted,
                  ),
                ),
              ],
              if (onRestart != null) ...[
                const SizedBox(height: 32),
                TvButton(
                  key: const ValueKey('phone-restart'),
                  autofocus: true,
                  label: l.phoneRestart,
                  height: 80,
                  fontSize: 30,
                  onPressed: onRestart,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
