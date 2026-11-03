import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import 'blocking_summary.dart';
import 'bound_item.dart';
import 'text_metrics.dart';

/// `ReleaseChecklist` : tableau go/no-go (`gc-check`), verdict, compteur et
/// statut de décision.
///
/// Le code `level` pilote la couleur des puces, le liseré des lignes
/// bloquantes et le compteur ; les libellés sont affichés tels quels (jamais
/// interprétés).
final CatalogItem releaseChecklistItem = boundCatalogItem<_Checklist>(
  name: 'ReleaseChecklist',
  description: 'Checklist go/no-go liée à /checklist.',
  parse: _Checklist.tryParse,
  build: (BuildContext context, _Checklist c, String _) =>
      _ChecklistView(checklist: c),
);

class _Item {
  const _Item(
    this.label,
    this.threshold,
    this.value,
    this.level,
    this.levelLabel,
  );

  final String label;
  final String threshold;
  final String value;
  final SceneStatus level;
  final String levelLabel;
}

class _Checklist {
  const _Checklist({
    required this.title,
    required this.items,
    required this.recommendationLevel,
    required this.recommendationLabel,
    required this.decisionStatus,
  });

  final String title;
  final List<_Item> items;
  final SceneStatus recommendationLevel;
  final String recommendationLabel;
  final String decisionStatus;

  static _Checklist? tryParse(Object raw) {
    if (raw is! Map) return null;
    final String? title = readString(raw, 'title');
    final String? decision = readString(raw, 'decisionStatus');
    final List<Map<Object?, Object?>>? rawItems = readMaps(raw, 'items');
    final Object? reco = raw['recommendation'];
    if (title == null || decision == null || rawItems == null || reco is! Map) {
      return null;
    }
    final SceneStatus? recoLevel = SceneStatus.fromCode(
      readString(reco, 'level'),
    );
    final String? recoLabel = readString(reco, 'label');
    if (recoLevel == null || recoLabel == null) return null;
    final List<_Item> items = <_Item>[];
    for (final Map<Object?, Object?> i in rawItems) {
      final String? label = readString(i, 'label');
      final String? threshold = readString(i, 'threshold');
      final String? value = readString(i, 'value');
      final SceneStatus? level = SceneStatus.fromCode(readString(i, 'level'));
      final String? levelLabel = readString(i, 'levelLabel');
      if (label == null ||
          threshold == null ||
          value == null ||
          level == null ||
          levelLabel == null) {
        return null;
      }
      items.add(_Item(label, threshold, value, level, levelLabel));
    }
    return _Checklist(
      title: title,
      items: items,
      recommendationLevel: recoLevel,
      recommendationLabel: recoLabel,
      decisionStatus: decision,
    );
  }
}

/// Statut de décision en pastille, jamais tronqué ; un changement de valeur
/// est mis en avant par une brève transition.
class _DecisionStatus extends StatelessWidget {
  const _DecisionStatus({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    key: const Key('decision-status'),
    duration: SceneMotionScope.of(context).durationFor(SceneMotion.status),
    child: DsStatusChip(
      key: ValueKey<String>(status),
      status: null,
      label: status,
    ),
  );
}

/// Titre de la colonne des critères.
const String _criterionHeading = 'Critère';

/// Titre de la colonne des seuils.
const String _thresholdHeading = 'Seuil';

/// Titre de la colonne des valeurs : neutre, sans version (la valeur de
/// chaque ligne dit déjà de quelle version elle parle, pdr-0088 P1).
const String _valueHeading = 'Valeur';

/// Espace entre le titre, le verdict et la puce de décision (`.gc-verdict`).
const double _headerGap = 14;

/// Espace entre deux lignes du tableau (`border-spacing: 0 6px`).
const double _rowGap = 6;

/// Remplissage horizontal d'une cellule (`padding: 11px 12px`).
const double _cellPadH = 12;

/// Remplissage vertical d'une cellule de ligne.
const double _cellPadV = 11;

/// Bordure d'une ligne (1 px, couleur `line`).
const double _rowBorder = 1;

/// Largeur du liseré des lignes bloquantes (`inset 3px 0 0 nogo`).
const double _edgeWidth = 3;

/// Sous-marge de la ligne d'en-têtes (`padding: 0 12px 2px`).
const double _headPadBottom = 2;

/// Glissement de départ d'une ligne (`gc-row` : `translateX(-12px)`).
const double _rowShift = 12;

/// Hauteur de ligne du texte des cellules (`.gc-check` : `15px/20px`).
const double _cellLineHeight = 20;

/// [style] à la hauteur de ligne du tableau.
TextStyle _cellStyle(TextStyle style) =>
    style.copyWith(height: _cellLineHeight / (style.fontSize ?? 15));

/// Nombre de partages essayés entre la colonne du critère et celle de la
/// valeur quand la cellule est étroite.
const int _splitSteps = 32;

/// Nombre de lignes au-delà duquel le décalage de la cascade ne grandit plus.
const int _cascadeCap = 8;

/// Durée d'une cascade de [rows] lignes : une ligne s'écrit en
/// [SceneMotion.row], la suivante [SceneMotion.stagger] plus tard.
Duration _cascadeDuration(int rows) =>
    SceneMotion.row +
    SceneMotion.stagger * ((rows > _cascadeCap ? _cascadeCap : rows) - 1);

class _ChecklistView extends StatefulWidget {
  const _ChecklistView({required this.checklist});

  final _Checklist checklist;

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
  late final bool _restored = DsRise.settledOf(context);
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
    final _Checklist checklist = widget.checklist;
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Head(checklist: checklist),
          Expanded(
            child: _Table(items: checklist.items, cascade: oneShot),
          ),
        ],
      ),
    );
  }
}

/// Espace entre deux lignes de l'en-tête quand il ne tient pas sur une seule.
const double _headRunGap = 4;

/// En-tête du panneau : titre et verdict (grande puce) à gauche, compteur
/// « n bloquants / total » à droite, et la puce de décision.
///
/// Selon la largeur, mesurée avec les polices réelles :
/// - tout tient : titre, verdict et décision à gauche, compteur à droite ;
/// - sinon : titre et verdict à gauche, décision au-dessus du compteur à
///   droite (l'en-tête garde environ la hauteur de la grande puce) ;
/// - sinon : le côté gauche passe à la ligne. Rien n'est jamais tronqué.
class _Head extends StatefulWidget {
  const _Head({required this.checklist});

  final _Checklist checklist;

  @override
  State<_Head> createState() => _HeadState();
}

class _HeadState extends State<_Head> {
  /// La puce de décision change de place selon la largeur que prend son texte :
  /// la clé globale conserve son `State` (et donc la transition de statut)
  /// quand elle passe d'un côté à l'autre.
  final GlobalKey _decisionKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final _Checklist checklist = widget.checklist;
    final SceneTheme theme = SceneTheme.of(context);
    final String count = blockingSummary(
      checklist.items.map((_Item item) => item.level),
    );
    final Widget title = Text(checklist.title, style: theme.title);
    final Widget verdict = DsStatusChip(
      key: const Key('checklist-verdict'),
      status: checklist.recommendationLevel,
      label: checklist.recommendationLabel,
      large: true,
    );
    final Widget decision = _DecisionStatus(
      key: _decisionKey,
      status: checklist.decisionStatus,
    );
    final Widget counter = DsCaps(count, key: const Key('checklist-count'));

    Widget wrapped(List<Widget> children) => Wrap(
      spacing: _headerGap,
      runSpacing: _headRunGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: DsPanelHead.bottomMargin),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double titleW = measureTextWidth(
            context,
            checklist.title,
            theme.title,
          );
          final double verdictW = DsStatusChip.measure(
            context,
            checklist.recommendationLevel,
            checklist.recommendationLabel,
            large: true,
          ).width;
          final double decisionW = DsStatusChip.measure(
            context,
            null,
            checklist.decisionStatus,
          ).width;
          final double countW = measureTextWidth(
            context,
            count.toUpperCase(),
            theme.label,
          );
          // Marge d'arrondi : un demi-pixel ne doit pas faire passer à la ligne.
          const double slack = 2;
          final double avail = constraints.maxWidth - DsPanelHead.gap;
          final double lead = titleW + _headerGap + verdictW + slack;
          final bool oneLine =
              lead + _headerGap + decisionW + countW + slack <= avail;
          final bool stacked =
              !oneLine &&
              lead + (decisionW > countW ? decisionW : countW) + slack <= avail;
          return Row(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: wrapped(
                  stacked
                      ? <Widget>[title, verdict]
                      : <Widget>[title, verdict, decision],
                ),
              ),
              const SizedBox(width: DsPanelHead.gap),
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    decision,
                    const SizedBox(height: _headRunGap),
                    counter,
                  ],
                )
              else
                counter,
            ],
          );
        },
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

  final List<_Item> items;

  /// Avancement de la cascade (0 à 1).
  final Animation<double> cascade;

  static int _priority(_Item item) => switch (item.level) {
    SceneStatus.blocking => 0,
    SceneStatus.risk => 1,
    _ => 2,
  };

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _Grid grid = _Grid.measure(
          context,
          theme,
          items,
          constraints.maxWidth,
        );
        final double moreHeight = lineHeightOf(theme.body) + _rowGap;
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

/// Géométrie du tableau : largeur du contenu de chaque colonne et hauteur de
/// chaque ligne, mesurées avec les polices réelles.
///
/// Les colonnes du seuil et de la puce gardent leur largeur naturelle ; quand
/// la cellule est trop étroite, les colonnes du critère et de la valeur
/// rétrécissent (leurs textes passent à la ligne, jamais en dessous du mot le
/// plus long). Quand elle est large, la colonne du critère prend le surplus.
class _Grid {
  const _Grid._({
    required this.label,
    required this.threshold,
    required this.value,
    required this.chip,
    required this.heights,
    required this.headHeight,
    required this.labelStyle,
    required this.dataStyle,
  });

  /// Largeur du contenu de chaque colonne (remplissage horizontal exclu).
  final double label;
  final double threshold;
  final double value;
  final double chip;

  /// Hauteur de chaque ligne, avec l'espace qui la précède.
  final List<double> heights;

  /// Hauteur de la ligne d'en-têtes.
  final double headHeight;

  final TextStyle labelStyle;
  final TextStyle dataStyle;

  static double _widest(
    BuildContext context,
    Iterable<String> texts,
    TextStyle style,
  ) {
    double max = 0;
    for (final String t in texts) {
      final double w = measureTextWidth(context, t, style);
      if (w > max) max = w;
    }
    // Marge d'arrondi pour ne pas déclencher un retour à la ligne sur un
    // demi-pixel.
    return max == 0 ? 0 : max.ceilToDouble() + 1;
  }

  /// Largeur du mot le plus long : en dessous, un mot serait coupé.
  static double _longestWord(
    BuildContext context,
    Iterable<String> texts,
    TextStyle style,
  ) => _widest(
    context,
    texts.expand((String t) => t.split(RegExp(r'\s+'))),
    style,
  );

  static _Grid measure(
    BuildContext context,
    SceneTheme theme,
    List<_Item> items,
    double maxWidth,
  ) {
    final TextStyle labelStyle = _cellStyle(theme.body.withSceneWeight(500));
    final TextStyle dataStyle = _cellStyle(theme.data);
    final Iterable<String> labels = items.map((_Item i) => i.label);
    final Iterable<String> thresholds = items.map((_Item i) => i.threshold);
    final Iterable<String> values = items.map((_Item i) => i.value);

    // Largeur réelle de la plus large puce, glyphe ou point compris, fournie
    // par la puce elle-même (même marge d'arrondi que les textes).
    double chip = 0;
    for (final _Item i in items) {
      final double w = DsStatusChip.measure(
        context,
        i.level,
        i.levelLabel,
      ).width;
      if (w > chip) chip = w;
    }
    if (chip > 0) chip = chip.ceilToDouble() + 1;

    double label = _widest(context, labels, labelStyle);
    double threshold = _widest(context, thresholds, dataStyle);
    double value = _widest(context, values, dataStyle);

    // Largeur disponible pour les contenus : sans les remplissages des quatre
    // cellules ni la bordure de la ligne.
    final double available = maxWidth - 4 * 2 * _cellPadH - 2 * _rowBorder;
    final double natural = label + threshold + value + chip;
    double rowsHeight(double labelWidth, double valueWidth) {
      double sum = 0;
      for (final _Item item in items) {
        sum += _rowHeight(
          context,
          item,
          labelWidth,
          threshold,
          valueWidth,
          labelStyle,
          dataStyle,
        );
      }
      return sum;
    }

    if (!available.isFinite || natural <= available) {
      if (available.isFinite) label += available - natural;
    } else {
      // Trop étroit : le critère et la valeur se partagent ce que laissent le
      // seuil et la puce, au partage qui donne les lignes les moins hautes
      // (à égalité, le plus proche du partage proportionnel).
      final double shared = available - threshold - chip;
      final double labelMin = _longestWord(context, labels, labelStyle);
      final double valueMin = _longestWord(context, values, dataStyle);
      if (shared >= labelMin + valueMin) {
        final double proportional = shared * label / (label + value);
        final double span = shared - valueMin - labelMin;
        double bestLabel = labelMin;
        double bestScore = double.infinity;
        for (int step = 0; step <= _splitSteps; step++) {
          final double candidate = labelMin + span * step / _splitSteps;
          final double score =
              rowsHeight(candidate, shared - candidate) +
              (candidate - proportional).abs() / 1000;
          if (score < bestScore) {
            bestScore = score;
            bestLabel = candidate;
          }
        }
        label = bestLabel;
        value = shared - bestLabel;
      } else {
        // Même au plus serré les mots ne tiennent pas : tout rétrécit
        // proportionnellement (un mot peut alors être coupé, jamais perdu).
        final double flexible = available - chip;
        final double k = flexible > 0
            ? flexible / (label + threshold + value)
            : 0;
        label *= k;
        threshold *= k;
        value *= k;
      }
    }

    final List<double> heights = <double>[
      for (final _Item item in items)
        _rowGap +
            _rowHeight(
              context,
              item,
              label,
              threshold,
              value,
              labelStyle,
              dataStyle,
            ),
    ];
    return _Grid._(
      label: label,
      threshold: threshold,
      value: value,
      chip: chip,
      heights: heights,
      headHeight: lineHeightOf(theme.label) + _headPadBottom,
      labelStyle: labelStyle,
      dataStyle: dataStyle,
    );
  }

  static double _rowHeight(
    BuildContext context,
    _Item item,
    double label,
    double threshold,
    double value,
    TextStyle labelStyle,
    TextStyle dataStyle,
  ) {
    double tallest = DsStatusChip.height;
    for (final double h in <double>[
      measureTextHeight(context, item.label, labelStyle, label),
      measureTextHeight(context, item.threshold, dataStyle, threshold),
      measureTextHeight(context, item.value, dataStyle, value),
    ]) {
      if (h > tallest) tallest = h;
    }
    return tallest + 2 * _cellPadV + 2 * _rowBorder;
  }

  /// Largeur d'une colonne, remplissage compris.
  List<double> get _boxes => <double>[
    label + 2 * _cellPadH,
    threshold + 2 * _cellPadH,
    value + 2 * _cellPadH,
    chip + 2 * _cellPadH,
  ];

  /// Ligne d'en-têtes : `label` en capitales, `ink-muted`. La colonne des
  /// statuts n'a pas de titre.
  Widget head(SceneTheme theme) {
    final List<double> boxes = _boxes;
    final TextStyle style = theme.label.copyWith(color: theme.textSecondary);
    const List<String> titles = <String>[
      _criterionHeading,
      _thresholdHeading,
      _valueHeading,
      '',
    ];
    return Padding(
      // Le liseré et la bordure d'une ligne décalent ses cellules : les
      // en-têtes suivent la même marge pour rester alignés.
      padding: const EdgeInsets.only(left: _rowBorder, right: _rowBorder),
      child: Row(
        children: <Widget>[
          for (int c = 0; c < 4; c++)
            SizedBox(
              key: Key('checklist-head-$c'),
              width: boxes[c],
              child: Padding(
                padding: const EdgeInsets.only(
                  left: _cellPadH,
                  right: _cellPadH,
                  bottom: _headPadBottom,
                ),
                child: titles[c].isEmpty
                    ? SizedBox(height: lineHeightOf(style))
                    : DsCaps(titles[c], style: style),
              ),
            ),
        ],
      ),
    );
  }

  /// Ligne du critère [index] : fond `surface-200`, bordure `line`, coins
  /// `md`, liseré `nogo` si le code `level` est bloquant.
  Widget row(SceneTheme theme, int index, _Item item) {
    final List<double> boxes = _boxes;
    Widget cell(int column, Widget child, {Alignment? align}) => SizedBox(
      key: Key('checklist-cell-$index-$column'),
      width: boxes[column],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _cellPadH,
          vertical: _cellPadV,
        ),
        child: align == null ? child : Align(alignment: align, child: child),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: _rowGap),
      child: DecoratedBox(
        key: Key('checklist-row-$index'),
        decoration: BoxDecoration(
          color: theme.surface200,
          borderRadius: SceneRadius.borderMd,
          border: Border.all(color: theme.line, width: _rowBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_rowBorder),
          child: ClipRRect(
            borderRadius: SceneRadius.borderMd,
            child: Stack(
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    cell(0, Text(item.label, style: labelStyle)),
                    cell(1, Text(item.threshold, style: dataStyle)),
                    cell(2, Text(item.value, style: dataStyle)),
                    cell(
                      3,
                      SizedBox(
                        width: chip,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: DsStatusChip(
                            status: item.level,
                            label: item.levelLabel,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.level == SceneStatus.blocking)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _edgeWidth,
                    child: DecoratedBox(
                      key: Key('checklist-row-$index-edge'),
                      decoration: BoxDecoration(
                        color: theme.blockingForeground,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
