import 'package:a2ui_core/a2ui_core.dart' show MessageProcessor, SurfaceModel;
import 'package:a2ui_flutter/a2ui_flutter.dart'
    show A2uiSurface, ComponentImplementation;
import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show
        DsGenFrame,
        DsRise,
        DsSkeleton,
        ScenePanel,
        ScenePanelDecoration,
        SceneRadius,
        SceneTheme;

import '../model/canvas_bloc.dart';
import '../model/canvas_state.dart';
import 'dashed_outline_painter.dart';
import 'generation_target.dart';
import 'surface_restored.dart';

/// Grille des surfaces actives (FR-01). Vide tant qu'aucune surface n'existe.
///
/// La disposition est tenue par l'app, pas par l'IA (pdr-0015). Le
/// [controller] est celui que le `CanvasBloc` alimente ; il est injecté.
///
/// Chaque surface a sa cellule `surface-<id>` dès `createSurface`. Le board
/// peint lui-même le squelette tant que la phase est `skeleton` : `A2uiSurface`
/// ne peint rien tant que la surface n'a pas de `root`. `A2uiSurface` n'est
/// montée qu'à partir de `updateComponents`.
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
    this.generation = const _NoGeneration(),
  });

  /// Hauteur réservée au bandeau de la Barre d'actions.
  static const double actionsBandHeight = 72;

  final MessageProcessor<ComponentImplementation> controller;

  /// Surface du message en cours du panneau du protocole (D2) : elle reçoit un
  /// contour pointillé `highlight-<id>` si elle est présente dans le canevas
  /// (un message refusé n'a pas de surface, donc pas de contour).
  ///
  /// L'écouteur appartient à l'appelant (la page le crée et le libère) : un
  /// changement ne reconstruit que l'ancienne et la nouvelle cellule.
  final ValueListenable<String?> highlight;

  /// Surface en cours de génération (la dernière créée) et son agent : la page
  /// l'alimente depuis l'enveloppe validée, comme [highlight] (019 T32a,
  /// pdr-0088 F11). Le cadre de génération (`DsGenFrame`) n'est posé que sur
  /// cette surface, tant que sa phase est `skeleton` ou `components` ; il
  /// s'achève à `data`. Une surface complète qui reçoit une mutation (acte 2)
  /// ou une surface restaurée n'en reçoit jamais.
  ///
  /// L'écouteur appartient à l'appelant ; chaque cellule n'écoute que pour
  /// elle-même.
  final ValueListenable<GenerationTarget?> generation;

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
      generation: widget.generation,
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
        oldWidget.highlight != widget.highlight ||
        oldWidget.generation != widget.generation) {
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
    required this.generation,
    required this.restored,
  });

  final String id;
  final MessageProcessor<ComponentImplementation> controller;
  final ValueListenable<String?> highlight;
  final ValueListenable<GenerationTarget?> generation;

  /// Surface présente dès le premier rendu du canevas (voir
  /// `_SurfaceAppearance`).
  final bool restored;

  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<CanvasBloc, CanvasState, SurfacePhase?>(
    selector: (CanvasState state) => state.phaseOf(id),
    builder: (BuildContext context, SurfacePhase? phase) {
      if (phase == null) return const SizedBox.shrink();
      return KeyedSubtree(
        key: ValueKey<String>('surface-$id'),
        // Couche panneau (pdr-0084 U9) : la décoration est une sœur
        // statique sous le contenu, jamais son enveloppe ni dans le
        // `ClipRect` (son ombre ne serait plus rognée). Elle est en retrait
        // de [ScenePanel.cellInset] : les cellules sont jointives, deux panneaux
        // voisins gardent 8 px visibles, et aucun rectangle de cellule ne
        // change. Le contenu (`RepaintBoundary` à place fixe) ne se remonte
        // pas et ses peintures restent isolées : le `ClipRect` contient la
        // translation d'apparition, et le contour pointillé est posé
        // au-dessus, sans repeindre ni le contenu ni la décoration. Le cadre
        // de génération est son frère, hors du `ClipRect` et sous le
        // contour pointillé : il couvre la cellule et peint dans le même
        // retrait.
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned.fill(
              left: ScenePanel.cellInset,
              top: ScenePanel.cellInset,
              right: ScenePanel.cellInset,
              bottom: ScenePanel.cellInset,
              child: ScenePanelDecoration(),
            ),
            RepaintBoundary(
              key: ValueKey<String>('surface-content-$id'),
              child: ClipRect(
                child: _SurfaceAppearance(
                  id: id,
                  controller: controller,
                  phase: phase,
                  restored: restored,
                ),
              ),
            ),
            Positioned.fill(
              child: _GenerationFrameSlot(
                id: id,
                phase: phase,
                restored: restored,
                generation: generation,
              ),
            ),
            Positioned.fill(
              left: ScenePanel.cellInset,
              top: ScenePanel.cellInset,
              right: ScenePanel.cellInset,
              bottom: ScenePanel.cellInset,
              child: _HighlightOutline(id: id, highlight: highlight),
            ),
          ],
        ),
      );
    },
  );
}

/// Passage du squelette aux composants d'une surface (D-06, pdr-0075 D3).
///
/// Tant que la phase est `skeleton`, le squelette est seul à l'écran. Au
/// passage aux composants, le squelette part aussitôt et l'`A2uiSurface` est
/// montée une fois pour toutes dans un [DsRise] (son `State` n'est jamais
/// recréé) : elle apparaît en fondu, de flou et de 10 px
/// vers sa place (`gc-rise`, pdr-0087 / pdr-0088 F5). La durée vient de
/// `SceneMotionScope` : nulle si les animations sont coupées (jamais de
/// `TickerMode`), divisée par la vitesse du rejeu sinon.
///
/// Une surface présente dès le premier rendu du canevas (`restored`,
/// restauration) est directement en place. Une surface qui arrive ensuite
/// apparaît, même si sa phase est déjà `components` ou `data` (le rejeu
/// reconstruit une surface d'un seul coup).
class _SurfaceAppearance extends StatefulWidget {
  const _SurfaceAppearance({
    required this.id,
    required this.controller,
    required this.phase,
    required this.restored,
  });

  final String id;
  final MessageProcessor<ComponentImplementation> controller;
  final SurfacePhase phase;

  /// Surface déjà présente au premier rendu du canevas : pas d'apparition.
  final bool restored;

  @override
  State<_SurfaceAppearance> createState() => _SurfaceAppearanceState();
}

class _SurfaceAppearanceState extends State<_SurfaceAppearance> {
  /// Le premier [DsRise] de la cellule est déjà en place si la surface était
  /// restaurée avec ses composants ; tout [DsRise] suivant joue.
  late bool _settled = widget.restored && widget.phase != SurfacePhase.skeleton;

  @override
  void didUpdateWidget(_SurfaceAppearance oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Retour au squelette : le prochain [DsRise] joue.
    if (widget.phase == SurfacePhase.skeleton) _settled = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phase == SurfacePhase.skeleton) {
      return DsSkeleton(key: ValueKey<String>('skeleton-${widget.id}'));
    }
    final SurfaceModel<ComponentImplementation>? surface = widget
        .controller
        .model
        .getSurface(widget.id);
    return DsRise(
      settled: _settled,
      // L'`A2uiSurface` est construite une fois : seul l'habillage suit
      // l'image. Une surface que le moteur a refusée n'a pas de modèle : la
      // cellule reste vide.
      child: SurfaceRestored(
        restored: _settled,
        child: surface == null
            ? const SizedBox.shrink()
            : A2uiSurface(surface: surface),
      ),
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
              radius: SceneRadius.lg,
            ),
          ),
        )
      : const SizedBox.shrink();
}

/// Avancement du cadre de génération d'une cellule.
enum _FramePhase { off, running, done }

/// Emplacement du cadre de génération `generation-frame-<id>` d'une cellule.
///
/// Le cadre naît quand cette surface devient la cible du port **alors qu'elle
/// n'est pas complète** (`skeleton` ou `components`), ou à sa création si elle
/// l'est déjà au montage ; il passe à `done` quand la phase atteint `data`, et
/// il est retiré quand `DsGenFrame` a fini (dernier tour puis fondu, aussitôt
/// sous animations coupées). Si une autre surface devient la cible, il est
/// retiré sans fondu : un seul cadre est actif. Une surface déjà complète
/// quand elle devient cible (rejeu positionné), une surface restaurée, ou une
/// mutation de l'acte 2 n'ouvrent aucun cadre : la phase ne recule jamais.
///
/// N'écoute que le port : seule cette cellule se reconstruit.
class _GenerationFrameSlot extends StatefulWidget {
  const _GenerationFrameSlot({
    required this.id,
    required this.phase,
    required this.restored,
    required this.generation,
  });

  final String id;
  final SurfacePhase phase;
  final bool restored;
  final ValueListenable<GenerationTarget?> generation;

  @override
  State<_GenerationFrameSlot> createState() => _GenerationFrameSlotState();
}

class _GenerationFrameSlotState extends State<_GenerationFrameSlot> {
  late _FramePhase _frame = _shouldOpen ? _FramePhase.running : _FramePhase.off;

  bool get _isTarget => widget.generation.value?.surfaceId == widget.id;

  bool get _shouldOpen =>
      _isTarget && !widget.restored && widget.phase != SurfacePhase.data;

  @override
  void initState() {
    super.initState();
    widget.generation.addListener(_onTargetChanged);
  }

  @override
  void didUpdateWidget(_GenerationFrameSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) {
      oldWidget.generation.removeListener(_onTargetChanged);
      widget.generation.addListener(_onTargetChanged);
    }
    if (_frame == _FramePhase.running && widget.phase == SurfacePhase.data) {
      _frame = _FramePhase.done;
    }
  }

  @override
  void dispose() {
    widget.generation.removeListener(_onTargetChanged);
    super.dispose();
  }

  void _onTargetChanged() {
    if (!_isTarget) {
      if (_frame != _FramePhase.off) setState(() => _frame = _FramePhase.off);
    } else if (_frame == _FramePhase.off) {
      if (_shouldOpen) setState(() => _frame = _FramePhase.running);
    } else {
      // Même cible, autre agent : l'étiquette change.
      setState(() {});
    }
  }

  void _onFinished() {
    if (_frame == _FramePhase.done) setState(() => _frame = _FramePhase.off);
  }

  @override
  Widget build(BuildContext context) => _frame == _FramePhase.off
      ? const SizedBox.shrink()
      : DsGenFrame(
          surfaceId: widget.id,
          agent: widget.generation.value?.agent,
          done: _frame == _FramePhase.done,
          onFinished: _onFinished,
          inset: ScenePanel.cellInset,
        );
}

/// Aucune génération en cours : valeur toujours `null`, rien à écouter.
class _NoGeneration implements ValueListenable<GenerationTarget?> {
  const _NoGeneration();

  @override
  GenerationTarget? get value => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
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
