import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart';

import 'checklist_model.dart';
import 'column_split.dart';
import 'text_metrics.dart';

/// Titre de la colonne des critères.
const String _criterionHeading = 'Critère';

/// Titre de la colonne des seuils.
const String _thresholdHeading = 'Seuil';

/// Titre de la colonne des valeurs : neutre, sans version (la valeur de
/// chaque ligne dit déjà de quelle version elle parle, pdr-0088 P1).
const String _valueHeading = 'Valeur';

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

/// Hauteur de ligne du texte des cellules (`.gc-check` : `15px/20px`).
const double _cellLineHeight = 20;

/// [style] à la hauteur de ligne du tableau.
TextStyle _cellStyle(TextStyle style) =>
    style.copyWith(height: _cellLineHeight / (style.fontSize ?? 15));

/// Géométrie du tableau : largeur du contenu de chaque colonne et hauteur de
/// chaque ligne, mesurées avec les polices réelles.
///
/// Les colonnes du seuil et de la puce gardent leur largeur naturelle ; quand
/// la cellule est trop étroite, les colonnes du critère et de la valeur
/// rétrécissent (leurs textes passent à la ligne, jamais en dessous du mot le
/// plus long). Quand elle est large, la colonne du critère prend le surplus.
class ChecklistGrid {
  const ChecklistGrid._({
    required this.label,
    required this.threshold,
    required this.value,
    required this.chip,
    required this.heights,
    required this.headHeight,
    required this.labelStyle,
    required this.dataStyle,
  });

  /// Espace entre deux lignes du tableau (`border-spacing: 0 6px`).
  static const double rowGap = 6;

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

  static ChecklistGrid measure(
    BuildContext context,
    SceneTheme theme,
    List<ChecklistItem> items,
    double maxWidth,
  ) {
    final TextStyle labelStyle = theme.micro.criterion.copyWith(
      color: theme.textPrimary,
    );
    final TextStyle dataStyle = _cellStyle(theme.data);
    final Iterable<String> labels = items.map((ChecklistItem i) => i.label);
    final Iterable<String> thresholds = items.map(
      (ChecklistItem i) => i.threshold,
    );
    final Iterable<String> values = items.map((ChecklistItem i) => i.value);

    // Largeur réelle de la plus large puce, glyphe ou point compris, fournie
    // par la puce elle-même (même marge d'arrondi que les textes).
    double chip = 0;
    for (final ChecklistItem i in items) {
      final double w = DsStatusChip.measure(
        context,
        i.level,
        i.levelLabel,
      ).width;
      if (w > chip) chip = w;
    }
    if (chip > 0) chip = chip.ceilToDouble() + 1;

    // Largeur disponible pour les contenus : sans les remplissages des quatre
    // cellules ni la bordure de la ligne.
    final double available = maxWidth - 4 * 2 * _cellPadH - 2 * _rowBorder;
    final ColumnWidths natural = (
      label: _widest(context, labels, labelStyle),
      threshold: _widest(context, thresholds, dataStyle),
      value: _widest(context, values, dataStyle),
    );
    final ColumnWidths widths = splitColumns(
      available: available,
      natural: natural,
      chip: chip,
      minimums: () => (
        label: _longestWord(context, labels, labelStyle),
        value: _longestWord(context, values, dataStyle),
      ),
      rowsHeight: (double labelWidth, double valueWidth) {
        double sum = 0;
        for (final ChecklistItem item in items) {
          sum += _rowHeight(
            context,
            item,
            labelWidth,
            natural.threshold,
            valueWidth,
            labelStyle,
            dataStyle,
          );
        }
        return sum;
      },
    );
    final double label = widths.label;
    final double threshold = widths.threshold;
    final double value = widths.value;

    final List<double> heights = <double>[
      for (final ChecklistItem item in items)
        rowGap +
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
    return ChecklistGrid._(
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
    ChecklistItem item,
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
  Widget row(SceneTheme theme, int index, ChecklistItem item) {
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
      padding: const EdgeInsets.only(top: rowGap),
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
