import 'package:flutter/widgets.dart';

/// Découpe une zone qui défile verticalement : le contenu ne passe jamais sous
/// l'en-tête ni sur la note de bas d'écran, mais l'anneau de focus reste visible
/// (marge de 14 en haut et en bas, 60 sur les côtés).
class TvScrollClip extends StatelessWidget {
  const TvScrollClip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ClipRect(clipper: const _TvScrollClipper(), child: child);
}

class _TvScrollClipper extends CustomClipper<Rect> {
  const _TvScrollClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-60, -14, size.width + 60, size.height + 14);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}
