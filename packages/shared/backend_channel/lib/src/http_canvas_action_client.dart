import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'canvas_action_client.dart';

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
    required this.baseUrl,
    required this.timeout,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    if ((baseUrl.path.isNotEmpty && baseUrl.path != '/') ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment) {
      throw ArgumentError.value(
        'baseUrl',
        'baseUrl',
        'doit être une origine (sans chemin, requête ni fragment)',
      );
    }
  }

  /// Origine du backend (valeur de `GENESIS_BACKEND_URL`).
  final Uri baseUrl;

  /// Délai maximal de la requête (envoi et lecture de la réponse).
  final Duration timeout;

  final http.Client _client;
  final bool _ownsClient;
  bool _closed = false;

  /// Taille maximale lue dans un corps de réponse : le backend n'en envoie
  /// qu'un minuscule.
  static const int _maxBodyBytes = 1024;

  /// Ferme le client `http` s'il a été créé par cette instance. Les appels
  /// suivants de [send] renvoient [CanvasActionResult.failed].
  void close() {
    _closed = true;
    if (_ownsClient) _client.close();
  }

  Uri get _actionsUri {
    final base = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(path: '$base/canvas/actions', query: '');
  }

  @override
  Future<CanvasActionResult> send({
    required String action,
    required String surface,
  }) async {
    if (_closed) return CanvasActionResult.failed;
    final request = http.Request('POST', _actionsUri)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(<String, String>{
        'action': action,
        'surface': surface,
      });
    try {
      return await Future<CanvasActionResult>(() async {
        final response = await _client.send(request);
        final bytes = <int>[];
        // Le corps est lu (borné) puis vidé pour libérer la connexion.
        await for (final chunk in response.stream) {
          if (bytes.length < _maxBodyBytes) bytes.addAll(chunk);
        }
        return _classify(response.statusCode, bytes);
      }).timeout(timeout);
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
