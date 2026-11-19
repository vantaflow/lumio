import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/guarded_image.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
import 'package:lumio/ui/theme.dart';

/// Dimensions des cartes de rangée des maquettes TV05/TV44 (300 x 170).
const double tvCardWidth = 300;
const double tvCardHeight = 170;
const double tvCardGap = 28;

/// Dégradés de repli (maquettes TV05) quand un titre n'a pas d'affiche ;
/// choisi de façon stable d'après le titre.
const _fallbackGradients = <(Color, Color)>[
  (Color(0xFF2E6F7A), Color(0xFF8A5A2B)),
  (Color(0xFF7A3B2E), Color(0xFFC98A3D)),
  (Color(0xFF1F4A55), Color(0xFF3C8F7A)),
  (Color(0xFF3C6B2E), Color(0xFFA0B84A)),
  (Color(0xFF6B3C2E), Color(0xFFC9683D)),
  (Color(0xFF2E5A7A), Color(0xFF7AB8C9)),
  (Color(0xFF4A2E2E), Color(0xFFC98A3D)),
  (Color(0xFF2E6F5A), Color(0xFFC9C94A)),
];

(Color, Color) tvGradientFor(String key) {
  var h = 0;
  for (final u in key.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return _fallbackGradients[h % _fallbackGradients.length];
}

/// Fond d'une carte : affiche (si connue) sinon dégradé de repli.
class TvArtwork extends StatelessWidget {
  const TvArtwork({
    super.key,
    required this.seed,
    this.url,
    this.allowPrivate = false,
    this.width = tvCardWidth,
    this.scrim = true,
    this.resize = true,
  });

  final String seed;
  final Uri? url;
  final bool allowPrivate;
  final double width;

  /// Voile sombre en bas pour garder le titre lisible sur une affiche.
  final bool scrim;

  /// Décode à la taille d'affichage (désactivé pour l'affiche de la fiche).
  final bool resize;

  @override
  Widget build(BuildContext context) {
    final (a, b) = tvGradientFor(seed);
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
      ),
    );
    final u = url;
    if (u == null) return gradient;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: resize
              ? ResizeImage.resizeIfNeeded(
                  (width * 2).round(),
                  null,
                  GuardedNetworkImage(u, allowPrivate: allowPrivate),
                )
              : GuardedNetworkImage(u, allowPrivate: allowPrivate),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => gradient,
        ),
        if (scrim)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 1],
                colors: [Color(0x000E1116), Color(0xCC0E1116)],
              ),
            ),
          ),
      ],
    );
  }
}

/// Pastille de source (maquettes `.bd` : fond #0E1116 à 88 %, 24 gras,
/// 4 x 12, rayon 10).
class TvBadge extends StatelessWidget {
  const TvBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xE00E1116),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontVariations: const [FontVariation.weight(700)],
          height: 1.3,
          color: context.lumio.text,
        ),
      ),
    ),
  );
}

/// Carte de rangée des maquettes TV05/TV44 : 300 x 170, rayon 20, titre en
/// bas à gauche, pastille de source en haut à gauche, barre de progression
/// ambre de 8 en bas (reprises).
class TvMediaCard extends StatelessWidget {
  const TvMediaCard({
    super.key,
    required this.title,
    required this.onSelect,
    this.seed,
    this.poster,
    this.allowPrivate = false,
    this.badge,
    this.progress,
    this.semanticLabel,
    this.onLongPress,
    this.width = tvCardWidth,
    this.height = tvCardHeight,
    this.radius = 20,
    this.inset = 16,
  });

  /// Dimensions de la carte : 300 x 170 en rangée, 230 x 340 en recherche
  /// (maquette TV12) ; [width] nul = largeur de la cellule.
  final double? width;
  final double height;
  final double radius;
  final double inset;

  final String title;
  final String? seed;
  final Uri? poster;
  final bool allowPrivate;
  final String? badge;

  /// 0..1 ; absent hors reprises.
  final double? progress;
  final String? semanticLabel;
  final VoidCallback onSelect;

  /// Appui long sur OK (menu de la carte) ; absent : OK ouvre simplement.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return SizedBox(
      width: width,
      height: height,
      child: FocusableCard(
        onSelect: onSelect,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(radius),
        semanticLabel: semanticLabel ?? title,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              TvArtwork(
                seed: seed ?? title,
                url: poster,
                allowPrivate: allowPrivate,
                width: width ?? tvCardWidth,
              ),
              if (badge != null)
                PositionedDirectional(
                  start: 12,
                  top: 12,
                  child: TvBadge(badge!),
                ),
              PositionedDirectional(
                start: inset,
                end: inset,
                bottom: inset,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation.weight(700)],
                    height: 1.35,
                    color: c.text,
                  ),
                ),
              ),
              if (progress != null)
                PositionedDirectional(
                  start: 0,
                  bottom: 0,
                  child: Container(
                    height: 8,
                    width: (width ?? tvCardWidth) * progress!.clamp(0.0, 1.0),
                    color: c.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rangée en chargement (maquette TV44 `.sk`) : cinq cartes 300 x 170 au
/// reflet #1F2630 sur #161B22.
class TvSkeletonCards extends StatelessWidget {
  const TvSkeletonCards({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: tvCardGap),
            Container(
              width: tvCardWidth,
              height: tvCardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  // 100deg CSS : légèrement incliné.
                  begin: const Alignment(-1, -0.18),
                  end: const Alignment(1, 0.18),
                  stops: const [0.3, 0.5, 0.7],
                  colors: [c.surface, c.surfaceRaised, c.surface],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rangée en échec (maquette TV44) : bande 170, icône d'alerte, message,
/// bouton « Réessayer » poussé à droite.
class TvErrorBand extends StatelessWidget {
  const TvErrorBand({
    super.key,
    required this.message,
    required this.onRetry,
    this.autofocus = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 96),
      height: tvCardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          LumioIconView(LumioIcon.alert, size: 32, color: c.error),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 30,
                fontWeight: FontWeight.w600,
                fontVariations: [FontVariation.weight(600)],
                color: Color(0xFFC9D0DA),
              ),
            ),
          ),
          const SizedBox(width: 28),
          TvButton(
            autofocus: autofocus,
            kind: TvButtonKind.secondary,
            label: context.l10n.retry,
            height: 76,
            horizontalPadding: 40,
            fontSize: 28,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Titre de rangée des maquettes (`.rt` : 34 Bricolage gras, marge 96).
class TvRowTitle extends StatelessWidget {
  const TvRowTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 96, right: 96, bottom: 20),
    child: Semantics(
      header: true,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: context.lumio.text,
          height: 1.2,
        ),
      ),
    ),
  );
}

/// Bandeau héros de l'accueil (maquette TV05) : 430 de haut, marges 96, rayon
/// 28, fondu sombre à gauche, accroche ambre, titre 64, deux boutons.
class TvHero extends StatelessWidget {
  const TvHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.onResume,
    this.poster,
    this.background,
    this.allowPrivate = false,
    this.listLabel,
    this.onList,
  });

  final String eyebrow;
  final String title;
  final Uri? poster;

  /// Fond « background » de l'addon : préféré à l'affiche (haute définition).
  final Uri? background;
  final bool allowPrivate;
  final VoidCallback onResume;

  /// Bouton secondaire (« + Ma liste ») ; absent si l'action n'existe pas.
  final String? listLabel;
  final VoidCallback? onList;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final l = context.l10n;
    return Container(
      height: 430,
      margin: const EdgeInsets.symmetric(horizontal: 96),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (background != null || poster == null)
            TvArtwork(
              seed: title,
              url: background,
              allowPrivate: allowPrivate,
              width: 1728,
              scrim: false,
            )
          else
            _PosterBackdrop(
              key: const ValueKey('hero-poster-backdrop'),
              seed: title,
              poster: poster!,
              allowPrivate: allowPrivate,
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                // linear-gradient(100deg, #0E1116 20%, transparent 70%)
                begin: const Alignment(-1, -0.18),
                end: const Alignment(1, 0.18),
                stops: const [0.2, 0.7],
                colors: [c.bg, c.bg.withValues(alpha: 0)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation.weight(700)],
                    color: c.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 64,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TvButton(
                      key: const ValueKey('home-hero-resume'),
                      autofocus: true,
                      label: l.heroResume,
                      height: 72,
                      horizontalPadding: 40,
                      fontSize: 30,
                      onPressed: onResume,
                    ),
                    if (listLabel != null) ...[
                      const SizedBox(width: 24),
                      TvButton(
                        key: const ValueKey('home-hero-list'),
                        kind: TvButtonKind.secondary,
                        label: listLabel!,
                        height: 72,
                        horizontalPadding: 36,
                        fontSize: 30,
                        onPressed: onList,
                      ),
                    ],
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

/// Héros sans fond d'addon : l'affiche (souvent basse définition) n'est ni
/// étirée ni floutée en grand ; elle est posée à droite à sa taille d'origine
/// (jamais agrandie), sur son propre reflet flou et assombri.
class _PosterBackdrop extends StatelessWidget {
  const _PosterBackdrop({
    super.key,
    required this.seed,
    required this.poster,
    required this.allowPrivate,
  });

  final String seed;
  final Uri poster;
  final bool allowPrivate;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final (a, b) = tvGradientFor(seed);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [a, b])),
        ),
        RepaintBoundary(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Opacity(
              opacity: 0.35,
              child: Image(
                image: ResizeImage.resizeIfNeeded(
                  160,
                  null,
                  GuardedNetworkImage(poster, allowPrivate: allowPrivate),
                ),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        ColoredBox(color: c.bg.withValues(alpha: 0.35)),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 72),
            child: SizedBox(
              width: 300,
              height: 380,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(
                  image: GuardedNetworkImage(
                    poster,
                    allowPrivate: allowPrivate,
                  ),
                  fit: BoxFit.scaleDown,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
