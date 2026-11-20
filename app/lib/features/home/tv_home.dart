import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
import 'package:lumio/ui/theme.dart';

/// Logo Lumio (anneau ambre + point turquoise) des maquettes, 44 dp.
class LumioMark extends StatelessWidget {
  const LumioMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MarkPainter(context.lumio.accent, context.lumio.secondary),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.ring, this.dot);

  final Color ring;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 72;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      c,
      30 * k,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9 * k,
    );
    canvas.drawCircle(c, 10 * k, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.ring != ring || old.dot != dot;
}

/// Barre haute TV (maquettes TV05/TV13) : logo, une seule ligne Accueil ·
/// Films · Séries · Recherche · Réglages, avatar du profil à droite. Les
/// autres entrées (liste, calendrier, personnalisation, profil) sont derrière
/// l'avatar.
class TvTopBar extends ConsumerWidget {
  const TvTopBar({
    super.key,
    required this.homeNode,
    required this.onMovies,
    required this.onSeries,
    required this.onSearch,
    required this.onSettings,
    required this.onLibrary,
    required this.onCalendar,
    required this.onCustomize,
  });

  /// Nœud de focus de « Accueil » (cible du retour télécommande).
  final FocusNode homeNode;
  final VoidCallback onMovies;
  final VoidCallback onSeries;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onLibrary;
  final VoidCallback onCalendar;
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(currentProfileProvider);
    final name = (profile?.name ?? '').trim();
    final avatar = avatarColorOf(
      ref.watch(profilesProvider).value ?? const <Profile>[],
      profile,
    );
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return SizedBox(
      height: 120,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 96),
        child: Row(
          children: [
            Semantics(
              header: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LumioMark(),
                  const SizedBox(width: 16),
                  Text(
                    'Lumio',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge?.copyWith(fontSize: 40),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Premier élément de la barre : Gauche ne mène nulle
                      // part, le focus reste sur « Accueil » (sans ce garde,
                      // il sautait dans le contenu et l'anneau disparaissait).
                      Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onKeyEvent: (_, event) =>
                            event.logicalKey == LogicalKeyboardKey.arrowLeft
                            ? KeyEventResult.handled
                            : KeyEventResult.ignored,
                        child: TvNavPill(
                          key: const ValueKey('home-nav-home'),
                          label: l.tvNavHome,
                          selected: true,
                          focusNode: homeNode,
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      TvNavPill(label: l.typeMovie, onPressed: onMovies),
                      const SizedBox(width: 12),
                      TvNavPill(label: l.typeSeries, onPressed: onSeries),
                      const SizedBox(width: 12),
                      TvNavPill(label: l.homeSearch, onPressed: onSearch),
                      const SizedBox(width: 12),
                      TvNavPill(
                        key: const ValueKey('home-settings'),
                        label: l.homeSettings,
                        onPressed: onSettings,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FocusableCard(
              key: const ValueKey('home-avatar'),
              scale: 1.1,
              borderRadius: BorderRadius.circular(28),
              semanticLabel: name.isEmpty ? l.profileFallback : name,
              onSelect: () => _openMenu(context, ref),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatar,
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation.weight(700)],
                    color: context.lumio.onAccent,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menu de l'avatar (maquette TV43) : s'ouvre sous l'avatar, à droite, sur
  /// le voile des pop-ups ; Retour le ferme.
  Future<void> _openMenu(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final entries = <(LumioIcon, String, VoidCallback)>[
      (LumioIcon.list, l.homeManageList, onLibrary),
      (LumioIcon.calendar, l.homeCalendar, onCalendar),
      (LumioIcon.sliders, l.homeCustomize, onCustomize),
      (
        LumioIcon.user,
        l.tvSwitchProfile,
        () => switchProfileFlow(context, ref),
      ),
    ];
    final c = context.lumio;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0xC206080C),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, _) => TvScaffold(
        onBack: () => Navigator.of(ctx).pop(),
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 136, right: 96),
            child: Material(
              key: const ValueKey('home-avatar-menu'),
              color: c.surface,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 560,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      FocusableCard(
                        autofocus: i == 0,
                        scale: 1.02,
                        borderRadius: BorderRadius.circular(22),
                        semanticLabel: entries[i].$2,
                        onSelect: () {
                          Navigator.of(ctx).pop();
                          entries[i].$3();
                        },
                        child: Container(
                          height: 88,
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          decoration: BoxDecoration(
                            color: c.surfaceFocus,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              LumioIconView(
                                entries[i].$1,
                                size: 36,
                                color: c.textMuted,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  entries[i].$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    fontVariations: [FontVariation.weight(700)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Accueil vide TV (maquette TV13) : aucune source. Les boutons ouvrent
/// l'ajout d'addon, d'un dossier local et d'un serveur Jellyfin.
class TvEmptyHome extends StatelessWidget {
  const TvEmptyHome({
    super.key,
    required this.onAddAddon,
    required this.onAddLocal,
    required this.onAddJellyfin,
  });

  final VoidCallback onAddAddon;
  final VoidCallback onAddLocal;
  final VoidCallback onAddJellyfin;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    Widget step(int n, String title, String body) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceFocus,
              ),
              child: Text(
                '$n',
                style: t.titleSmall
                    ?.weighted(FontWeight.w700)
                    .copyWith(color: c.accent),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: t.bodyLarge
                  ?.weighted(FontWeight.w700)
                  .copyWith(fontSize: 30),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: t.bodyLarge?.copyWith(
                fontSize: 26,
                color: c.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      key: const ValueKey('tv-empty-home'),
      padding: const EdgeInsets.fromLTRB(160, 64, 160, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.tvEmptyEyebrow,
            style: t.bodyLarge
                ?.weighted(FontWeight.w700)
                .copyWith(fontSize: 26, color: c.secondary, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            l.tvEmptyTitle,
            style: t.displayLarge?.copyWith(fontSize: 72, height: 1.2),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: Text(
              l.tvEmptyBody,
              style: t.bodyLarge?.copyWith(
                fontSize: 32,
                color: c.textMuted,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              TvButton(
                key: const ValueKey('tv-empty-addon'),
                autofocus: true,
                label: l.addAddon,
                onPressed: onAddAddon,
              ),
              const SizedBox(width: 24),
              TvButton(
                key: const ValueKey('tv-empty-local'),
                kind: TvButtonKind.secondary,
                label: l.tvEmptyLocal,
                onPressed: onAddLocal,
              ),
              const SizedBox(width: 24),
              TvButton(
                key: const ValueKey('tv-empty-jellyfin'),
                kind: TvButtonKind.secondary,
                label: l.tvEmptyJellyfin,
                onPressed: onAddJellyfin,
              ),
            ],
          ),
          const SizedBox(height: 72),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              step(1, l.tvEmptyStep1Title, l.tvEmptyStep1Body),
              const SizedBox(width: 28),
              step(2, l.tvEmptyStep2Title, l.tvEmptyStep2Body),
              const SizedBox(width: 28),
              step(3, l.tvEmptyStep3Title, l.tvEmptyStep3Body),
            ],
          ),
        ],
      ),
    );
  }
}
