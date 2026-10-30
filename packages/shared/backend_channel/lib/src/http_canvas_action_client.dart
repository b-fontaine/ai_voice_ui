import 'dart:convert';

import 'package:http/http.dart' as http;

import 'canvas_action_client.dart';
import 'json_post_transport.dart';

/// [CanvasActionClient] sur HTTP (`package:http`).
///
/// `POST {baseUrl}/canvas/actions`, `Content-Type: application/json`, corps
/// `{"action":…,"surface":…}`. Aucun en-tête `Origin` n'est envoyé : le
/// backend refuse (403) toute requête qui en porte un. Un seul essai par appel.
/// Le client `http` injecté appartient à l'appelant : [close] ne ferme que
/// celui créé ici.
///
/// [baseUrl] doit être une origine (schéma, hôte, port) : ni chemin autre
/// que `/`, ni requête, ni fragment (sinon [ArgumentError]).
class HttpCanvasActionClient implements CanvasActionClient {
  HttpCanvasActionClient({
    required Uri baseUrl,
    required Duration timeout,
    http.Client? client,
  }) : _transport = JsonPostTransport(
         baseUrl: baseUrl,
         timeout: timeout,
         client: client,
       );

  final JsonPostTransport _transport;

  /// Origine du backend (valeur de `GENESIS_BACKEND_URL`).
  Uri get baseUrl => _transport.baseUrl;

  /// Délai maximal de la requête (envoi et lecture de la réponse).
  ///
  /// `Future.timeout` n'annule pas la requête HTTP en vol : un 202 reçu après
  /// le délai est classé [CanvasActionResult.failed] côté app alors que le
  /// backend a accepté l'action.
  Duration get timeout => _transport.timeout;

  /// Taille maximale lue dans un corps de réponse : le backend n'en envoie
  /// qu'un minuscule.
  static const int _maxBodyBytes = 1024;

  /// Ferme le client `http` s'il a été créé par cette instance. Les appels
  /// suivants de [send] renvoient [CanvasActionResult.failed].
  void close() => _transport.close();

  @override
  Future<CanvasActionResult> send({
    required String action,
    required String surface,
  }) async {
    if (_transport.isClosed) return CanvasActionResult.failed;
    try {
      return await _transport.post<CanvasActionResult>(
        '/canvas/actions',
        jsonEncode(<String, String>{'action': action, 'surface': surface}),
        (response) async {
          final bytes = <int>[];
          // Le corps est lu (borné) puis vidé pour libérer la connexion.
          await for (final chunk in response.stream) {
            if (bytes.length < _maxBodyBytes) bytes.addAll(chunk);
          }
          return _classify(response.statusCode, bytes);
        },
      );
    } on Object {
      // Réseau, délai, TLS, client fermé : le contrat du port ne lève jamais
      // et le message d'origine contient l'URL.
      return CanvasActionResult.failed;
    }
  }

  static CanvasActionResult _classify(int status, List<int> body) =>
      switch (status) {
        202 => CanvasActionResult.accepted,
        409 => _conflict(body),
        400 || 403 || 413 || 415 || 421 || 422 => CanvasActionResult.rejected,
        _ => CanvasActionResult.failed,
      };

  static CanvasActionResult _conflict(List<int> body) {
    try {
      final decoded = jsonDecode(utf8.decode(body));
      if (decoded is Map) {
        return switch (decoded['error']) {
          'busy' => CanvasActionResult.busy,
          'no_session' => CanvasActionResult.noSession,
          _ => CanvasActionResult.failed,
        };
      }
    } on FormatException {
      // Corps illisible : traité comme un échec.
    }
    return CanvasActionResult.failed;
  }
}
