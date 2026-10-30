import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'canvas_reset_client.dart';
import 'json_post_transport.dart';

/// [CanvasResetClient] sur HTTP (`package:http`, `dart:io`).
///
/// `POST {baseUrl}/canvas/reset`, `Content-Type: application/json`, corps
/// `{}`. Aucun en-tête `Origin` n'est envoyé : le backend refuse (403) toute
/// requête qui en porte un (A6). Le client `http` injecté appartient à
/// l'appelant : [close] ne ferme que celui créé ici.
///
/// [baseUrl] doit être une origine (schéma, hôte, port) : ni chemin autre
/// que `/`, ni requête, ni fragment (sinon [ArgumentError] à la
/// construction).
class HttpCanvasResetClient implements CanvasResetClient {
  HttpCanvasResetClient({
    required Uri baseUrl,
    required Duration timeout,
    http.Client? client,
    this.onError,
  }) : _transport = JsonPostTransport(
         baseUrl: baseUrl,
         timeout: timeout,
         client: client,
       );

  final JsonPostTransport _transport;

  /// Origine du backend (valeur de `GENESIS_BACKEND_URL`).
  Uri get baseUrl => _transport.baseUrl;

  /// Délai maximal de la requête (envoi et lecture de la réponse).
  Duration get timeout => _transport.timeout;

  /// Reçoit une phrase fermée à chaque échec (jamais l'URL ni le corps).
  /// Une exception levée par ce rappel est ignorée.
  final void Function(String reason)? onError;

  /// Ferme le client `http` s'il a été créé par cette instance. Les appels
  /// suivants de [reset] renvoient [CanvasResetResult.unreachable].
  void close() => _transport.close();

  @override
  Future<CanvasResetResult> reset() async {
    if (_transport.isClosed) return _fail(CanvasResetResult.unreachable);
    try {
      final status = await _transport.post<int>('/canvas/reset', '{}', (
        response,
      ) async {
        // Le corps n'est pas lu : on le vide pour libérer la connexion.
        await response.stream.drain<void>();
        return response.statusCode;
      });
      return switch (status) {
        204 => CanvasResetResult.done,
        409 => _fail(CanvasResetResult.busy),
        _ => _fail(CanvasResetResult.rejected),
      };
    } on TimeoutException {
      return _fail(CanvasResetResult.timeout);
    } on SocketException {
      return _fail(CanvasResetResult.unreachable);
    } on http.ClientException {
      return _fail(CanvasResetResult.unreachable);
    } on Object {
      // TLS, client fermé (StateError) : le contrat du port ne lève jamais,
      // et le message d'origine contient l'URL.
      return _fail(CanvasResetResult.unreachable);
    }
  }

  CanvasResetResult _fail(CanvasResetResult result) {
    final reason = switch (result) {
      CanvasResetResult.done => null,
      CanvasResetResult.busy =>
        'Remise à vide refusée : le backend est occupé.',
      CanvasResetResult.rejected => 'Remise à vide refusée par le backend.',
      CanvasResetResult.timeout => 'Remise à vide : délai dépassé.',
      CanvasResetResult.unreachable => 'Remise à vide : backend injoignable.',
    };
    if (reason != null) {
      try {
        onError?.call(reason);
      } on Object {
        // Un journal défaillant ne doit pas faire échouer la remise à vide.
      }
    }
    return result;
  }
}
