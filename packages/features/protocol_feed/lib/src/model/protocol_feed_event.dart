import 'package:entity_catalog/entity_catalog.dart';

/// Events de `ProtocolFeedBloc`.
sealed class ProtocolFeedEvent {
  const ProtocolFeedEvent();
}

/// Branche le Bloc sur une source de messages validés (remplace la précédente).
final class ProtocolSourceSubscribed extends ProtocolFeedEvent {
  const ProtocolSourceSubscribed(this.envelopes);

  final Stream<ValidatedEnvelope> envelopes;
}

/// Commande : remise à vide (état initial : replié, sans entrée).
final class ProtocolFeedCleared extends ProtocolFeedEvent {
  const ProtocolFeedCleared();
}

/// Commande : replie ou déplie le panneau.
final class PanelToggled extends ProtocolFeedEvent {
  const PanelToggled();
}
