import 'package:a2ui_flutter/a2ui_flutter.dart' show ComponentImplementation;
import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../ui/surface_restored.dart';
import 'bound_item.dart';
import 'split_share.dart';
import 'text_metrics.dart';

/// `ReviewSentiment` : en-tête (titre, nombre d'avis et note moyenne),
/// légende et barre de répartition positifs / négatifs, ligne de comparaison
/// de l'acte 2 si `comparison` est complet, puis les extraits d'avis en
/// cartes (`gc-quote`).
final ComponentImplementation reviewSentimentItem = boundCatalogItem<_Reviews>(
  name: 'ReviewSentiment',
  description: 'Sentiment des avis lié à /reviews.',
  parse: _Reviews.tryParse,
  build: (BuildContext context, _Reviews r, String _) =>
      _ReviewsView(reviews: r),
);

class _Excerpt {
  const _Excerpt(this.stars, this.platform, this.text);

  final int stars;
  final String platform;
  final String text;
}

class _Reviews {
  const _Reviews({
    required this.title,
    required this.count,
    required this.positivePct,
    required this.negativePct,
    required this.average,
    required this.excerpts,
    this.comparison,
  });

  final String title;
  final int count;
  final int positivePct;
  final int negativePct;
  final double average;
  final List<_Excerpt> excerpts;

  /// Ligne de comparaison de l'acte 2 ; `null` : omise.
  final String? comparison;

  /// Exactement 3 extraits attendus, étoiles de 1 à 5.
  static _Reviews? tryParse(Object raw) {
    if (raw is! Map) return null;
    final String? title = readString(raw, 'title');
    final int? count = readInt(raw, 'count');
    final int? positive = readInt(raw, 'positivePct');
    final int? negative = readInt(raw, 'negativePct');
    final double? average = readNumber(raw, 'average');
    final List<Map<Object?, Object?>>? rawExcerpts = readMaps(raw, 'excerpts');
    if (title == null ||
        count == null ||
        positive == null ||
        negative == null ||
        average == null ||
        rawExcerpts == null ||
        rawExcerpts.length != 3) {
      return null;
    }
    final List<_Excerpt> excerpts = <_Excerpt>[];
    for (final Map<Object?, Object?> e in rawExcerpts) {
      final int? stars = readInt(e, 'stars');
      final String? platform = readString(e, 'platform');
      final String? text = readString(e, 'text');
      if (stars == null ||
          stars < 1 ||
          stars > 5 ||
          platform == null ||
          text == null) {
        return null;
      }
      excerpts.add(_Excerpt(stars, platform, text));
    }
    return _Reviews(
      title: title,
      count: count,
      positivePct: positive,
      negativePct: negative,
      average: average,
      excerpts: excerpts,
      comparison: readComparisonText(raw),
    );
  }
}

/// Hauteur de la barre de répartition (`.gc-split`).
const double _barHeight = 10;

/// Espace au-dessus de la légende (`margin: 10px 0 4px`), sous l'en-tête
/// dont la marge basse (14 px) se confond avec lui.
const double _legendBottom = 4;

/// Espace entre la barre (ou la ligne de comparaison) et les cartes, et entre
/// deux cartes (`.gc-quote { margin-top: 10px }`).
const double _cardGap = 10;

/// Espace au-dessus de la ligne de comparaison (`margin-top: 8px`).
const double _comparisonGap = 8;

/// Remplissage d'une carte (`padding: 12px 14px`).
const double _cardPadV = 12;
const double _cardPadH = 14;

/// Espace entre « 1★ Android » et le texte (`gap: 4px 12px`, colonnes).
const double _cardColumnGap = 12;

class _ReviewsView extends StatefulWidget {
  const _ReviewsView({required this.reviews});

  final _Reviews reviews;

  @override
  State<_ReviewsView> createState() => _ReviewsViewState();
}

/// Joue une fois, au premier `data` de la surface (pdr-0088 F13), le
/// remplissage de la barre (1,4 s, le négatif 200 ms plus tard) et
/// l'apparition des cartes : un seul contrôleur. Une mise à jour des données
/// se fait sur place.
class _ReviewsViewState extends State<_ReviewsView>
    with
        SingleTickerProviderStateMixin<_ReviewsView>,
        SceneOneShot<_ReviewsView> {
  late final bool _restored = SurfaceRestored.of(context);
  bool _started = false;

  @override
  Duration get oneShotBase => splitDuration;

  // Surface restaurée : l'état final, sans animation.
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
    final SceneTheme theme = SceneTheme.of(context);
    final _Reviews reviews = widget.reviews;
    final String average = reviews.average
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    final TextStyle legend = theme.micro.splitLegend;
    final ({double positive, double negative})? shares = splitShares(
      reviews.positivePct,
      reviews.negativePct,
    );
    // Les en-têtes passent à la ligne si besoin ; les cartes prennent la
    // hauteur restante de la cellule (302 px à 1920 × 1080) et n'y figurent
    // qu'en entier.
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DsPanelHead.title(
            title: reviews.title,
            wrap: true,
            trailing: Text(
              '${reviews.count} avis · $average ★',
              style: theme.micro.legend.copyWith(color: theme.textSecondary),
            ),
          ),
          // Chaque pourcentage cède de la place à l'autre dans une cellule
          // étroite (3 × 2) et passe à la ligne au lieu de déborder.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Text(
                  '${reviews.positivePct} % positifs',
                  key: const Key('reviews-legend-pos'),
                  style: legend.copyWith(color: theme.okForeground),
                ),
              ),
              Flexible(
                child: Text(
                  '${reviews.negativePct} % négatifs',
                  key: const Key('reviews-legend-neg'),
                  textAlign: TextAlign.end,
                  style: legend.copyWith(color: theme.blockingForeground),
                ),
              ),
            ],
          ),
          if (shares != null) ...<Widget>[
            const SizedBox(height: _legendBottom),
            _SplitBar(shares: shares, progress: oneShot),
          ],
          if (reviews.comparison != null) ...<Widget>[
            const SizedBox(height: _comparisonGap),
            comparisonLine(
              context,
              key: const Key('comparison-reviews'),
              text: reviews.comparison!,
            ),
          ],
          Expanded(
            child: _Excerpts(excerpts: reviews.excerpts, progress: oneShot),
          ),
        ],
      ),
    );
  }
}

/// Barre de répartition (`.gc-split`) : 10 px, rayon 5, fond `surface-300`,
/// part positive à gauche, part négative à droite, écart de 2 px.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.shares, required this.progress});

  final ({double positive, double negative}) shares;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return RepaintBoundary(
      child: SizedBox(
        key: const Key('reviews-split'),
        height: _barHeight,
        child: ClipRRect(
          borderRadius: SceneRadius.borderPill,
          child: ColoredBox(
            color: theme.surface300,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  AnimatedBuilder(
                    animation: progress,
                    builder: (BuildContext context, Widget? _) {
                      final ({double positive, double negative})
                      w = splitWidths(
                        track: constraints.maxWidth,
                        shares: shares,
                        positiveProgress: splitPositiveProgress(progress.value),
                        negativeProgress: splitNegativeProgress(progress.value),
                      );
                      return Stack(
                        children: <Widget>[
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: w.positive,
                            child: ColoredBox(
                              key: const Key('reviews-split-pos'),
                              color: theme.okForeground,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: w.negative,
                            child: ColoredBox(
                              key: const Key('reviews-split-neg'),
                              color: theme.blockingForeground,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les cartes qui tiennent en entier dans la hauteur disponible, dans l'ordre
/// du contrat, puis « + N avis » pour les autres. Un extrait n'est jamais
/// coupé ni tronqué : s'il ne tient pas, il rejoint les N avis non affichés.
class _Excerpts extends StatelessWidget {
  const _Excerpts({required this.excerpts, required this.progress});

  final List<_Excerpt> excerpts;
  final Animation<double> progress;

  static String _head(_Excerpt e) => '${e.stars}★ ${e.platform}';

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double moreHeight = lineHeightOf(theme.body);
        final double budget = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : double.infinity;
        final List<double> heights = <double>[
          for (final _Excerpt e in excerpts)
            _cardHeight(context, theme, e, constraints.maxWidth),
        ];
        // Plus grand préfixe de cartes qui tient, avec la ligne « + N avis »
        // s'il en reste.
        int shown = 0;
        double used = 0;
        for (int i = 0; i < excerpts.length; i++) {
          final bool last = i == excerpts.length - 1;
          final double next = used + _cardGap + heights[i];
          if (next + (last ? 0 : _cardGap + moreHeight) > budget) break;
          used = next;
          shown = i + 1;
        }
        final int hidden = excerpts.length - shown;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < shown; i++)
              _Card(index: i, excerpt: excerpts[i], progress: progress),
            if (hidden > 0 && _cardGap + moreHeight <= budget)
              Padding(
                padding: const EdgeInsets.only(top: _cardGap),
                child: MoreLine(
                  textKey: const Key('review-more'),
                  text: '+ $hidden avis',
                  height: moreHeight,
                ),
              ),
          ],
        );
      },
    );
  }

  static double _cardHeight(
    BuildContext context,
    SceneTheme theme,
    _Excerpt e,
    double maxWidth,
  ) {
    final double metaWidth = measureTextWidth(
      context,
      _head(e),
      theme.micro.quoteMeta,
    ).ceilToDouble();
    final double textWidth =
        maxWidth - 2 * _cardPadH - metaWidth - 1 - _cardColumnGap;
    final double text = measureTextHeight(
      context,
      e.text,
      theme.micro.quote,
      textWidth,
    );
    final double meta = lineHeightOf(theme.micro.quoteMeta);
    return 2 * _cardPadV + (meta > text ? meta : text);
  }
}

/// Une carte de verbatim (`.gc-quote`) : `surface-300`, rayon `md`, note et
/// plateforme à gauche, texte à droite. Elle apparaît (`gc-rise` sans flou :
/// opacité et glissement de 10 px) [index] × `stagger` après la première.
class _Card extends StatelessWidget {
  const _Card({
    required this.index,
    required this.excerpt,
    required this.progress,
  });

  final int index;
  final _Excerpt excerpt;
  final Animation<double> progress;

  /// Part de la lecture commune occupée par cette carte, avec la courbe du
  /// design system.
  Interval _interval() {
    final double total = splitDuration.inMicroseconds.toDouble();
    final double begin = (SceneMotion.stagger * index).inMicroseconds / total;
    final double end = begin + SceneMotion.appear.inMicroseconds / total;
    return Interval(begin, end, curve: SceneMotion.curve);
  }

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final Widget card = Padding(
      padding: const EdgeInsets.only(top: _cardGap),
      child: Container(
        key: Key('reviews-card-$index'),
        padding: const EdgeInsets.symmetric(
          vertical: _cardPadV,
          horizontal: _cardPadH,
        ),
        decoration: BoxDecoration(
          color: theme.surface300,
          borderRadius: SceneRadius.borderMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '${excerpt.stars}★',
                    style: TextStyle(color: theme.blockingForeground),
                  ),
                  TextSpan(text: ' ${excerpt.platform}'),
                ],
              ),
              key: Key('reviews-card-$index-meta'),
              softWrap: false,
              style: theme.micro.quoteMeta.copyWith(color: theme.textSecondary),
            ),
            const SizedBox(width: _cardColumnGap),
            Expanded(
              child: Text(
                excerpt.text,
                key: Key('reviews-card-$index-text'),
                style: theme.micro.quote.copyWith(color: theme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
    // Opacité et glissement seulement : le flou de `gc-rise` est réservé aux
    // surfaces (pdr-0088 F5), jamais à leurs cartes.
    return DsReveal(
      animation: progress,
      from: const Offset(0, SceneMotion.translation),
      interval: _interval(),
      child: card,
    );
  }
}
