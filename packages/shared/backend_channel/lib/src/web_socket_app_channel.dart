import 'dart:async';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'app_channel.dart';
import 'app_channel_envelope.dart';

/// [AppChannel] sur `web_socket_channel` (`dart:io`, pas de web).
///
/// L'URL se déduit de [baseUrl] (`http` vers `ws`, `https` vers `wss`),
/// chemin `/app`, requête `?session=<id>`. Aucun en-tête `Origin` n'est
/// envoyé, et l'hôte de [baseUrl] est utilisé tel quel : le backend répond
/// 421 à un autre hôte que `127.0.0.1`.
///
/// [baseUrl] doit être une origine (schéma, hôte, port) : ni chemin autre
/// que `/`, ni requête, ni fragment (sinon [ArgumentError]).
class WebSocketAppChannel implements AppChannel {
  WebSocketAppChannel({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 5),
    this.closeTimeout = const Duration(seconds: 2),
    this.onInvalid,
  });

  /// Origine du backend (valeur de `GENESIS_BACKEND_URL`).
  final Uri baseUrl;

  /// Délai maximal d'établissement de la connexion.
  final Duration connectTimeout;

  /// Délai maximal de la fermeture de la socket (au-delà, on abandonne).
  final Duration closeTimeout;

  /// Appelé pour chaque enveloppe invalide, ignorée (jamais fatale).
  final void Function(AppChannelFormatException)? onInvalid;

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  /// URL WSS du canal de [sessionId] pour [baseUrl].
  ///
  /// Lève [ArgumentError] (sans la valeur) si [baseUrl] n'est pas une
  /// origine.
  static Uri endpointFor(Uri baseUrl, String sessionId) {
    if ((baseUrl.path.isNotEmpty && baseUrl.path != '/') ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment) {
      throw ArgumentError.value(
        'baseUrl',
        'baseUrl',
        'doit être une origine (sans chemin, requête ni fragment)',
      );
    }
    return Uri(
      scheme: baseUrl.scheme == 'https' ? 'wss' : 'ws',
      host: baseUrl.host,
      port: baseUrl.hasPort ? baseUrl.port : null,
      path: '/app',
      queryParameters: <String, String>{'session': sessionId},
    );
  }

  @override
  Stream<AppChannelEnvelope> open(String sessionId) {
    if (!_idPattern.hasMatch(sessionId)) {
      throw ArgumentError.value(
        sessionId.length,
        'sessionId',
        "identifiant de session invalide (longueur d'origine indiquée)",
      );
    }
    final uri = endpointFor(baseUrl, sessionId);

    late final StreamController<AppChannelEnvelope> controller;
    WebSocketChannel? socket;
    StreamSubscription<Object?>? subscription;
    var cancelled = false;

    Future<void> closeSocket() async {
      final current = socket;
      socket = null;
      if (current == null) return;
      try {
        await current.sink.close(1000).timeout(closeTimeout);
      } on Object {
        // Fermeture bornée : un échec ici n'est plus exploitable.
      }
    }

    void fail(AppChannelFailureKind kind) {
      if (controller.isClosed) return;
      controller
        ..addError(AppChannelFailure(kind))
        ..close();
    }

    Future<void> start() async {
      final WebSocketChannel connected;
      try {
        connected = IOWebSocketChannel.connect(
          uri,
          connectTimeout: connectTimeout,
        );
        await connected.ready;
      } on Object catch (error) {
        if (!cancelled) fail(_connectFailure(error));
        return;
      }
      socket = connected;
      if (cancelled) {
        await closeSocket();
        return;
      }
      subscription = connected.stream.listen(
        (Object? message) {
          if (message is! String) return;
          try {
            controller.add(AppChannelEnvelope.parse(message));
          } on AppChannelFormatException catch (error) {
            onInvalid?.call(error);
          }
        },
        onError: (Object _) => fail(AppChannelFailureKind.connectionLost),
        onDone: () {
          switch (connected.closeCode) {
            case 1000:
              if (!controller.isClosed) controller.close();
            case 1008:
              fail(AppChannelFailureKind.tooSlow);
            default:
              fail(AppChannelFailureKind.connectionLost);
          }
        },
      );
    }

    controller = StreamController<AppChannelEnvelope>(
      onListen: () => unawaited(start()),
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        cancelled = true;
        await subscription?.cancel();
        await closeSocket();
      },
    );
    return controller.stream;
  }

  /// Le statut HTTP d'un refus de mise à niveau n'est exposé que dans le
  /// message de l'exception (`... HTTP status code: 404`) ; on n'en extrait
  /// que le code, jamais l'URL qui l'accompagne.
  static final RegExp _statusPattern = RegExp(r'HTTP status code: (\d{3})');

  static AppChannelFailureKind _connectFailure(Object error) {
    final status = _statusPattern.firstMatch('$error')?.group(1);
    return switch (status) {
      '404' => AppChannelFailureKind.sessionNotFound,
      '421' => AppChannelFailureKind.hostRejected,
      '400' => AppChannelFailureKind.badRequest,
      _ => AppChannelFailureKind.unreachable,
    };
  }
}
