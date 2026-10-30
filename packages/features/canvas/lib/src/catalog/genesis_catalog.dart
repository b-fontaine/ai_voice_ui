import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:genui/genui.dart' show Catalog, CatalogItem;

import 'key_indicator.dart';
import 'release_checklist.dart';
import 'review_sentiment.dart';
import 'trend_chart.dart';

/// Catalogue fermé `genesis` (pdr-0053) : les 4 composants validés.
/// `ActionBar` et `CrashList` n'ont pas de schéma et restent hors catalogue.
///
/// [catalogId] vient de la configuration de l'app (`GENESIS_CATALOG_ID`).
Catalog genesisCatalog({String catalogId = GenesisContract.defaultCatalogId}) =>
    Catalog(<CatalogItem>[
      keyIndicatorItem,
      trendChartItem,
      reviewSentimentItem,
      releaseChecklistItem,
    ], catalogId: catalogId);
