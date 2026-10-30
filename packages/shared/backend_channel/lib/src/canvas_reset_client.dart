/// Issue fermée d'une demande de remise à vide du backend.
///
/// [CanvasResetClient.reset] ne lève jamais : la remise à vide locale n'attend
/// pas le backend (échec silencieux pour l'appelant, journalisable).
enum CanvasResetResult {
  /// 204 : les surfaces actives ont été retirées côté backend.
  done,

  /// 409 : une délégation est en cours, rien n'a changé.
  busy,

  /// Backend injoignable (connexion refusée ou coupée, client fermé).
  unreachable,

  /// Autre réponse d'erreur (4xx, 5xx) ou réponse inattendue.
  rejected,

  /// Délai de la requête dépassé.
  timeout,
}

/// Port de la remise à vide du backend (`POST /canvas/reset`).
abstract interface class CanvasResetClient {
  /// Demande au backend de retirer les surfaces actives, au mieux.
  /// Ne lève jamais.
  Future<CanvasResetResult> reset();
}
