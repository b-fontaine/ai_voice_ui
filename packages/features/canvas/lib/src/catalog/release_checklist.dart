import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import '../ui/surface_restored.dart';
import 'bound_item.dart';
import 'checklist_grid.dart';
import 'checklist_head.dart';
import 'checklist_model.dart';
import 'text_metrics.dart';

/// `ReleaseChecklist` : tableau go/no-go (`gc-check`), verdict, compteur et
/// statut de décision.
///
/// Le code `level` pilote la couleur des puces, le liseré des lignes
/// bloquantes et le compteur ; les libellés sont affichés tels quels (jamais
/// interprétés).
final CatalogItem releaseChecklistItem = boundCatalogItem<ChecklistData>(
  name: 'ReleaseChecklist',
  description: 'Checklist go/no-go liée à /checklist.',
  parse: ChecklistData.tryParse,
  build: (BuildContext context, ChecklistData c, String _) =>
      _ChecklistView(checklist: c),
);

/// Glissement de départ d'une ligne (`gc-row` : `translateX(-12px)`).
const double _rowShift = 12;

/// Nombre de lignes au-delà duquel le décalage de la cascade ne grandit plus.
const int _cascadeCap = 8;

/// Durée d'une cascade de [rows] lignes : une ligne s'écrit en
/// [SceneMotion.row], la suivante [SceneMotion.stagger] plus tard.
Duration _cascadeDuration(int rows) =>
    SceneMotion.row +
    SceneMotion.stagger * ((rows > _cascadeCap ? _cascadeCap : rows) - 1);

class _ChecklistView extends StatefulWidget {
  const _ChecklistView({required this.checklist});

  final ChecklistData checklist;

  @override
  State<_ChecklistView> createState() => _ChecklistViewState();
}

/// Joue la cascade des lignes une fois, au premier `data` de la surface
/// (pdr-0088 F13) : un seul contrôleur pour toutes les lignes. Une mise à jour
/// de valeur ou de statut se fait sur place, sans nouvelle cascade.
class _ChecklistViewState extends State<_ChecklistView>
    with
        SingleTickerProviderStateMixin<_ChecklistView>,
        SceneOneShot<_ChecklistView> {
  late final bool _restored = SurfaceRestored.of(context);
  bool _started = false;

  @override
  Duration get oneShotBase => _cascadeDuration(widget.checklist.items.length);

  // Surface restaurée : l'état final, sans cascade.
  @override
  double get oneShotInitialValue => _restored ? 1 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_restored) playOneShot();
  }

  @override
  Widget build(BuildContext context) {
    final ChecklistData checklist = widget.checklist;
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChecklistHead(checklist: checklist),
          Expanded(
            child: _Table(items: checklist.items, cascade: oneShot),
          ),
        ],
      ),
    );
  }
}

/// Tableau des critères : jamais de troncature muette, les textes passent à la
/// ligne dans leur colonne. Quand tous les critères ne tiennent pas, les
/// bloquants (puis les à risque) sont gardés en priorité, dans leur ordre
/// d'origine, et la dernière ligne annonce « + N autres critères ».
class _Table extends StatelessWidget {
  const _Table({required this.items, required this.cascade});

  final List<ChecklistItem> items;

  /// Avancement de la cascade (0 à 1).
  final Animation<double> cascade;

  static int _priority(ChecklistItem item) => switch (item.level) {
    SceneStatus.blocking => 0,
    SceneStatus.risk => 1,
    _ => 2,
  };

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ChecklistGrid grid = ChecklistGrid.measure(
          context,
          theme,
          items,
          constraints.maxWidth,
        );
        final double moreHeight =
            lineHeightOf(theme.body) + ChecklistGrid.rowGap;
        final double budget = constraints.hasBoundedHeight
            ? constraints.maxHeight - grid.headHeight
            : double.infinity;

        final double total = grid.heights.fold(
          0,
          (double a, double b) => a + b,
        );
        final List<int> kept = List<int>.generate(items.length, (int i) => i);
        bool showMore = false;
        if (total > budget) {
          // Ordre de priorité (niveau, puis rang d'origine) : on garde les
          // premiers critères qui tiennent avec la ligne « + N autres ».
          kept.sort((int a, int b) {
            final int byLevel = _priority(items[a])
                .compareTo(_priority(items[b]));
            return byLevel != 0 ? byLevel : a.compareTo(b);
          });
          double used = moreHeight;
          int count = 0;
          while (count < kept.length &&
              used + grid.heights[kept[count]] <= budget) {
            used += grid.heights[kept[count]];
            count++;
          }
          kept
            ..removeRange(count, kept.length)
            ..sort();
          // Si même la ligne d'annonce ne tient pas, rien à afficher.
          showMore = moreHeight <= budget;
        }
        return RepaintBoundary(
          child: SizedBox(
            key: const Key('checklist-table'),
            width: constraints.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                grid.head(theme),
                for (final int i in kept)
                  _RowReveal(
                    animation: cascade,
                    index: i,
                    count: items.length,
                    child: grid.row(theme, i, items[i]),
                  ),
                if (showMore)
                  MoreLine(
                    textKey: const Key('checklist-more'),
                    text: '+ ${items.length - kept.length} autres critères',
                    height: moreHeight,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Apparition d'une ligne (`gc-row`) : fondu et glissement de [_rowShift] px
/// sur X, décalés de [SceneMotion.stagger] par rang (plafonné) sur la cascade
/// commune [animation].
class _RowReveal extends StatelessWidget {
  const _RowReveal({
    required this.animation,
    required this.index,
    required this.count,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double total = _cascadeDuration(count).inMicroseconds.toDouble();
    final int rank = index < _cascadeCap ? index : _cascadeCap - 1;
    final double begin = SceneMotion.stagger.inMicroseconds * rank / total;
    final double end = begin + SceneMotion.row.inMicroseconds / total;
    return DsReveal(
      animation: animation,
      from: const Offset(-_rowShift, 0),
      interval: Interval(begin, end > 1 ? 1 : end, curve: SceneMotion.curve),
      child: child,
    );
  }
}
