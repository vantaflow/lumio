import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/party_client.dart';
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/party/party_providers.dart';
import 'package:lumio/features/party/party_session.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
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
    // Maquette TV27 : deux colonnes de 820 séparées par un filet ; « Avant la
    // salle » (créer, rejoindre) à gauche, « Salle ouverte » à droite. L'app
    // n'affiche qu'un état à la fois, dans la colonne correspondante. Sur
    // écran étroit (téléphone), une seule colonne centrée.
    return LayoutBuilder(
      builder: (context, box) {
        final room = session == null
            ? null
            : ValueListenableBuilder<PartyView>(
                valueListenable: session,
                builder: (_, v, _) => _room(context, session, v),
              );
        if (box.maxWidth < 1700) {
          // Écran étroit (téléphone, tests) : barre d'application et une seule
          // colonne centrée.
          return Scaffold(
            appBar: AppBar(title: Text(l.partyTitle)),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: room ?? _entry(context),
                ),
              ),
            ),
          );
        }
        final c = context.lumio;
        return TvScreen(
          title: l.partyTitle,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 820,
                child: session == null
                    ? SingleChildScrollView(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.only(top: 70),
                        child: _entry(context),
                      )
                    : null,
              ),
              Container(width: 2, height: 760, color: c.surfaceFocus),
              SizedBox(
                width: 820,
                child: room == null
                    ? null
                    : SingleChildScrollView(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.only(top: 64),
                        child: room,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const _gap = SizedBox(height: 22);

  Widget _entry(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.partyCreateHint,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 28,
            height: 1.4,
            color: Color(0xFFC9D0DA),
          ),
        ),
        _gap,
        TvButton(
          autofocus: true,
          key: const ValueKey('party:create'),
          label: l.partyCreate,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          icon: LumioIconView(LumioIcon.people, size: 32, color: c.onAccent),
          onPressed: _busy ? null : _create,
        ),
        const SizedBox(height: 42),
        Text(
          l.partyJoinTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 36,
            height: 1.15,
          ),
        ),
        _gap,
        TvLabeledField(
          fieldKey: const ValueKey('party:link'),
          controller: _link,
          label: l.partyJoinField,
          hint: l.partyJoinHint,
          onSubmitted: (_) => _join(),
        ),
        _gap,
        TvButton(
          key: const ValueKey('party:join'),
          kind: TvButtonKind.secondary,
          label: l.partyJoinButton,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          onPressed: _busy ? null : _join,
        ),
        if (_error != null) ...[
          _gap,
          _errorLine(context, partyErrorText(l, _error!)),
        ],
      ],
    );
  }

  Widget _errorLine(BuildContext context, String text) {
    final c = context.lumio;
    return Row(
      children: [
        LumioIconView(LumioIcon.alert, size: 28, color: c.error),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            key: const ValueKey('party:error'),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 26,
              fontWeight: FontWeight.w600,
              fontVariations: const [FontVariation.weight(600)],
              color: c.error,
            ),
          ),
        ),
      ],
    );
  }

  /// KR74PQ2X -> KR74-PQ2X (lisibilité).
  static String _grouped(String code) =>
      code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

  Widget _room(BuildContext context, PartySession s, PartyView v) {
    final l = context.l10n;
    final c = context.lumio;
    final theme = Theme.of(context);
    final err = v.error;
    const md = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 28,
      height: 1.4,
      color: Color(0xFFC9D0DA),
    );
    final sm = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 24,
      height: 1.35,
      color: c.textMuted,
    );
    Widget leave({bool primary = false}) => TvButton(
      autofocus: primary,
      key: const ValueKey('party:leave'),
      kind: primary ? TvButtonKind.primary : TvButtonKind.ghost,
      destructive: !primary,
      label: l.partyLeave,
      height: 76,
      fontSize: 28,
      horizontalPadding: 40,
      onPressed: () => unawaited(_leave(s)),
    );
    if (v.status == PartyStatus.failed || v.status == PartyStatus.ended) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            err == null ? l.partyErrUnavailable : partyErrorText(l, err),
            key: const ValueKey('party:error'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 26,
              fontWeight: FontWeight.w600,
              fontVariations: const [FontVariation.weight(600)],
              color: c.error,
            ),
          ),
          const SizedBox(height: 16),
          leave(primary: true),
        ],
      );
    }
    final info = _info;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (v.status == PartyStatus.connecting)
          Text(l.partyConnecting, textAlign: TextAlign.center, style: md)
        else ...[
          Text(
            v.host ? l.partyRoleHost : l.partyRoleGuest,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 40,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.partyParticipants(v.participants),
            key: const ValueKey('party:count'),
            textAlign: TextAlign.center,
            style: md,
          ),
        ],
        if (info != null) ...[
          const SizedBox(height: 16),
          Text(l.partyInviteCode, textAlign: TextAlign.center, style: sm),
          const SizedBox(height: 16),
          Text(
            _grouped(info.inviteCode),
            key: const ValueKey('party:code'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 68,
              letterSpacing: 10,
              height: 1,
              color: c.accent,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: l.partyQrLabel,
            image: true,
            child: Container(
              // Maquette : le SVG en ligne laisse ~8 px sous l'image.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: info.link.toString(),
                size: 160,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.partyLinkLabel, textAlign: TextAlign.center, style: sm),
          const SizedBox(height: 16),
          TvButton(
            key: const ValueKey('party:copy'),
            kind: TvButtonKind.secondary,
            label: l.partyCopyLink,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            icon: LumioIconView(LumioIcon.copy, size: 32, color: c.text),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: info.link.toString()),
              );
              if (!context.mounted) return;
              showTvSnack(context, l.partyLinkCopied);
            },
          ),
        ],
        if (v.metaId != null && !v.host) ...[
          const SizedBox(height: 16),
          TvButton(
            key: const ValueKey('party:openTitle'),
            label: l.partyOpenTitle,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            icon: LumioIconView(LumioIcon.clapper, size: 32, color: c.onAccent),
            onPressed: () => _openTitle(v.metaId!, v.mediaType),
          ),
        ],
        if (v.host) ...[
          const SizedBox(height: 16),
          Semantics(
            toggled: v.allControl,
            child: TvTile(
              key: const ValueKey('party:allControl'),
              minHeight: 92,
              color: c.bg,
              horizontalPadding: 24,
              semanticLabel: l.partyAllControl,
              onSelect: v.status == PartyStatus.connected
                  ? () => unawaited(s.setAllControl(!v.allControl))
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.partyAllControl,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            fontVariations: [FontVariation.weight(700)],
                          ),
                        ),
                        Text(l.partyAllControlHint, style: sm),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  TvSwitch(value: v.allControl),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        leave(),
      ],
    );
  }
}
