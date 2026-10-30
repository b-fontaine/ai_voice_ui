import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import 'bound_item.dart';

/// `ReviewSentiment` : répartition positifs / négatifs, note moyenne et
/// 3 extraits d'avis, et la ligne de comparaison de l'acte 2 si `comparison`
/// est complet.
final CatalogItem reviewSentimentItem = boundCatalogItem<_Reviews>(
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

class _ReviewsView extends StatelessWidget {
  const _ReviewsView({required this.reviews});

  final _Reviews reviews;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final String average = reviews.average
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    // Budget de hauteur (cellule de 250 px à 1920 × 1080, marge de 2 × 16) :
    // 6 lignes de 31,2 px (le repli de « ★ » en ajoute jusqu'à 0,8 chacune
    // avec les polices réelles), la barre de 12 px et 3 écarts de 4 px.
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  reviews.title,
                  style: theme.label.copyWith(color: theme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${reviews.count} avis · $average ★',
                style: theme.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 4),
          _SplitBar(
            positive: reviews.positivePct,
            negative: reviews.negativePct,
          ),
          const SizedBox(height: 4),
          // Chaque pourcentage cède de la place à l'autre dans une cellule
          // étroite (3 × 2) au lieu de déborder.
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  '${reviews.positivePct} % positifs',
                  style: theme.body.copyWith(color: theme.okForeground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '${reviews.negativePct} % négatifs',
                  style: theme.body.copyWith(color: theme.blockingForeground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (reviews.comparison != null)
            comparisonLine(
              context,
              key: const Key('comparison-reviews'),
              text: reviews.comparison!,
            ),
          const SizedBox(height: 4),
          for (int i = 0; i < reviews.excerpts.length; i++)
            _ExcerptRow(
              key: Key('review-excerpt-$i'),
              excerpt: reviews.excerpts[i],
            ),
        ],
      ),
    );
  }
}

/// Barre de répartition : part positive, part négative, reste neutre.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.positive, required this.negative});

  final int positive;
  final int negative;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final int pos = positive.clamp(0, 100);
    final int neg = negative.clamp(0, 100 - pos);
    final int rest = 100 - pos - neg;
    Widget part(int flex, Color color) => flex == 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: flex,
            child: ColoredBox(color: color),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        key: const Key('review-split-bar'),
        height: 12,
        child: Row(
          children: <Widget>[
            part(pos, theme.okForeground),
            part(rest, theme.neutralBackground),
            part(neg, theme.blockingForeground),
          ],
        ),
      ),
    );
  }
}

class _ExcerptRow extends StatelessWidget {
  const _ExcerptRow({super.key, required this.excerpt});

  final _Excerpt excerpt;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Row(
      children: <Widget>[
        Text(
          '${excerpt.stars}★ ${excerpt.platform}',
          style: theme.body.copyWith(color: theme.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            excerpt.text,
            style: theme.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
