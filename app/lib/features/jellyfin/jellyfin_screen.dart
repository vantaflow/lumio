import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lumio/ui/common/tv_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/jellyfin_repository.dart';
import 'package:lumio/features/detail/playback_service.dart'
    show playerBuilderProvider;
import 'package:lumio/features/home/home_providers.dart'
    show contentAllowed, profileAllows;
import 'package:lumio/features/jellyfin/jellyfin_providers.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/guarded_image.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

// --- Lecture ---

/// Lance la lecture d'un élément Jellyfin. Le flux passe par le proxy local
/// du lecteur (jamais `trustedLocal`), avec l'accord réseau privé propre au
/// serveur ; le jeton part dans l'en-tête imposé, pas dans l'URL. Refusé à un
/// profil enfant si la classification est absente, inconnue ou trop haute.
/// Rend `true` si la lecture a été lancée.
Future<bool> playJellyfinItem(
  BuildContext context, {
  required JellyfinRepository repo,
  required Profile? profile,
  required String profileId,
  required Widget Function(PlayerScreen) build,
  required String serverId,
  required String itemId,
}) async {
  final l = context.l10n;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  void tell(String m) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
  final JellyfinServer? server;
  final JellyfinClient? client;
  final JellyfinItem item;
  try {
    server = await repo.server(serverId);
    client = await repo.client(serverId);
    if (server == null || client == null) {
      tell(l.jellyfinErrExpired);
      return false;
    }
    item = await client.item(itemId);
  } on Object catch (e) {
    tell(l10nForError(l, e));
    return false;
  }
  if (!context.mounted) return false;
  if (!contentAllowed(profile, [item.certification])) {
    tell(l.notAllowedForProfile);
    return false;
  }
  if (!item.playable) {
    tell(l.jellyfinPlayFailed);
    return false;
  }
  final id = jellyfinItemId(serverId, itemId);
  await navigator.push<PlayerExit>(
    MaterialPageRoute(
      builder: (_) => build(
        PlayerScreen(
          item: StreamItem(
            addonId: serverId,
            title: item.name,
            url: client!.streamUrl(itemId),
            requestHeaders: client.streamHeaders(),
          ),
          allowPrivate: server!.allowPrivate,
          metaId: id,
          videoId: id,
          profileId: profileId,
          meta: Meta(
            id: id,
            type: 'movie',
            name: item.name,
            certification: item.certification,
          ),
        ),
      ),
    ),
  );
  return true;
}

/// [playJellyfinItem] depuis un widget.
Future<bool> playJellyfinFromWidget(
  BuildContext context,
  WidgetRef ref, {
  required String serverId,
  required String itemId,
}) => playJellyfinItem(
  context,
  repo: ref.read(jellyfinRepositoryProvider),
  profile: ref.read(currentProfileProvider),
  profileId: ref.read(currentProfileIdProvider),
  build: ref.read(playerBuilderProvider),
  serverId: serverId,
  itemId: itemId,
);

// --- Ouverture depuis l'accueil, la recherche, « Continuer » ---

/// Ouvre un élément Jellyfin : conteneur (série, dossier) → navigation ;
/// film ou épisode → fiche.
Future<void> openJellyfinDetail(BuildContext context, MetaPreview item) {
  final ids = parseJellyfinId(item.id);
  if (ids == null) return Future.value();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => item.type == 'series'
          ? JellyfinBrowseScreen(
              serverId: ids.serverId,
              parentId: ids.itemId,
              title: item.name,
            )
          : JellyfinDetailScreen(preview: item),
    ),
  );
}

/// Fiche d'un film ou d'un épisode Jellyfin.
class JellyfinDetailScreen extends ConsumerStatefulWidget {
  const JellyfinDetailScreen({super.key, required this.preview});

  final MetaPreview preview;

  @override
  ConsumerState<JellyfinDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<JellyfinDetailScreen> {
  late final ({String serverId, String itemId}) _ids = parseJellyfinId(
    widget.preview.id,
  )!;
  late Future<JellyfinItem> _item = _load();
  bool _allowPrivate = false;

  Future<JellyfinItem> _load() async {
    final repo = ref.read(jellyfinRepositoryProvider);
    final server = await repo.server(_ids.serverId);
    final client = await repo.client(_ids.serverId);
    if (server == null || client == null) {
      throw const JellyfinAuthException(expired: true);
    }
    _allowPrivate = server.allowPrivate;
    return client.item(_ids.itemId);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = ref.watch(currentProfileProvider);
    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.preview.name),
          backgroundColor: Colors.transparent,
        ),
        body: FutureBuilder<JellyfinItem>(
          future: _item,
          builder: (context, snap) {
            if (snap.hasError) {
              return StateView.error(
                message: l10nForError(l, snap.error!),
                onRetry: () => setState(() => _item = _load()),
              );
            }
            final it = snap.data;
            if (it == null) return const StateView.loading();
            if (!contentAllowed(profile, [it.certification])) {
              return StateView.empty(message: l.notAllowedForProfile);
            }
            final theme = Theme.of(context);
            final c = context.lumio;
            final meta = [
              ?it.seriesName,
              if (it.season != null && it.episode != null)
                'S${it.season}E${it.episode}',
              ?it.year?.toString(),
              ?it.officialRating,
            ].join(' · ');
            return ListView(
              padding: const EdgeInsets.all(LumioSpacing.lg),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.preview.poster != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: LumioSpacing.lg,
                        ),
                        child: SizedBox(
                          width: 200,
                          height: 300,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(LumioRadius.md),
                            child: Image(
                              image: GuardedNetworkImage(
                                widget.preview.poster!,
                                allowPrivate: _allowPrivate,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.name, style: theme.textTheme.headlineSmall),
                          if (meta.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: LumioSpacing.xs,
                              ),
                              child: Text(
                                meta,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: c.textMuted,
                                ),
                              ),
                            ),
                          if (it.overview != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: LumioSpacing.md,
                              ),
                              child: Text(it.overview!),
                            ),
                          const SizedBox(height: LumioSpacing.lg),
                          FilledButton.icon(
                            key: const ValueKey('jellyfin-play'),
                            autofocus: true,
                            onPressed: () => playJellyfinFromWidget(
                              context,
                              ref,
                              serverId: _ids.serverId,
                              itemId: _ids.itemId,
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l.play),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- Navigation dans les bibliothèques ---

const _pageSize = 50;

/// Contenu d'un serveur : ses bibliothèques (sans [parentId]) ou le contenu
/// d'un dossier, une page à la fois (`StartIndex` / `Limit`).
class JellyfinBrowseScreen extends ConsumerStatefulWidget {
  const JellyfinBrowseScreen({
    super.key,
    required this.serverId,
    this.parentId,
    this.title,
  });

  final String serverId;
  final String? parentId;
  final String? title;

  @override
  ConsumerState<JellyfinBrowseScreen> createState() => _BrowseState();
}

class _BrowseState extends ConsumerState<JellyfinBrowseScreen> {
  JellyfinClient? _client;
  final _entries = <({String id, String name, bool container})>[];
  final _certs = <String, String?>{};
  bool _loading = true;
  bool _more = false;
  Object? _error;
  String _title = '';

  @override
  void initState() {
    super.initState();
    _title = widget.title ?? '';
    unawaited(_loadFirst());
  }

  Future<JellyfinClient> _ensureClient() async {
    final c = _client;
    if (c != null) return c;
    final made = await ref
        .read(jellyfinRepositoryProvider)
        .client(widget.serverId);
    if (made == null) throw const JellyfinAuthException(expired: true);
    return _client = made;
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
      _entries.clear();
    });
    try {
      final c = await _ensureClient();
      if (widget.title == null) {
        final s = await ref
            .read(jellyfinRepositoryProvider)
            .server(widget.serverId);
        _title = s?.name ?? '';
      }
      if (widget.parentId == null) {
        for (final v in await c.views()) {
          _entries.add((id: v.id, name: v.name, container: true));
        }
      } else {
        await _fetch(c);
      }
    } on Object catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetch(JellyfinClient c) async {
    final page = await c.items(
      widget.parentId!,
      skip: _entries.length,
      limit: _pageSize,
    );
    for (final it in page.items) {
      _certs[it.id] = it.certification;
      _entries.add((id: it.id, name: it.name, container: !it.playable));
    }
    // Le filtre d'âge n'agit qu'à l'affichage : la page suivante part du
    // nombre d'éléments reçus.
    _hasMore = page.hasMore;
  }

  bool _hasMore = false;

  Future<void> _loadMore() async {
    setState(() => _more = true);
    try {
      await _fetch(await _ensureClient());
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10nForError(context.l10n, e))),
          );
      }
    }
    if (mounted) setState(() => _more = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = ref.watch(currentProfileProvider);
    final shown = [
      for (final e in _entries)
        if (widget.parentId == null || profileAllows(profile, _certs[e.id])) e,
    ];
    Widget body;
    if (_loading) {
      body = const StateView.loading();
    } else if (_error != null) {
      body = StateView.error(
        message: l10nForError(l, _error!),
        onRetry: _loadFirst,
      );
    } else if (shown.isEmpty && !_hasMore) {
      body = StateView.empty(message: l.jellyfinEmptyFolder);
    } else {
      body = ListView(
        padding: const EdgeInsets.all(LumioSpacing.md),
        children: [
          for (final e in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: LumioSpacing.sm),
              child: FocusRing(
                child: ListTile(
                  key: ValueKey('jellyfin-item:${e.id}'),
                  leading: Icon(
                    e.container ? Icons.folder_outlined : Icons.movie_outlined,
                  ),
                  title: Text(e.name),
                  onTap: () => e.container
                      ? Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => JellyfinBrowseScreen(
                              serverId: widget.serverId,
                              parentId: e.id,
                              title: e.name,
                            ),
                          ),
                        )
                      : playJellyfinFromWidget(
                          context,
                          ref,
                          serverId: widget.serverId,
                          itemId: e.id,
                        ),
                ),
              ),
            ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: LumioSpacing.sm),
              child: Center(
                child: OutlinedButton(
                  key: const ValueKey('jellyfin-more'),
                  onPressed: _more ? null : _loadMore,
                  child: Text(l.jellyfinLoadMore),
                ),
              ),
            ),
        ],
      );
    }
    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title.isEmpty ? l.jellyfinLibraries : _title),
        ),
        body: body,
      ),
    );
  }
}

// --- Gestion des serveurs (réglages) ---

/// Serveurs Jellyfin : liste, ajout (avec avertissement en http), retrait.
class JellyfinServersScreen extends ConsumerWidget {
  const JellyfinServersScreen({super.key});

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    JellyfinServer s,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.jellyfinRemoveTitle(s.name)),
        content: Text(ctx.l10n.jellyfinRemoveBody),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('jellyfin-remove-ok'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.jellyfinRemove(s.name)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(jellyfinServersProvider.notifier).remove(s.id);
    ref.invalidate(jellyfinRowsProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.jellyfinRemoved)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final servers = ref.watch(jellyfinServersProvider);
    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.jellyfinServers),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: LumioSpacing.sm),
              child: FilledButton.icon(
                key: const ValueKey('jellyfin-add'),
                autofocus: true,
                onPressed: () async {
                  final added = await showDialog<bool>(
                    context: context,
                    builder: (_) => const JellyfinAddDialog(),
                  );
                  if (added == true) ref.invalidate(jellyfinRowsProvider);
                },
                icon: const Icon(Icons.add),
                label: Text(l.jellyfinAddServer),
              ),
            ),
          ],
        ),
        body: servers.when(
          loading: () => const StateView.loading(),
          error: (e, _) => StateView.error(
            message: l10nForError(l, e),
            onRetry: () => ref.invalidate(jellyfinServersProvider),
          ),
          data: (list) {
            if (list.isEmpty) return StateView.empty(message: l.jellyfinEmpty);
            return ListView(
              padding: const EdgeInsets.all(LumioSpacing.md),
              children: [
                for (final s in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LumioSpacing.sm),
                    child: FocusRing(
                      child: ListTile(
                        key: ValueKey('jellyfin-server:${s.id}'),
                        leading: const Icon(Icons.dns_outlined),
                        title: Text(s.name),
                        subtitle: Text(l.jellyfinSignedInAs(s.userName)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                JellyfinBrowseScreen(serverId: s.id),
                          ),
                        ),
                        trailing: IconButton(
                          key: ValueKey('jellyfin-remove:${s.id}'),
                          tooltip: l.jellyfinRemove(s.name),
                          onPressed: () => _remove(context, ref, s),
                          icon: Icon(
                            Icons.delete_outline,
                            color: context.lumio.error,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Saisie d'un serveur : adresse, utilisateur, mot de passe. Une adresse
/// http hors réseau privé demande une confirmation explicite ; un certificat
/// invalide est affiché tel quel et n'est jamais accepté.
class JellyfinAddDialog extends ConsumerStatefulWidget {
  const JellyfinAddDialog({super.key});

  @override
  ConsumerState<JellyfinAddDialog> createState() => _AddState();
}

class _AddState extends ConsumerState<JellyfinAddDialog> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// `https://` par défaut quand le schéma est omis.
  Uri? _parse() {
    var t = _url.text.trim();
    if (t.isEmpty) return null;
    if (!t.contains('://')) t = 'https://$t';
    return Uri.tryParse(t);
  }

  Future<bool> _confirmInsecure() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const ValueKey('jellyfin-insecure'),
          title: Text(ctx.l10n.jellyfinInsecureTitle),
          content: Text(ctx.l10n.jellyfinInsecureBody),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
            ),
            TextButton(
              key: const ValueKey('jellyfin-insecure-ok'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.jellyfinInsecureContinue),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _submit() async {
    final l = context.l10n;
    final url = _parse();
    if (url == null || url.host.isEmpty) {
      setState(() => _error = l.jellyfinErrAddress);
      return;
    }
    var confirmed = false;
    if (url.scheme == 'http' && !isPrivateServer(url)) {
      confirmed = await _confirmInsecure();
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(jellyfinServersProvider.notifier)
          .add(
            url,
            _user.text.trim(),
            _pass.text,
            confirmedInsecure: confirmed,
          );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10nForError(context.l10n, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.jellyfinAddServer),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TvTextField(
              key: const ValueKey('jellyfin-url'),
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.jellyfinServerUrl,
                hintText: l.jellyfinServerUrlHint,
              ),
            ),
            TvTextField(
              key: const ValueKey('jellyfin-user'),
              controller: _user,
              autocorrect: false,
              decoration: InputDecoration(labelText: l.jellyfinUser),
            ),
            TvTextField(
              key: const ValueKey('jellyfin-pass'),
              controller: _pass,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(labelText: l.jellyfinPassword),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: LumioSpacing.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const ValueKey('jellyfin-error'),
                    style: TextStyle(color: context.lumio.error),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('jellyfin-connect'),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? l.jellyfinConnecting : l.jellyfinConnect),
        ),
      ],
    );
  }
}
