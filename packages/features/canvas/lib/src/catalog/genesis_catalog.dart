import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:genui/genui.dart' show Catalog, CatalogItem;

import 'action_bar.dart';
import 'key_indicator.dart';
import 'release_checklist.dart';
import 'review_sentiment.dart';
import 'trend_chart.dart';

/// Catalogue fermé `genesis` (pdr-0053) : les 5 composants validés.
/// `CrashList` n'a pas de schéma et reste hors catalogue.
///
/// [catalogId] vient de la configuration de l'app (`GENESIS_CATALOG_ID`).
Catalog genesisCatalog({String catalogId = GenesisContract.defaultCatalogId}) =>
    Catalog(<CatalogItem>[
      keyIndicatorItem,
      trendChartItem,
      reviewSentimentItem,
      releaseChecklistItem,
      actionBarItem,
    ], catalogId: catalogId);
