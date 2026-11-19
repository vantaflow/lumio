import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Icônes exactes des maquettes TV (docs/design/maquettes/project) : chemins
/// SVG de la grille 24 x 24 (contour de 2, extrémités et jonctions arrondies),
/// dessinés par [CustomPaint] sans dépendance externe.
enum LumioIcon {
  general('<c 12 12 3><p M12 2v3M12 19v3M2 12h3M19 12h3>'),
  plus('<p M12 5v14M5 12h14>'),
  back('<p M15 5l-7 7 7 7>'),
  play('<p M7 5l12 7-12 7z>'),
  torrents('<p M5 20v-8a7 7 0 0114 0v8h-4v-8a3 3 0 00-6 0v8z>'),
  user('<c 12 8 4><p M4 21a8 8 0 0116 0>'),
  tracking('<p M4 18l5-6 4 4 7-9>'),
  group('<c 8 9 3><c 16 9 3><p M2 20a6 6 0 0112 0M10 20a6 6 0 0112 0>'),
  download('<p M12 3v12M7 10l5 5 5-5M4 21h16>'),
  phone(
    '<r 3 3 7 7><r 14 3 7 7><r 3 14 7 7>'
    '<p M14 14h3v3h-3zM20 14v7M14 20h3>',
    join: false,
  ),
  chevron('<p M9 6l6 6-6 6>'),
  chevronAlt('<p M9 5l7 7-7 7>'),
  shield(
    '<p M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z><p M8.5 12l2.5 2.5 4.5-5>',
  ),
  lock('<r 5 11 14 9 2><p M8 11V8a4 4 0 018 0v3>', join: false),
  lockSolid('<p M5 11h14v9H5zM8 11V8a4 4 0 018 0v3>'),
  pencil('<p M4 20l4-1 11-11-3-3L5 16zM14 6l3 3>'),
  check('<p M5 12l5 5 9-10>'),
  link(
    '<p M10 14a4 4 0 005 0l3-3a4 4 0 00-5-5l-1 1M14 10a4 4 0 00-5 0l-3 3a4 4 0 005 5l1-1>',
    join: false,
  ),
  list('<p M5 7h14M5 12h14M5 17h9>', join: false),
  calendar('<r 4 5 16 15 2><p M4 10h16M9 3v4M15 3v4>'),
  sliders(
    '<p M4 7h10M18 7h2M4 17h2M10 17h10><c 16 7 2><c 8 17 2>',
    join: false,
  ),
  pause('<p M8 5v14M16 5v14>'),
  replay('<p M5 12a7 7 0 107-7H8M8 2L5 5l3 3>'),
  refresh('<p M4 12a8 8 0 0114-5M20 12a8 8 0 01-14 5M18 3v4h-4M6 21v-4h4>'),
  folder(
    '<p M3 7a2 2 0 012-2h4l2 2h8a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z>',
  ),
  trash('<p M5 7h14M10 7V4h4v3M7 7l1 13h8l1-13>'),
  clapper('<p M4 5h16v14H4zM4 9h16M8 5v4M12 5v4M16 5v4>'),
  keyboard('<p M3 7h18v10H3zM7 11h.01M11 11h.01M15 11h.01M7 14h10>'),
  inbox('<p M3 13h5l1 3h6l1-3h5M5 5h14l2 8v6H3v-6z>'),
  alert('<p M12 3a9 9 0 100 18 9 9 0 000-18zM12 7v6M12 16.5v.5>'),
  close('<p M6 6l12 12M18 6L6 18>'),
  mic('<r 9 3 6 11 3><p M5 11a7 7 0 0014 0M12 18v3>'),

  /// Sauvegarde (TV33), import de fichier (TV32), Trakt (TV25).
  upload('<p M12 15V3M7 8l5-5 5 5M4 21h16>'),
  document('<p M6 3h8l4 4v14H6zM9 12h6M9 16h6>'),
  filePlain('<p M6 3h8l4 4v14H6zM14 3v5h5>'),
  linkOn(
    '<p M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1>',
  ),
  linkOff(
    '<p M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1M4 4l16 16>',
  ),

  /// Jellyfin (TV28, P07) et Regarder ensemble (TV27).
  server('<p M4 5h16v6H4zM4 13h16v6H4zM8 8h.01M8 16h.01>'),
  people(
    '<p M9 11a3 3 0 100-6 3 3 0 000 6zM3 20a6 6 0 0112 0M17 11a3 3 0 100-6M21 20a6 6 0 00-4-5.6>',
  ),
  copy('<p M8 8h12v12H8zM4 16V4h12>'),

  /// Variantes pleines du lecteur (TV07 : pause = deux barres arrondies).
  pauseSolid('<r 6 5 4 14 1><r 14 5 4 14 1>', fill: true),
  playSolid('<p M7 5l12 7-12 7z>', fill: true);

  const LumioIcon(this.spec, {this.join = true, this.fill = false});

  /// Éléments : `<p d>` chemin, `<c cx cy r>` cercle, `<r x y w h [rx]>`.
  final String spec;

  /// Jonctions et extrémités arrondies (stroke-linejoin / linecap round).
  final bool join;

  /// Forme pleine (`fill`) au lieu d'un contour.
  final bool fill;
}

/// Dessine une [LumioIcon] à [size] dp dans [color].
class LumioIconView extends StatelessWidget {
  const LumioIconView(
    this.icon, {
    super.key,
    this.size = 30,
    this.color = Colors.white,
    this.strokeWidth = 2,
  });

  final LumioIcon icon;
  final double size;
  final Color color;

  /// Épaisseur dans la grille 24 (2 dans toutes les maquettes).
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(icon, color, strokeWidth),
    ),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, this.strokeWidth);

  final LumioIcon icon;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k);
    final paint = Paint()
      ..style = icon.fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = icon.join ? StrokeCap.round : StrokeCap.butt
      ..strokeJoin = icon.join ? StrokeJoin.round : StrokeJoin.miter
      ..isAntiAlias = true;
    for (final m in RegExp(r'<(\w) ([^>]*)>').allMatches(icon.spec)) {
      final kind = m.group(1);
      final arg = m.group(2)!;
      if (kind == 'p') {
        canvas.drawPath(parseSvgPath(arg), paint);
      } else {
        final n = arg.split(' ').map(double.parse).toList();
        if (kind == 'c') {
          canvas.drawCircle(Offset(n[0], n[1]), n[2], paint);
        } else {
          final r = Rect.fromLTWH(n[0], n[1], n[2], n[3]);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              r,
              Radius.circular(n.length > 4 ? n[4] : 0),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}

/// Convertit des données de chemin SVG (M L H V C A Z, absolues et
/// relatives) en [Path]. Les drapeaux d'arc peuvent être collés (`a7 7 0 107-7`).
Path parseSvgPath(String d) {
  final path = Path();
  var i = 0;
  final n = d.length;

  bool isCmd(String c) => 'MmLlHhVvCcSsQqAaZz'.contains(c);

  void skipSep() {
    while (i < n && (d[i] == ' ' || d[i] == ',' || d[i] == '\n')) {
      i++;
    }
  }

  double num_() {
    skipSep();
    final s = i;
    if (i < n && (d[i] == '-' || d[i] == '+')) i++;
    var dot = false;
    while (i < n) {
      final c = d[i];
      if (c == '.' && !dot) {
        dot = true;
        i++;
      } else if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
        i++;
      } else {
        break;
      }
    }
    return double.parse(d.substring(s, i));
  }

  bool flag() {
    skipSep();
    final v = d[i] == '1';
    i++;
    return v;
  }

  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  var cmd = 'M';
  while (true) {
    skipSep();
    if (i >= n) break;
    if (isCmd(d[i])) {
      cmd = d[i];
      i++;
    }
    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'Z':
        path.close();
        x = sx;
        y = sy;
      case 'M':
        var nx = num_(), ny = num_();
        if (rel) {
          nx += x;
          ny += y;
        }
        path.moveTo(nx, ny);
        x = sx = nx;
        y = sy = ny;
        cmd = rel ? 'l' : 'L';
      case 'L':
        var nx = num_(), ny = num_();
        if (rel) {
          nx += x;
          ny += y;
        }
        path.lineTo(nx, ny);
        x = nx;
        y = ny;
      case 'H':
        final nx = num_() + (rel ? x : 0);
        path.lineTo(nx, y);
        x = nx;
      case 'V':
        final ny = num_() + (rel ? y : 0);
        path.lineTo(x, ny);
        y = ny;
      case 'C':
        final o = rel ? Offset(x, y) : Offset.zero;
        final x1 = num_() + o.dx, y1 = num_() + o.dy;
        final x2 = num_() + o.dx, y2 = num_() + o.dy;
        final nx = num_() + o.dx, ny = num_() + o.dy;
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        x = nx;
        y = ny;
      case 'A':
        final rx = num_(), ry = num_(), rot = num_();
        final large = flag(), sweep = flag();
        final nx = num_() + (rel ? x : 0), ny = num_() + (rel ? y : 0);
        path.arcToPoint(
          Offset(nx, ny),
          radius: Radius.elliptical(rx, ry),
          rotation: rot * math.pi / 180,
          largeArc: large,
          clockwise: sweep,
        );
        x = nx;
        y = ny;
      default:
        throw FormatException('commande SVG non gérée : $cmd');
    }
  }
  return path;
}
