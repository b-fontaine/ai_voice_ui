import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:genui/genui.dart' show Catalog, CatalogItem;

import 'key_indicator.dart';

/// Catalogue fermé `genesis` (pdr-0053). Pour l'instant : `KeyIndicator` ;
/// les trois autres composants arrivent avec T11.
///
/// [catalogId] vient de la configuration de l'app (`GENESIS_CATALOG_ID`).
Catalog genesisCatalog({String catalogId = GenesisContract.defaultCatalogId}) =>
    Catalog(<CatalogItem>[keyIndicatorItem], catalogId: catalogId);
