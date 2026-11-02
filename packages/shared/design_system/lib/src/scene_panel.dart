import 'package:flutter/material.dart';

import 'scene_radius.dart';
import 'scene_shadow.dart';
import 'scene_space.dart';
import 'scene_theme.dart';

/// Longueur des traits des coins HUD (`.gc-panel::before`, pdr-0084 U9).
const double _hudCornerLength = 10;

/// Épaisseur des traits des coins HUD.
const double _hudCornerThickness = 1;

/// Distance des coins HUD au bord du panneau.
const double _hudCornerInset = 8;

/// Opacité des coins HUD.
const double _hudCornerOpacity = 0.8;

/// Épaisseur de la bordure et du filet du haut.
const double _hairline = 1;

/// Décoration de panneau du design system (pdr-0084 U9) : dégradé vertical
/// `panelTop` vers `surface`, bordure `line`, rayon `SceneRadius.lg`, ombre
/// `SceneShadow.panel`, filet `panelHighlight` en haut et coins HUD
/// `lineStrong`.
///
/// Couche décorative sans enfant, remplie par son parent et statique : elle a
/// son propre `RepaintBoundary` et ne se repeint jamais quand le contenu
/// bouge. Aucun `Clip` ne l'entoure, pour que l'ombre ne soit pas rognée.
/// [glow] ajoute des ombres (par exemple `SceneShadow.glowSignal` pour une
/// zone en cours de génération) ; il n'y a pas de halo permanent.
class ScenePanelDecoration extends StatelessWidget {
  const ScenePanelDecoration({super.key, this.glow});

  final List<BoxShadow>? glow;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[theme.panelTop, theme.surface],
          ),
          border: Border.all(color: theme.line, width: _hairline),
          borderRadius: SceneRadius.borderLg,
          boxShadow: <BoxShadow>[...SceneShadow.panel, ...?glow],
        ),
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _PanelDetailPainter(
              highlight: theme.panelHighlight,
              corner: theme.lineStrong.withValues(alpha: _hudCornerOpacity),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filet du haut et coins HUD, peints par-dessus le fond du panneau.
class _PanelDetailPainter extends CustomPainter {
  const _PanelDetailPainter({required this.highlight, required this.corner});

  final Color highlight;
  final Color corner;

  @override
  void paint(Canvas canvas, Size size) {
    // Filet : croissant de 1 px en haut, dans la bordure (ombre `inset 0 1px`).
    final RRect inner = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(SceneRadius.lg),
    ).deflate(_hairline);
    final Path crescent = Path.combine(
      PathOperation.difference,
      Path()..addRRect(inner),
      Path()..addRRect(inner.shift(const Offset(0, _hairline))),
    );
    canvas.drawPath(crescent, Paint()..color = highlight);

    // Coins HUD : un L en haut à gauche, un L en bas à droite.
    const double a = _hudCornerInset;
    const double len = _hudCornerLength;
    const double t = _hudCornerThickness;
    final double right = size.width - a;
    final double bottom = size.height - a;
    canvas
      ..drawRect(const Rect.fromLTWH(a, a, len, t), Paint()..color = corner)
      ..drawRect(const Rect.fromLTWH(a, a, t, len), Paint()..color = corner)
      ..drawRect(
        Rect.fromLTRB(right - len, bottom - t, right, bottom),
        Paint()..color = corner,
      )
      ..drawRect(
        Rect.fromLTRB(right - t, bottom - len, right, bottom),
        Paint()..color = corner,
      );
  }

  @override
  bool shouldRepaint(_PanelDetailPainter old) =>
      old.highlight != highlight || old.corner != corner;
}

/// Panneau pratique : [ScenePanelDecoration] en dessous, [child] au-dessus.
///
/// La décoration est une couche sœur du contenu, jamais son enveloppe : elle
/// est retirée de [inset] sur chaque bord (les cellules d'une grille sont
/// jointives ; 4 px de retrait laissent 8 px visibles entre deux panneaux), et
/// le [child] est placé à [padding] du bord de la cellule. L'enfant mesure
/// donc largeur − padding.horizontal et hauteur − padding.vertical ; la
/// décoration, largeur − 2 × inset.
class ScenePanel extends StatelessWidget {
  const ScenePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SceneSpace.space4),
    this.inset = 4,
    this.glow,
  });

  final Widget child;

  /// Marge entre le bord de la cellule et le contenu.
  final EdgeInsetsGeometry padding;

  /// Retrait de la décoration par rapport au bord de la cellule.
  final double inset;

  /// Ombres ajoutées pour une zone active (`SceneShadow.glowSignal`).
  final List<BoxShadow>? glow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        Positioned.fill(
          left: inset,
          top: inset,
          right: inset,
          bottom: inset,
          child: ScenePanelDecoration(glow: glow),
        ),
        Padding(padding: padding, child: child),
      ],
    );
  }
}
