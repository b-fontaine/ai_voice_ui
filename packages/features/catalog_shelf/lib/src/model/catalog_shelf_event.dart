import 'package:entity_catalog/entity_catalog.dart';

/// Events de `CatalogShelfBloc`.
sealed class CatalogShelfEvent {
  const CatalogShelfEvent();
}

/// Branche le Bloc sur une source de messages validés (remplace la précédente).
final class CatalogShelfSourceSubscribed extends CatalogShelfEvent {
  const CatalogShelfSourceSubscribed(this.envelopes);

  final Stream<ValidatedEnvelope> envelopes;
}

/// Commande : éteint tous les composants.
final class CatalogShelfCleared extends CatalogShelfEvent {
  const CatalogShelfCleared();
}
