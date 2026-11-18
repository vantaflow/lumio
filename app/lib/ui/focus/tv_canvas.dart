import 'package:flutter/material.dart';

/// Canevas logique des maquettes TV (docs/design/README.md) : 1920 dp de large.
const double tvCanvasWidth = 1920;

/// Facteur px logiques réels / px de maquette pour une largeur donnée.
double tvScaleFor(double actualWidth) => actualWidth / tvCanvasWidth;

/// Met toute l'interface TV à l'échelle du canevas 1920 dp des maquettes.
///
/// Les maquettes sont dessinées en px physiques sur 1920 x 1080 ; or une box
/// annonce un `devicePixelRatio` d'environ 2 (écran 1920 x 1080 en densité
/// 320), soit seulement 960 dp logiques : sans cette échelle, tout paraîtrait
/// deux fois trop gros. Ici une seule transformation centrale : l'enfant est
/// disposé sur [tvCanvasWidth] de large (la hauteur suit le rapport de
/// l'écran) puis réduit de `largeur réelle / 1920`. `MediaQuery` annonce la
/// taille du canevas, tous les écrans raisonnent donc en px de maquette.
class TvCanvas extends StatelessWidget {
  const TvCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = tvScaleFor(mq.size.width);
    if ((scale - 1).abs() < 0.001) return child;
    final canvas = Size(tvCanvasWidth, mq.size.height / scale);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: canvas.width,
        maxWidth: canvas.width,
        minHeight: canvas.height,
        maxHeight: canvas.height,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: canvas,
            child: MediaQuery(
              data: mq.copyWith(
                size: canvas,
                devicePixelRatio: mq.devicePixelRatio * scale,
                padding: mq.padding / scale,
                viewPadding: mq.viewPadding / scale,
                viewInsets: mq.viewInsets / scale,
                systemGestureInsets: mq.systemGestureInsets / scale,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
