/// Issue fermée d'une demande d'action (`POST /canvas/actions`).
///
/// Aucun détail brut du backend n'y figure : l'appelant n'a besoin que de
/// savoir s'il doit réessayer, abandonner ou considérer l'action en cours.
enum CanvasActionResult {
  /// 202 : l'action est prise en charge, le travail de l'agent continue en
  /// arrière-plan.
  accepted,

  /// 409 `busy` : une délégation ou une autre action est en cours.
  busy,

  /// 409 `no_session` : aucune session voix ouverte pour porter l'action.
  noSession,

  /// 400, 403, 413, 415, 421 ou 422 : le backend refuse la demande ; la
  /// réémettre ne changerait rien.
  rejected,

  /// Réseau coupé, délai dépassé, 5xx, réponse inattendue ou illisible.
  failed,
}

/// Port de l'envoi d'une action utilisateur au backend.
abstract interface class CanvasActionClient {
  /// **Un seul essai** : le réessai relève de l'appelant. Ne lève jamais.
  Future<CanvasActionResult> send({
    required String action,
    required String surface,
  });
}
