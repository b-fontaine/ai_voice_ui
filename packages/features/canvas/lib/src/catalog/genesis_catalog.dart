import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:genui/genui.dart' show Catalog, CatalogItem;

import 'action_bar.dart';
import 'crash_list.dart';
import 'key_indicator.dart';
import 'release_checklist.dart';
import 'review_sentiment.dart';
import 'trend_chart.dart';

/// Catalogue fermé `genesis` (pdr-0053) : les 6 composants du contrat, dans
/// l'ordre de `GenesisContract.components`.
///
/// [catalogId] vient de la configuration de l'app (`GENESIS_CATALOG_ID`).
Catalog genesisCatalog({String catalogId = GenesisContract.defaultCatalogId}) =>
    Catalog(<CatalogItem>[
      keyIndicatorItem,
      trendChartItem,
      reviewSentimentItem,
      releaseChecklistItem,
      actionBarItem,
      crashListItem,
    ], catalogId: catalogId);
