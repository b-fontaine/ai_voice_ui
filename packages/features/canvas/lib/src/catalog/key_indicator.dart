import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import 'bound_item.dart';
import 'fr_percent.dart';
import 'gauge_scale.dart';

/// `KeyIndicator` : un indicateur clé (libellé, valeur, tendance, seuil, statut).
///
/// Habillage du design system (spec 019, pdr-0088 F3) : en-tête de panneau,
/// chiffre héros (compteur de 100 vers la valeur), jauge avec marque de seuil
/// et repère de comparaison, deltas « Tendance » et « vs `comparaison` ». Les
/// données sont des chaînes : une valeur, un seuil ou une comparaison
/// illisibles ne donnent ni jauge, ni marque, ni repère (jamais inventés).
final CatalogItem keyIndicatorItem = boundCatalogItem<_Kpi>(
  name: 'KeyIndicator',
  description: 'Indicateur clé lié à /kpi.',
  parse: _Kpi.tryParse,
  build: (BuildContext context, _Kpi kpi, String _) => _Complete(kpi: kpi),
);

/// Objet `/kpi` validé.
class _Kpi {
  const _Kpi({
    required this.label,
    required this.value,
    required this.trend,
    required this.threshold,
    required this.status,
    required this.statusLabel,
    this.comparison,
    this.percent,
    this.thresholdPercent,
    this.comparisonPercent,
  });

  final String label;
  final String value;
  final String trend;
  final String threshold;
  final SceneStatus status;
  final String statusLabel;

  /// Comparaison de l'acte 2 (`{label, value, delta}`) ; `null` : omise.
  final _Comparison? comparison;

  /// Lectures de `value`, de `threshold` et de `comparison.value` (pdr-0088
  /// F3), faites une fois à l'analyse : `null` si le texte est illisible.
  final FrPercent? percent;
  final double? thresholdPercent;
  final double? comparisonPercent;

  /// `null` si l'objet n'est pas une `Map` ou si un champ requis manque, a un
  /// mauvais type ou un statut hors `ok|risk|blocking`.
  static _Kpi? tryParse(Object raw) {
    if (raw is! Map) return null;
    final String? label = readString(raw, 'label');
    final String? value = readString(raw, 'value');
    final String? trend = readString(raw, 'trend');
    final String? threshold = readString(raw, 'threshold');
    final String? statusLabel = readString(raw, 'statusLabel');
    final SceneStatus? status = SceneStatus.fromCode(readString(raw, 'status'));
    if (label == null ||
        value == null ||
        trend == null ||
        threshold == null ||
        statusLabel == null ||
        status == null) {
      return null;
    }
    final _Comparison? comparison = _Comparison.tryParse(raw['comparison']);
    return _Kpi(
      label: label,
      value: value,
      trend: trend,
      threshold: threshold,
      status: status,
      statusLabel: statusLabel,
      comparison: comparison,
      percent: FrPercent.tryParse(value),
      thresholdPercent: parseFrPercent(threshold),
      comparisonPercent: comparison == null
          ? null
          : parseFrPercent(comparison.value),
    );
  }
}

/// Comparaison à une autre version (`comparison` du contrat).
class _Comparison {
  const _Comparison({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;

  /// `null` si l'objet n'est pas une `Map` ou si un des trois textes manque.
  static _Comparison? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final String? label = readString(raw, 'label');
    final String? value = readString(raw, 'value');
    final String? delta = readString(raw, 'delta');
    if (label == null || value == null || delta == null) return null;
    return _Comparison(label: label, value: value, delta: delta);
  }
}

/// Lueur `nogo` du chiffre héros (`text-shadow: 0 0 32px #ff5a7655`).
const double _glowBlur = 32;
const double _glowAlpha = 0x55 / 255;

class _Complete extends StatefulWidget {
  const _Complete({required this.kpi});

  final _Kpi kpi;

  @override
  State<_Complete> createState() => _CompleteState();
}

class _CompleteState extends State<_Complete>
    with SingleTickerProviderStateMixin<_Complete>, SceneOneShot<_Complete> {
  late final bool _restored = DsRise.settledOf(context);
  bool _started = false;

  FrPercent? get _value => widget.kpi.percent;

  @override
  Duration get oneShotBase => SceneMotion.count;

  // Surface restaurée ou valeur illisible : rien à compter.
  @override
  double get oneShotInitialValue => _restored || _value == null ? 1 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_restored && _value != null) playOneShot();
  }

  // Le compteur rejoue à chaque changement de valeur (mutation de l'acte 2),
  // jamais à une mise à jour qui laisse la valeur inchangée (pdr-0088 F13).
  @override
  void didUpdateWidget(_Complete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kpi.value == widget.kpi.value) return;
    if (_value == null) {
      oneShot.value = 1;
    } else {
      playOneShot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final _Kpi kpi = widget.kpi;
    final FrPercent? value = _value;
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DsPanelHead(
            label: kpi.label,
            wrap: true,
            trailing: DsStatusChip(status: kpi.status, label: kpi.statusLabel),
          ),
          _Hero(
            text: kpi.value,
            parsed: value,
            status: kpi.status,
            progress: oneShot,
          ),
          if (value != null)
            _gauge(
              theme,
              value: value.value,
              threshold: kpi.thresholdPercent,
              reference: kpi.comparisonPercent,
            ),
          const SizedBox(height: 8),
          _Deltas(kpi: kpi),
        ],
      ),
    );
  }

  Widget _gauge(
    SceneTheme theme, {
    required double value,
    required double? threshold,
    required double? reference,
  }) {
    final _Kpi kpi = widget.kpi;
    final GaugeScale scale = GaugeScale.of(
      value: value,
      threshold: threshold,
      comparison: reference,
    );
    return DsGauge(
      fill: scale.fraction(value),
      fillColor: switch (kpi.status) {
        SceneStatus.blocking => theme.blockingForeground,
        SceneStatus.risk => theme.riskForeground,
        SceneStatus.ok => theme.okForeground,
      },
      mark: threshold == null ? null : scale.fraction(threshold),
      markLabel: threshold == null ? null : 'seuil ${kpi.threshold}',
      reference: reference == null ? null : scale.fraction(reference),
      referenceLabel: reference == null ? null : kpi.comparison!.label,
      settled: _restored,
      keys: const DsGaugeKeys(
        track: Key('kpi-gauge'),
        fill: Key('kpi-gauge-fill'),
        mark: Key('kpi-gauge-mark'),
        markLabel: Key('kpi-gauge-mark-label'),
        reference: Key('kpi-gauge-ref'),
        referenceLabel: Key('kpi-gauge-ref-label'),
      ),
    );
  }
}

/// Chiffre héros : valeur (76 px) et unité (36 px) dans un seul `Text.rich`
/// dont `toPlainText()` égale la chaîne de données ; compteur de 100 vers la
/// valeur tant que [progress] n'est pas à 1, lueur `nogo` si le statut est
/// bloquant. Texte illisible ([parsed] nul) : la chaîne telle quelle.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.text,
    required this.parsed,
    required this.status,
    required this.progress,
  });

  final String text;
  final FrPercent? parsed;
  final SceneStatus status;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final List<Shadow>? glow = status == SceneStatus.blocking
        ? <Shadow>[
            Shadow(
              color: theme.blockingForeground.withValues(alpha: _glowAlpha),
              blurRadius: _glowBlur,
            ),
          ]
        : null;
    final TextStyle valueStyle = theme.value.copyWith(shadows: glow);
    final TextStyle unitStyle = theme.micro.kpiUnit.copyWith(
      color: theme.textSecondary,
      shadows: glow,
    );
    final FrPercent? number = parsed;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: progress,
        builder: (BuildContext context, Widget? _) {
          final InlineSpan span = number == null
              ? TextSpan(text: text, style: valueStyle)
              : TextSpan(
                  text: '${number.prefix}${_shown(number)}',
                  style: valueStyle,
                  children: <InlineSpan>[
                    TextSpan(text: number.suffix, style: unitStyle),
                  ],
                );
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              span,
              key: const Key('kpi-value'),
              maxLines: 1,
              softWrap: false,
            ),
          );
        },
      ),
    );
  }

  /// Le nombre affiché : celui de la donnée une fois le compteur fini, sinon
  /// la valeur intermédiaire entre 100 et la valeur, à deux décimales.
  String _shown(FrPercent number) {
    if (progress.value >= 1) return number.number;
    final double eased = SceneMotion.curve.transform(progress.value);
    final double current = 100 + (number.value - 100) * eased;
    return current.toStringAsFixed(2).replaceAll('.', ',');
  }
}

/// Deltas en grille de deux colonnes (`.gc-kpi__deltas`) : « Tendance » (la
/// tendance telle quelle) puis « vs `comparaison` » (écart puis valeur de la
/// comparaison). Pas de « vs seuil » : l'écart au seuil serait une valeur
/// calculée (Q-94). Les textes sont ceux des données, jamais lus ni recalculés.
class _Deltas extends StatelessWidget {
  const _Deltas({required this.kpi});

  final _Kpi kpi;

  static const double _columnGap = 16;
  static const double _rowGap = 6;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final TextStyle base = theme.micro.delta;
    final _Comparison? comparison = kpi.comparison;
    TableRow row(Widget label, Widget value, {bool last = false}) => TableRow(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
            right: _columnGap,
            bottom: last ? 0 : _rowGap,
          ),
          child: label,
        ),
        Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : _rowGap),
          child: value,
        ),
      ],
    );
    Text term(String text, Key key) => Text(
      text,
      key: key,
      style: base.copyWith(color: theme.textSecondary),
      maxLines: 1,
    );
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: <TableRow>[
        row(
          term('Tendance', const Key('kpi-delta-trend-label')),
          Text(
            kpi.trend,
            key: const Key('kpi-delta-trend-value'),
            style: base.copyWith(color: theme.textPrimary),
            maxLines: 1,
          ),
          last: comparison == null,
        ),
        if (comparison != null)
          row(
            term(
              'vs ${comparison.label}',
              const Key('kpi-delta-comparison-label'),
            ),
            Text.rich(
              TextSpan(
                style: base,
                children: <InlineSpan>[
                  TextSpan(
                    text: comparison.delta,
                    style: TextStyle(color: theme.textPrimary),
                  ),
                  TextSpan(
                    text: ' (${comparison.value})',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                ],
              ),
              key: const Key('kpi-delta-comparison-value'),
              maxLines: 1,
            ),
            last: true,
          ),
      ],
    );
  }
}
