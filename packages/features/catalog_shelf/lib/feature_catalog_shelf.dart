/// API publique de feature_catalog_shelf : étagère du catalogue (FR-06).
library;

export 'src/model/catalog_shelf_bloc.dart' show CatalogShelfBloc;
export 'src/model/catalog_shelf_event.dart'
    show CatalogShelfCleared, CatalogShelfEvent, CatalogShelfSourceSubscribed;
export 'src/model/catalog_shelf_state.dart'
    show CatalogShelfState, ShelfComponent;
