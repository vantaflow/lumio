import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/pairing_client.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Ouvre l'écran d'appairage ; renvoie le texte envoyé par le téléphone, ou
/// null si l'utilisateur annule.
Future<String?> showPairingScreen(BuildContext context) => Navigator.of(
  context,
).push<String>(MaterialPageRoute(builder: (_) => const PairingScreen()));

/// Écran « Saisir depuis mon téléphone » : code en grand, QR, compte à
/// rebours et « Annuler ». Un nouveau code est proposé à l'expiration.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key, this.client});

  /// Substituable en test ; par défaut [pairingClientProvider].
  final PairingClient? client;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  PairingClient? _client;
  PairSession? _session;
  StreamSubscription<String>? _sub;
  Timer? _tick;
  Duration _left = Duration.zero;
  Object? _error;
  bool _expired = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ref.read(pairingClientProvider);
    unawaited(_start());
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    final client = _client;
    if (client == null || _starting) return;
    _starting = true;
    await _sub?.cancel();
    _tick?.cancel();
    setState(() {
      _session = null;
      _error = null;
      _expired = false;
    });
    try {
      final s = await client.create();
      if (!mounted) return;
      setState(() {
        _session = s;
        _starting = false;
      });
      _updateLeft();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _updateLeft());
      _sub = client
          .waitPayload(s)
          .listen(
            (payload) {
              if (mounted) Navigator.pop(context, payload);
            },
            onError: (Object e) {
              if (!mounted) return;
              _tick?.cancel();
              setState(() {
                if (e is PairingException &&
                    e.code == PairingErrorCode.expired) {
                  _expired = true;
                } else {
                  _error = e;
                }
              });
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _starting = false;
      });
    }
  }

  void _updateLeft() {
    final s = _session;
    if (s == null || !mounted) return;
    final d = s.expiresAt.difference(DateTime.now());
    setState(() => _left = d.isNegative ? Duration.zero : d);
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// KR74PQ -> KR7-4PQ (lisibilité), le code reste saisissable sans tiret.
  static String _grouped(String code) =>
      code.length == 6 ? '${code.substring(0, 3)}-${code.substring(3)}' : code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final theme = Theme.of(context);
    final s = _session;
    final retry = _expired || _error != null;
    return Scaffold(
      appBar: AppBar(title: Text(l.pairTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LumioSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s != null && !retry) ...[
                  Semantics(
                    label: l.pairQrLabel,
                    image: true,
                    child: Container(
                      padding: const EdgeInsets.all(LumioSpacing.md),
                      // Fond clair : contraste du QR, quel que soit le thème.
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(LumioRadius.md),
                      ),
                      child: QrImageView(
                        data: _client!.companionUrl(s.code).toString(),
                        size: 240,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: LumioSpacing.lg),
                  Text(l.pairCodeLabel, style: theme.textTheme.labelLarge),
                  Text(
                    _grouped(s.code),
                    key: const Key('pair-code'),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: c.accent,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: LumioSpacing.sm),
                  Text(
                    l.pairOrOpen(_client!.baseUrl.toString()),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: LumioSpacing.md),
                  Text(l.pairStep1, style: theme.textTheme.bodyMedium),
                  Text(l.pairStep2, style: theme.textTheme.bodyMedium),
                  Text(l.pairStep3, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: LumioSpacing.md),
                  Text(
                    '${l.pairWaiting}  ·  ${l.pairExpiresIn(_mmss(_left))}',
                    style: theme.textTheme.labelLarge,
                  ),
                ] else if (retry) ...[
                  Icon(Icons.error_outline, color: c.error, size: 48),
                  const SizedBox(height: LumioSpacing.md),
                  Text(
                    _expired
                        ? l.pairExpired
                        : l10nForError(l, _error ?? l.errOther),
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: LumioSpacing.md),
                  FilledButton(
                    autofocus: true,
                    onPressed: _start,
                    child: Text(_expired ? l.pairNewCode : l.retry),
                  ),
                ] else
                  const CircularProgressIndicator(),
                const SizedBox(height: LumioSpacing.lg),
                TextButton(
                  autofocus: !retry,
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
