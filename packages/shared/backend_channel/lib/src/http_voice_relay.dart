import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'voice_relay.dart';

/// [VoiceRelay] sur HTTP (`package:http`, `dart:io`).
///
/// `POST {baseUrl}/voice/sessions` (corps `application/sdp`) puis
/// `DELETE {baseUrl}/voice/sessions/{id}`. Le client `http` injecté
/// appartient à l'appelant : [close] ne ferme que celui créé ici.
class HttpVoiceRelay implements VoiceRelay {
  HttpVoiceRelay({
    required this.baseUrl,
    http.Client? client,
    this.createTimeout = const Duration(seconds: 20),
    this.deleteTimeout = const Duration(seconds: 7),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  /// URL de base du backend (valeur de `GENESIS_BACKEND_URL`).
  final Uri baseUrl;

  /// Délai maximal de `POST` (envoi de l'offre et lecture de l'answer).
  final Duration createTimeout;

  /// Délai maximal de `DELETE`.
  final Duration deleteTimeout;

  final http.Client _client;
  final bool _ownsClient;

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _secondsPattern = RegExp(r'^\d{1,9}$');

  /// Taille maximale de l'answer lue (128 Kio).
  static const int maxAnswerBytes = 128 * 1024;

  /// Ferme le client `http` s'il a été créé par cette instance.
  void close() {
    if (_ownsClient) _client.close();
  }

  Uri _sessionsUri([String? id]) {
    final base = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(
      path: '$base/voice/sessions${id == null ? '' : '/$id'}',
      query: '',
    );
  }

  @override
  Future<RelayAnswer> createSession(String offerSdp) async {
    final request = http.Request('POST', _sessionsUri())
      ..headers['Content-Type'] = 'application/sdp'
      ..bodyBytes = utf8.encode(offerSdp);
    final (response, body) = await _exchange(request, createTimeout);
    switch (response.statusCode) {
      case 200:
        final id = response.headers['x-session-id'];
        if (body == null || id == null || !_idPattern.hasMatch(id)) {
          throw const RelayFailure(RelayFailureKind.protocol);
        }
        final answer = utf8.decode(body, allowMalformed: true);
        if (answer.trim().isEmpty) {
          throw const RelayFailure(RelayFailureKind.protocol);
        }
        return RelayAnswer(answerSdp: answer, sessionId: id);
      case 429:
        throw RelayFailure(
          RelayFailureKind.rateLimited,
          retryAfter: _retryAfter(response.headers['retry-after']),
        );
      case 400 || 413 || 415:
        throw const RelayFailure(RelayFailureKind.badRequest);
      case >= 500 && < 600:
        throw const RelayFailure(RelayFailureKind.relayFailed);
      default:
        throw const RelayFailure(RelayFailureKind.protocol);
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (!_idPattern.hasMatch(sessionId)) {
      throw ArgumentError.value(
        sessionId.length,
        'sessionId',
        "identifiant de session invalide (longueur d'origine indiquée)",
      );
    }
    final request = http.Request('DELETE', _sessionsUri(sessionId));
    final (response, _) = await _exchange(request, deleteTimeout);
    switch (response.statusCode) {
      case 204:
        return;
      case 404:
        throw const RelayFailure(RelayFailureKind.sessionNotFound);
      case 504:
        throw const RelayFailure(RelayFailureKind.closeNotConfirmed);
      case 429:
        throw RelayFailure(
          RelayFailureKind.rateLimited,
          retryAfter: _retryAfter(response.headers['retry-after']),
        );
      case 400:
        throw const RelayFailure(RelayFailureKind.badRequest);
      case >= 500 && < 600:
        throw const RelayFailure(RelayFailureKind.relayFailed);
      default:
        throw const RelayFailure(RelayFailureKind.protocol);
    }
  }

  /// Envoie [request] et lit au plus [maxAnswerBytes] octets de corps ;
  /// `body` vaut `null` si la limite est dépassée. Traduit les erreurs
  /// réseau en [RelayFailure] (jamais de message d'origine : il contient
  /// l'URL).
  Future<(http.StreamedResponse, List<int>?)> _exchange(
    http.BaseRequest request,
    Duration timeout,
  ) async {
    try {
      return await Future<(http.StreamedResponse, List<int>?)>(() async {
        final response = await _client.send(request);
        final bytes = <int>[];
        var tooBig = false;
        final done = Completer<void>();
        late final StreamSubscription<List<int>> subscription;
        subscription = response.stream.listen(
          (chunk) {
            bytes.addAll(chunk);
            if (bytes.length > maxAnswerBytes) {
              tooBig = true;
              unawaited(subscription.cancel());
              if (!done.isCompleted) done.complete();
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!done.isCompleted) done.completeError(error, stack);
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
        await done.future;
        return (response, tooBig ? null : bytes);
      }).timeout(timeout);
    } on TimeoutException {
      throw const RelayFailure(RelayFailureKind.timeout);
    } on SocketException {
      throw const RelayFailure(RelayFailureKind.unreachable);
    } on http.ClientException {
      throw const RelayFailure(RelayFailureKind.unreachable);
    } on HandshakeException {
      throw const RelayFailure(RelayFailureKind.unreachable);
    }
  }

  /// `Retry-After` en secondes entières, borné à 1..3600 ; sinon `null`.
  static Duration? _retryAfter(String? raw) {
    final text = raw?.trim();
    if (text == null || !_secondsPattern.hasMatch(text)) return null;
    final seconds = int.parse(text);
    if (seconds < 1 || seconds > 3600) return null;
    return Duration(seconds: seconds);
  }
}
