import 'dart:async';

import 'package:http/http.dart' as http;

/// Transport interne de `POST` JSON vers l'origine du backend, partagé par
/// [HttpCanvasActionClient] et [HttpCanvasResetClient]. Privé au paquet :
/// non exporté par le barrel.
///
/// Aucun en-tête `Origin` n'est envoyé : le backend refuse (403) toute
/// requête qui en porte un. Le client `http` injecté appartient à
/// l'appelant : [close] ne ferme que celui créé ici.
class JsonPostTransport {
  /// Lève [ArgumentError] si [baseUrl] n'est pas une origine (schéma, hôte,
  /// port) : ni chemin autre que `/`, ni requête, ni fragment.
  JsonPostTransport({
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

  /// `true` après [close].
  bool get isClosed => _closed;

  /// Ferme le client `http` s'il a été créé par cette instance.
  void close() {
    _closed = true;
    if (_ownsClient) _client.close();
  }

  /// Envoie `POST {baseUrl}{path}` avec [body] (JSON) puis renvoie le
  /// résultat de [onResponse], qui doit consommer le flux de la réponse.
  ///
  /// Les erreurs (réseau, TLS, client fermé, [TimeoutException]) sont
  /// propagées : l'appelant les classe.
  ///
  /// Attention : `Future.timeout` ne fait que cesser d'attendre ; il
  /// n'annule pas la requête HTTP en vol. Un 202 reçu après le délai est donc
  /// classé en échec côté app alors que le backend a accepté la demande.
  Future<T> post<T>(
    String path,
    String body,
    Future<T> Function(http.StreamedResponse response) onResponse,
  ) {
    final request = http.Request('POST', _uri(path))
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    return Future<T>(() async {
      final response = await _client.send(request);
      return onResponse(response);
    }).timeout(timeout);
  }

  Uri _uri(String path) {
    final base = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(path: '$base$path', query: '');
  }
}
