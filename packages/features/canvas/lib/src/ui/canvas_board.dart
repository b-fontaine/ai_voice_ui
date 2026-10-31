import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart' show Surface, SurfaceController;
import 'package:shared_design_system/shared_design_system.dart'
    show DsSkeleton, SceneMotion, SceneMotionScope, SceneTheme;

import '../model/canvas_bloc.dart';
import '../model/canvas_state.dart';
import 'dashed_outline_painter.dart';

/// Grille des surfaces actives (FR-01). Vide tant qu'aucune surface n'existe.
///
/// La disposition est tenue par l'app, pas par l'IA (pdr-0015). Le
/// [controller] est celui que le `CanvasBloc` alimente ; il est injecté.
///
/// Chaque surface a sa cellule `surface-<id>` dès `createSurface`. Le board
/// peint lui-même le squelette tant que la phase est `skeleton` : avec genui
/// 0.10.4 le `defaultBuilder` de `Surface` ne s'affiche jamais après
/// `createSurface` (la définition existe, sans `root`). `Surface` n'est montée
/// qu'à partir de `updateComponents`.
///
/// La Barre d'actions est un **bandeau** sous la grille, de largeur égale et
/// de hauteur [actionsBandHeight], réservée dès la première surface : la grille
/// 2 × 2 et le `State` de ses quatre cellules ne changent pas quand `actions`
/// arrive (A1). Toutes les cellules ont le même parent : le `State` des
/// moteurs de rendu survit aussi au passage de 2 × 2 à 3 × 2 (A7).
///
/// Périmètre de reconstruction (NFR-04, P6) : le board ne se reconstruit que
/// quand la liste des surfaces change. Chaque cellule suit la phase de sa seule
/// surface, et lit la surbrillance sans reconstruire ses voisines. Chaque
/// cellule porte un `RepaintBoundary` à place fixe : une cellule inchangée n'est
/// pas repeinte quand sa voisine l'est.
///
/// Emplacement **déterministe** (A7a) : les surfaces du contrat à leur rang
/// (kpi, trend, reviews, checklist), puis les surfaces inconnues dans leur
/// ordre d'arrivée. Pas de défilement, pas de mise à l'échelle.
class CanvasBoard extends StatefulWidget {
  const CanvasBoard({
    super.key,
    required this.controller,
    this.highlight = const _NoHighlight(),
  });

  /// Hauteur réservée au bandeau de la Barre d'actions.
  static const double actionsBandHeight = 72;

  final SurfaceController controller;

  /// Surface du message en cours du panneau du protocole (D2) : elle reçoit un
  /// contour pointillé `highlight-<id>` si elle est présente dans le canevas
  /// (un message refusé n'a pas de surface, donc pas de contour).
  ///
  /// L'écouteur appartient à l'appelant (la page le crée et le libère) : un
  /// changement ne reconstruit que l'ancienne et la nouvelle cellule.
  final ValueListenable<String?> highlight;

  @override
  State<CanvasBoard> createState() => _CanvasBoardState();

  /// Rang d'emplacement des surfaces du contrat, dans l'ordre des composants.
  static final List<String> _contractOrder = <String>[
    for (final String component in GenesisContract.components)
      ?GenesisContract.surfaceOf(component),
  ];

  /// Surface du bandeau (Barre d'actions), hors de la grille (A1, pdr-0065 D7).
  static final String _bandSurface = GenesisContract.surfaceOf('ActionBar')!;

  /// Surfaces de la grille : celles du contrat dans l'ordre du contrat, puis
  /// les autres dans leur ordre d'arrivée ; le bandeau n'en fait pas partie.
  static List<String> _inSlotOrder(List<String> arrival) => <String>[
    for (final String id in _contractOrder)
      if (id != _bandSurface && arrival.contains(id)) id,
    for (final String id in arrival)
      if (id != _bandSurface && !_contractOrder.contains(id)) id,
  ];

  /// Grille tenue par l'app (pdr-0015) : une colonne pour une surface, 2 × 2
  /// jusqu'à quatre, 3 × 2 pour cinq ou six (A7a du plan 007).
  static int _columnsFor(int count) => switch (count) {
    <= 1 => 1,
    <= 4 => 2,
    _ => 3,
  };
}

class _CanvasBoardState extends State<CanvasBoard> {
  // Une cellule par surface, la même instance d'un rendu à l'autre : le board
  // qui se reconstruit (arrivée d'une surface) ne reconstruit pas les cellules
  // voisines (`Widget.==` n'est pas redéfinissable, l'identité suffit).
  final Map<String, _SurfaceCell> _cells = <String, _SurfaceCell>{};

  _SurfaceCell _cell(String id) => _cells.putIfAbsent(
    id,
    () => _SurfaceCell(
      id: id,
      controller: widget.controller,
      highlight: widget.highlight,
      restored: _firstBuild,
    ),
  );

  // Vrai jusqu'à la fin du premier rendu : les cellules créées alors sont des
  // surfaces restaurées, qui n'apparaissent pas en fondu.
  bool _firstBuild = true;

  @override
  void didUpdateWidget(CanvasBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.highlight != widget.highlight) {
      _cells.clear();
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CanvasBloc, CanvasState>(
    buildWhen: (CanvasState previous, CanvasState next) =>
        !listEquals(previous.surfaceIds, next.surfaceIds),
    builder: (BuildContext context, CanvasState state) {
      // Une surface supprimée perd sa cellule : si elle revient, elle arrive.
      _cells.removeWhere((String id, _) => !state.surfaceIds.contains(id));
      final List<String> ids = CanvasBoard._inSlotOrder(state.surfaceIds);
      final int columns = CanvasBoard._columnsFor(ids.length);
      // Le bandeau est réservé dès la première surface : les cellules de la
      // grille ne bougent pas quand `actions` arrive (A1, S-02).
      //
      // Parent unique (A7, 012) : toutes les cellules sont des enfants
      // directs d'un même `CustomMultiChildLayout`, repérés par leur clé. Un
      // `Column` de `Row` recréerait les `State` des moteurs de rendu au
      // passage de 2 × 2 à 3 × 2 (une cellule change de parent). Le
      // `CustomMultiChildLayout` plutôt qu'un `Stack` + `Positioned` : la
      // géométrie (colonnes, rangées, bandeau) est calculée en un seul
      // endroit, le délégué, sans recalcul dans `build`.
      final bool hasBand = state.surfaceIds.isNotEmpty;
      final Widget layout = CustomMultiChildLayout(
        delegate: _BoardLayoutDelegate(
          slots: ids,
          columns: columns,
          bandId: hasBand ? CanvasBoard._bandSurface : null,
        ),
        children: <Widget>[
          for (final String id in ids)
            LayoutId(
              key: ValueKey<String>('slot-$id'),
              id: id,
              child: _cell(id),
            ),
          if (hasBand)
            LayoutId(
              key: ValueKey<String>('slot-$CanvasBoard._bandSurface'),
              id: CanvasBoard._bandSurface,
              child: state.surfaceIds.contains(CanvasBoard._bandSurface)
                  ? _cell(CanvasBoard._bandSurface)
                  : const SizedBox.shrink(),
            ),
        ],
      );
      _firstBuild = false;
      return layout;
    },
  );
}

/// Cellule d'une surface : ne se reconstruit que si la phase de **sa** surface
/// change.
///
/// Le board en garde une instance par surface (voir `_CanvasBoardState`).
class _SurfaceCell extends StatelessWidget {
  const _SurfaceCell({
    required this.id,
    required this.controller,
    required this.highlight,
    required this.restored,
  });

  final String id;
  final SurfaceController controller;
  final ValueListenable<String?> highlight;

  /// Surface présente dès le premier rendu du canevas (voir
  /// `_SurfaceAppearance`).
  final bool restored;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<CanvasBloc, CanvasState, SurfacePhase?>(
        selector: (CanvasState state) => state.phaseOf(id),
        builder: (BuildContext context, SurfacePhase? phase) {
          if (phase == null) return const SizedBox.shrink();
          return KeyedSubtree(
            key: ValueKey<String>('surface-$id'),
            // Le contenu (`RepaintBoundary` à place fixe, premier enfant) ne se
            // remonte pas et ses peintures restent isolées : le `ClipRect`
            // contient la translation d'apparition, et le contour pointillé
            // est posé au-dessus du `RepaintBoundary`, sans le repeindre.
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                RepaintBoundary(
                  child: ClipRect(
                    child: _SurfaceAppearance(
                      id: id,
                      controller: controller,
                      phase: phase,
                      restored: restored,
                    ),
                  ),
                ),
                _HighlightOutline(id: id, highlight: highlight),
              ],
            ),
          );
        },
      );
}

/// Passage du squelette aux composants d'une surface (D-06, pdr-0075 D3).
///
/// Un seul `AnimationController` par surface. Tant que la phase est
/// `skeleton`, le squelette est seul à l'écran. Au passage aux composants, le
/// squelette part aussitôt et la `Surface` est montée une fois pour toutes
/// (son `State` n'est jamais recréé) : elle apparaît en fondu en se décalant de
/// [SceneMotion.translation] vers sa place. La durée vient de
/// [SceneMotionScope] : nulle si les animations sont coupées (jamais de
/// `TickerMode`), divisée par la vitesse du rejeu sinon.
///
/// Une surface présente dès le premier rendu du canevas (`restored`,
/// restauration) est directement pleinement visible. Une surface qui arrive
/// ensuite apparaît en fondu, même si sa phase est déjà `components` ou `data`
/// (le rejeu reconstruit une surface d'un seul coup).
class _SurfaceAppearance extends StatefulWidget {
  const _SurfaceAppearance({
    required this.id,
    required this.controller,
    required this.phase,
    required this.restored,
  });

  final String id;
  final SurfaceController controller;
  final SurfacePhase phase;

  /// Surface déjà présente au premier rendu du canevas : pas d'apparition.
  final bool restored;

  @override
  State<_SurfaceAppearance> createState() => _SurfaceAppearanceState();
}

class _SurfaceAppearanceState extends State<_SurfaceAppearance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: SceneMotion.appear,
    value: widget.restored && widget.phase != SurfacePhase.skeleton ? 1 : 0,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Surface qui arrive déjà avec ses composants : le fondu part au montage.
    if (_started) return;
    _started = true;
    if (!widget.restored && widget.phase != SurfacePhase.skeleton) _play();
  }

  @override
  void didUpdateWidget(_SurfaceAppearance oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool wasSkeleton = oldWidget.phase == SurfacePhase.skeleton;
    final bool isSkeleton = widget.phase == SurfacePhase.skeleton;
    if (wasSkeleton == isSkeleton) return;
    if (isSkeleton) {
      _animation.value = 0;
    } else {
      _play();
    }
  }

  void _play() {
    SceneMotionScope.play(context, _animation, SceneMotion.appear);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phase == SurfacePhase.skeleton) {
      return DsSkeleton(key: ValueKey<String>('skeleton-${widget.id}'));
    }
    return AnimatedBuilder(
      animation: _animation,
      // La `Surface` est construite une fois : seul l'habillage suit l'image.
      child: Surface(surfaceContext: widget.controller.contextFor(widget.id)),
      builder: (BuildContext context, Widget? surface) {
        final double t = SceneMotion.curve.transform(_animation.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, SceneMotion.translation * (1 - t)),
            child: surface,
          ),
        );
      },
    );
  }
}

/// Contour pointillé `highlight-<id>`, posé quand [highlight] vaut [id].
///
/// N'écoute que la surbrillance et ne se reconstruit que quand cette cellule
/// gagne ou perd le contour.
class _HighlightOutline extends StatefulWidget {
  const _HighlightOutline({required this.id, required this.highlight});

  final String id;
  final ValueListenable<String?> highlight;

  @override
  State<_HighlightOutline> createState() => _HighlightOutlineState();
}

class _HighlightOutlineState extends State<_HighlightOutline> {
  late bool _on = widget.highlight.value == widget.id;

  @override
  void initState() {
    super.initState();
    widget.highlight.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_HighlightOutline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight != widget.highlight) {
      oldWidget.highlight.removeListener(_onChanged);
      widget.highlight.addListener(_onChanged);
    }
    _on = widget.highlight.value == widget.id;
  }

  @override
  void dispose() {
    widget.highlight.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final bool on = widget.highlight.value == widget.id;
    if (on != _on) setState(() => _on = on);
  }

  @override
  Widget build(BuildContext context) => _on
      ? IgnorePointer(
          child: CustomPaint(
            key: ValueKey<String>('highlight-${widget.id}'),
            painter: DashedOutlinePainter(
              color: SceneTheme.of(context).highlightOutline,
            ),
          ),
        )
      : const SizedBox.shrink();
}

/// Aucune surbrillance : valeur toujours `null`, rien à écouter.
class _NoHighlight implements ValueListenable<String?> {
  const _NoHighlight();

  @override
  String? get value => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Géométrie de la grille : [slots] dans l'ordre de lecture sur [columns]
/// colonnes de largeur égale, rangées de hauteur égale, puis le bandeau de
/// [CanvasBoard.actionsBandHeight] sur toute la largeur s'il existe.
class _BoardLayoutDelegate extends MultiChildLayoutDelegate {
  _BoardLayoutDelegate({
    required this.slots,
    required this.columns,
    required this.bandId,
  });

  final List<String> slots;
  final int columns;

  /// Identifiant du bandeau ; `null` : pas de bandeau (aucune surface).
  final String? bandId;

  @override
  void performLayout(Size size) {
    final double bandHeight = bandId != null
        ? CanvasBoard.actionsBandHeight.clamp(0, size.height)
        : 0;
    final double gridHeight = size.height - bandHeight;
    final int rows = slots.isEmpty
        ? 1
        : (slots.length + columns - 1) ~/ columns;
    final double cellWidth = size.width / columns;
    final double cellHeight = gridHeight / rows;
    for (int i = 0; i < slots.length; i++) {
      final Offset origin = Offset(
        (i % columns) * cellWidth,
        (i ~/ columns) * cellHeight,
      );
      layoutChild(slots[i], BoxConstraints.tight(Size(cellWidth, cellHeight)));
      positionChild(slots[i], origin);
    }
    final String? band = bandId;
    if (band != null && hasChild(band)) {
      layoutChild(band, BoxConstraints.tight(Size(size.width, bandHeight)));
      positionChild(band, Offset(0, gridHeight));
    }
  }

  @override
  bool shouldRelayout(_BoardLayoutDelegate oldDelegate) =>
      columns != oldDelegate.columns ||
      bandId != oldDelegate.bandId ||
      !listEquals(slots, oldDelegate.slots);
}
