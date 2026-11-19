import 'package:flutter/material.dart';
import 'package:lumio/ui/common/guarded_image.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// Logo d'addon avec repli sur une icône (logo absent ou illisible).
class AddonLogo extends StatelessWidget {
  const AddonLogo({
    super.key,
    required this.logo,
    this.size = 48,
    this.name,
    this.radius,
  });
  final Uri? logo;
  final double size;

  /// Rayon des coins (0,28 x taille par défaut ; 36 pour le logo de 150 de TV08).
  final double? radius;

  /// Nom de l'addon : sa première lettre sert de logo de repli (maquettes
  /// TV10 / P09 : pastille colorée), au lieu d'une icône ou d'un texte
  /// alternatif qui déborde.
  final String? name;

  static const _palette = [
    Color(0xFF4FD1C5),
    Color(0xFFFFB84D),
    Color(0xFFFF8A65),
    Color(0xFF5BD68A),
    Color(0xFF64B5F6),
    Color(0xFFE6C17A),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final letter = (name ?? '').trim();
    final Widget fallback = letter.isEmpty
        ? Icon(Icons.extension_outlined, color: c.accent, size: size * 0.5)
        : ColoredBox(
            color:
                _palette[letter.runes.fold<int>(0, (a, b) => a + b) %
                    _palette.length],
            child: Center(
              child: Text(
                letter.characters.first.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation.weight(700)],
                  color: c.onAccent,
                ),
              ),
            ),
          );
    // Le logo vient de l'addon : adresse locale ou réseau privé = pas chargé.
    var safe = logo != null;
    if (safe) {
      try {
        UrlGuard.check(logo!);
      } on UnsafeUrlException {
        safe = false;
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(radius ?? size * 0.28),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: !safe
          ? fallback
          : Image(
              image: GuardedNetworkImage(logo!, allowPrivate: false),
              width: size,
              height: size,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
