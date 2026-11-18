import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lumio/ui/common/tv_text_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/party_client.dart';
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/party/party_providers.dart';
import 'package:lumio/features/party/party_session.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart' show MetaPreview;
import 'package:qr_flutter/qr_flutter.dart';

String partyErrorText(AppLocalizations l, PartyErrorCode c) => switch (c) {
  PartyErrorCode.invalidLink => l.partyErrInvalidLink,
  PartyErrorCode.wrongCode => l.partyErrWrongCode,
  PartyErrorCode.full => l.partyErrFull,
  PartyErrorCode.notFound => l.partyErrNotFound,
  PartyErrorCode.rateLimited => l.partyErrRateLimited,
  PartyErrorCode.unavailable => l.partyErrUnavailable,
};

/// Écran « Regarder ensemble » : créer une salle (code + lien + QR), en
/// rejoindre une, voir les participants, quitter. La salle reste ouverte
/// quand l'écran se ferme (le lecteur s'y synchronise) ; seul « Quitter » la
/// ferme.
class PartyScreen extends ConsumerStatefulWidget {
  const PartyScreen({
    super.key,
    this.metaId,
    this.mediaType,
    this.onOpenTitle,
    this.client,
  });

  /// Titre en cours de lecture, annoncé aux invités (identifiant seulement).
  final String? metaId;

  /// Type du titre (movie, series…), annoncé avec [metaId].
  final String? mediaType;

  /// Ouvre le titre commun ; par défaut sa fiche (filtre du profil appliqué).
  final void Function(BuildContext context, String metaId, String? mediaType)?
  onOpenTitle;

  /// Substituable en test ; par défaut [partyClientProvider].
  final PartyClient? client;

  @override
  ConsumerState<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends ConsumerState<PartyScreen> {
  final _link = TextEditingController();
  PartyRoomInfo? _info; // seulement si l'on a créé la salle
  PartyErrorCode? _error;
  bool _busy = false;

  PartyClient? get _client => widget.client ?? ref.read(partyClientProvider);

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _open(PartySession s) {
    ref.read(partySessionProvider)?.dispose();
    ref.read(partySessionProvider.notifier).state = s;
    unawaited(s.start());
  }

  Future<void> _create() async {
    final client = _client;
    if (client == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await client.create(
        metaId: widget.metaId,
        type: widget.mediaType,
      );
      if (!mounted) return;
      _info = info;
      _open(
        PartySession(
          client: client,
          roomId: info.roomId,
          inviteCode: info.inviteCode,
          hostKey: info.hostKey,
          host: true,
        ),
      );
    } on PartyException catch (e) {
      if (mounted) _error = e.code;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _join() {
    final client = _client;
    if (client == null || _busy) return;
    final p = parsePartyLink(_link.text);
    if (p == null) {
      setState(() => _error = PartyErrorCode.invalidLink);
      return;
    }
    setState(() => _error = null);
    _info = null;
    _open(PartySession(client: client, roomId: p.roomId, inviteCode: p.code));
  }

  Future<void> _leave(PartySession s) async {
    await s.leave();
    if (!mounted) return;
    ref.read(partySessionProvider.notifier).state = null;
    s.dispose();
    setState(() => _info = null);
  }

  void _openTitle(String metaId, String? mediaType) {
    final open = widget.onOpenTitle;
    if (open != null) {
      open(context, metaId, mediaType);
      return;
    }
    // Chaque participant ouvre le titre avec ses propres addons ; la fiche
    // applique le filtre du profil (profil enfant compris).
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailScreen(
            preview: MetaPreview(
              id: metaId,
              type: mediaType ?? 'movie',
              name: metaId,
              sourceAddonId: '',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(partySessionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.partyTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LumioSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: session == null
                ? _entry(context)
                : ValueListenableBuilder<PartyView>(
                    valueListenable: session,
                    builder: (_, v, _) => _room(context, session, v),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _entry(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.partyCreateHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: LumioSpacing.md),
        FocusRing(
          child: FilledButton.icon(
            autofocus: true,
            key: const ValueKey('party:create'),
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.groups_outlined),
            label: Text(l.partyCreate),
          ),
        ),
        const SizedBox(height: LumioSpacing.xl),
        Text(l.partyJoinTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: LumioSpacing.sm),
        TvTextField(
          key: const ValueKey('party:link'),
          controller: _link,
          maxLength: 300,
          decoration: InputDecoration(
            labelText: l.partyJoinField,
            hintText: l.partyJoinHint,
            counterText: '',
          ),
          onSubmitted: (_) => _join(),
        ),
        const SizedBox(height: LumioSpacing.sm),
        FocusRing(
          child: OutlinedButton(
            key: const ValueKey('party:join'),
            onPressed: _busy ? null : _join,
            child: Text(l.partyJoinButton),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: LumioSpacing.md),
          Text(
            partyErrorText(l, _error!),
            key: const ValueKey('party:error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  /// KR74PQ2X -> KR74-PQ2X (lisibilité).
  static String _grouped(String code) =>
      code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

  Widget _room(BuildContext context, PartySession s, PartyView v) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final err = v.error;
    if (v.status == PartyStatus.failed || v.status == PartyStatus.ended) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            err == null ? l.partyErrUnavailable : partyErrorText(l, err),
            key: const ValueKey('party:error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: LumioSpacing.md),
          FocusRing(
            child: FilledButton(
              autofocus: true,
              key: const ValueKey('party:leave'),
              onPressed: () => unawaited(_leave(s)),
              child: Text(l.partyLeave),
            ),
          ),
        ],
      );
    }
    final info = _info;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (v.status == PartyStatus.connecting)
          Text(l.partyConnecting, textAlign: TextAlign.center)
        else ...[
          Text(
            v.host ? l.partyRoleHost : l.partyRoleGuest,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: LumioSpacing.xs),
          Text(
            l.partyParticipants(v.participants),
            key: const ValueKey('party:count'),
            textAlign: TextAlign.center,
          ),
        ],
        if (info != null) ...[
          const SizedBox(height: LumioSpacing.lg),
          Text(l.partyInviteCode, textAlign: TextAlign.center),
          Text(
            _grouped(info.inviteCode),
            key: const ValueKey('party:code'),
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: LumioSpacing.md),
          Center(
            child: Semantics(
              label: l.partyQrLabel,
              image: true,
              child: Container(
                padding: const EdgeInsets.all(LumioSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(LumioRadius.md),
                ),
                child: QrImageView(
                  data: info.link.toString(),
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: LumioSpacing.sm),
          FocusRing(
            child: TextButton.icon(
              key: const ValueKey('party:copy'),
              icon: const Icon(Icons.copy),
              label: Text(l.partyCopyLink),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: info.link.toString()),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l.partyLinkCopied)));
              },
            ),
          ),
        ],
        if (v.host)
          SwitchListTile(
            key: const ValueKey('party:allControl'),
            title: Text(l.partyAllControl),
            subtitle: Text(l.partyAllControlHint),
            value: v.allControl,
            onChanged: v.status == PartyStatus.connected
                ? (x) => unawaited(s.setAllControl(x))
                : null,
          ),
        if (v.metaId != null && !v.host) ...[
          const SizedBox(height: LumioSpacing.md),
          FocusRing(
            child: FilledButton.icon(
              key: const ValueKey('party:openTitle'),
              onPressed: () => _openTitle(v.metaId!, v.mediaType),
              icon: const Icon(Icons.movie_outlined),
              label: Text(l.partyOpenTitle),
            ),
          ),
        ],
        const SizedBox(height: LumioSpacing.lg),
        FocusRing(
          child: OutlinedButton(
            key: const ValueKey('party:leave'),
            onPressed: () => unawaited(_leave(s)),
            child: Text(l.partyLeave),
          ),
        ),
      ],
    );
  }
}
