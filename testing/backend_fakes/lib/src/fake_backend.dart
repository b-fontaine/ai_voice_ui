import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'contract_fixtures.dart';

/// Comportement de `POST /voice/sessions`.
enum PostMode {
  /// 200, answer SDP factice et en-tête `X-Session-Id`.
  ok,

  /// 429 avec `Retry-After`.
  rateLimited,

  /// 502 `{error}` opaque.
  badGateway,

  /// 415 (type de contenu refusé).
  unsupportedMediaType,

  /// 200 avec answer, mais sans en-tête `X-Session-Id`.
  missingSessionId,

  /// 200 avec `X-Session-Id` et une answer de plus de 128 Kio.
  oversizedAnswer,
}

/// Temps de fabrication d'une surface (RG-02) : chaque temps correspond à un
/// message du contrat, dans l'ordre.
enum SurfaceStage {
  /// `createSurface` : l'app peint le squelette.
  skeleton,

  /// `updateComponents` : les composants, sans données.
  components,

  /// `updateDataModel` : les données.
  data,
}

/// Faux backend de Genesis Canvas : un vrai serveur `dart:io` (HTTP et
/// WebSocket) sur `127.0.0.1`, port éphémère. Seule la frontière réseau est
/// réelle ; le fournisseur de voix (OpenAI) n'existe pas.
///
/// Il imite le contrat v1 (`product/architecture/app-channel-contract.md`) :
/// - `POST /voice/sessions` (corps `application/sdp`) ;
/// - `DELETE /voice/sessions/{id}` ;
/// - `GET /app?session=<id>` (WebSocket), backlog rejoué à la connexion
///   (50 messages au plus, `orb.level` jamais rejoué), 404 si la session est
///   inconnue, 400 si l'identifiant est invalide ;
/// - 421 si l'en-tête `Host` n'est pas `127.0.0.1`.
///
/// Dans un `testWidgets`, créer et piloter ce serveur depuis
/// `tester.runAsync` : les sockets réels ne tournent pas dans la zone
/// `FakeAsync`.
class FakeBackend {
  FakeBackend._(this._server, this.port, this.onEvent);

  /// Réponse SDP fournie par le relais.
  static const String answerSdp =
      'v=0\r\no=fake-relay 0 0 IN IP4 127.0.0.1\r\n';

  /// Fixture versionnée : enveloppes réelles d'une phrase → une surface
  /// (voir `lib/fixtures/session_act1.jsonl`, `{session}` est remplacé).
  /// Elle est résolue par URI de paquet, donc indépendamment du répertoire
  /// courant du test.
  static const String fixtureUri =
      'package:testing_backend_fakes/fixtures/session_act1.jsonl';

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static const int _backlogLimit = 50;

  /// Démarre le serveur. [onEvent] reçoit une ligne par événement serveur
  /// (`relay POST sess-1`, `relay DELETE sess-1`, `app connect sess-1`…),
  /// ce qui permet à un test de vérifier un ordre entre le backend et un
  /// autre acteur (par exemple le transport).
  static Future<FakeBackend> start({
    void Function(String event)? onEvent,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final backend = FakeBackend._(server, server.port, onEvent);
    backend._listen(server);
    return backend;
  }

  HttpServer? _server;

  /// Port d'écoute, conservé quand le serveur est coupé puis rétabli.
  final int port;
  final void Function(String event)? onEvent;

  // Injection.
  PostMode postMode = PostMode.ok;
  int retryAfterSeconds = 30;

  /// Valeur brute de `Retry-After` (prioritaire sur [retryAfterSeconds]),
  /// par exemple illisible ; `null` : [retryAfterSeconds].
  String? retryAfterRaw;

  /// `false` : la réponse 429 n'a pas d'en-tête `Retry-After`.
  bool sendRetryAfter = true;

  /// Délai avant toute réponse à `POST` (simule un relais qui ne répond pas).
  Duration postDelay = Duration.zero;

  /// Statut de `DELETE` pour une session connue ; `null` : 204 (404 si la
  /// session est inconnue).
  int? deleteStatus;

  /// Statut forcé pour le refus de `GET /app` (avant la mise à niveau
  /// WebSocket), par exemple 400 ; `null` : comportement normal.
  int? appRejectStatus;

  /// Identifiant de catalogue substitué à `${CATALOG_ID}` dans les fixtures
  /// du contrat (défaut : celui de la configuration).
  String catalogId = ContractFixtures.defaultCatalogId;

  /// Délai avant la réponse à `DELETE`.
  Duration deleteDelay = Duration.zero;

  // Enregistrements.
  final List<String> offers = <String>[];
  final List<String?> offerContentTypes = <String?>[];
  final List<String> deletes = <String>[];
  final List<String> appConnections = <String>[];
  final List<String?> appOrigins = <String?>[];
  final List<String> events = <String>[];

  final Map<String, int> _requestsByPath = <String, int>{};

  /// Nombre de requêtes HTTP reçues, toutes confondues : succès, refus (421,
  /// 415, 429, 404…) et chemins inconnus compris. Les connexions WebSocket
  /// (`GET /app`, y compris refusées avant la mise à niveau) ne sont **pas**
  /// comptées : ce sont des connexions, suivies par [appConnections]. Sert à
  /// vérifier qu'une action (p. ex. le rejeu) n'a touché le backend en rien.
  int get requestCount =>
      _requestsByPath.values.fold(0, (total, count) => total + count);

  /// Nombre de requêtes HTTP reçues sur [path] (même périmètre que
  /// [requestCount]).
  int requestCountFor(String path) => _requestsByPath[path] ?? 0;

  /// Remet à zéro [requestCount] et les compteurs par chemin.
  void resetRequestCounts() => _requestsByPath.clear();

  /// Nombre de requêtes `POST /canvas/reset` reçues.
  int canvasResets = 0;

  /// Corps bruts des requêtes `POST /canvas/actions` reçues (pdr-0065, D1),
  /// dans l'ordre d'arrivée, refusées comprises.
  final List<String> canvasActionBodies = <String>[];

  /// Statuts forcés pour les prochaines requêtes `POST /canvas/actions`,
  /// consommés dans l'ordre (par exemple `[409, 202]`) ; vide : 202. Un 409
  /// répond `{"error":"busy"}`.
  final List<int> canvasActionStatuses = <int>[];

  /// `true` : une action acceptée (202) déclenche seule la séquence de l'acte
  /// 3 ([emitGenesisActionStart], attente de [actionWorkDuration], puis
  /// [emitGenesisActionResult]), comme le vrai orchestrateur. `false` : le
  /// test pilote chaque temps.
  bool actionAutoRun = true;

  /// Durée du travail de l'agent entre `working` et le résultat, en temps réel.
  Duration actionWorkDuration = const Duration(milliseconds: 400);

  final List<String> _sessions = <String>[];

  /// Surfaces actives par session, déduites des messages `a2ui` publiés.
  final Map<String, Set<String>> _activeSurfaces = <String, Set<String>>{};
  final List<_Published> _backlog = <_Published>[];
  final List<_Client> _clients = <_Client>[];
  int _counter = 0;

  /// URL de base (valeur de `GENESIS_BACKEND_URL`).
  String get url => 'http://127.0.0.1:$port';

  bool get isListening => _server != null;

  /// Identifiant de la dernière session créée par `POST`, ou `null`.
  String? get lastSessionId => _sessions.isEmpty ? null : _sessions.last;

  List<String> get sessions => List<String>.unmodifiable(_sessions);

  /// Nombre de clients WebSocket actuellement connectés à [sessionId].
  int appClientCount(String sessionId) =>
      _clients.where((c) => c.session == sessionId).length;

  /// Charge la fixture, avec [session] à la place de `{session}`.
  static Future<List<Map<String, Object?>>> fixtureEnvelopes(
    String session,
  ) async {
    final file = File.fromUri(await _resolveFixture());
    return (await file.readAsLines()).where((l) => l.trim().isNotEmpty).map((
      line,
    ) {
      final decoded = jsonDecode(line.replaceAll('{session}', session));
      return Map<String, Object?>.from(decoded as Map);
    }).toList();
  }

  /// Résout [fixtureUri] par paquet (voir [ContractFixtures.resolvePackageFile]).
  static Future<Uri> _resolveFixture() =>
      ContractFixtures.resolvePackageFile(fixtureUri);

  /// Publie une enveloppe `{v:1,type,session,t_ms,data,agent?,task?}`.
  void emit(
    String session,
    String type,
    Map<String, Object?> data, {
    int tMs = 0,
    String? agent,
    String? task,
  }) => emitEnvelope(<String, Object?>{
    'v': 1,
    'type': type,
    'session': session,
    't_ms': tMs,
    'data': data,
    'agent': ?agent,
    'task': ?task,
  });

  /// Publie une enveloppe déjà construite (par exemple issue de la fixture).
  void emitEnvelope(Map<String, Object?> envelope) {
    final session = envelope['session'] as String;
    final published = _Published(
      session,
      envelope['type'] as String,
      jsonEncode(envelope),
    );
    if (published.type == 'a2ui') _trackSurface(session, envelope['data']);
    if (published.type != 'orb.level') {
      _backlog.add(published);
    }
    for (final client in _clients.where((c) => c.accepts(session))) {
      client.socket.add(published.json);
    }
  }

  /// Publie la session de l'acte 1 construite depuis les exemples du contrat
  /// (`contracts/a2ui/genesis/v1/examples/act1-*.jsonl`, [catalogId]
  /// substitué) : `plan`, `agent.activity working` ×3, les messages `a2ui` des
  /// quatre surfaces (trois temps chacune), puis `agent.activity completed` ×3.
  /// Les enveloppes `a2ui` portent `agent` et `task`.
  Future<void> emitGenesisAct1(String session) async {
    final surfaces = await ContractFixtures.act1Surfaces(catalogId: catalogId);
    emitGenesisPlan(session, selected: ContractFixtures.act1Agents);
    await emitGenesisActivity(session, 'working');
    for (final surface in surfaces) {
      await emitGenesisSurface(session, surface.surfaceId);
    }
    await emitGenesisActivity(session, 'completed');
  }

  /// Publie la phrase du speaker puis la délégation qu'elle déclenche
  /// ([delegation] : identifiant du tour, `deleg_2` pour l'acte 2).
  void emitGenesisUserPhrase(
    String session,
    String text, {
    String delegation = 'deleg_2',
  }) {
    emit(session, 'transcript', <String, Object?>{
      'role': 'user',
      'text': text,
      'start_ms': 300,
      'end_ms': 1200,
    }, tMs: 1200);
    emit(session, 'delegation', <String, Object?>{
      'id': delegation,
      'offset_ms': 1300,
    }, tMs: 1300);
  }

  /// Publie un tour de transformation (spec 008) construit depuis les exemples
  /// du contrat : `plan` des trois agents, `agent.activity working` ×3, un
  /// `updateDataModel` par surface (aucun `createSurface`, D1), puis
  /// `agent.activity completed` ×3. Les identifiants de tâche sont distincts
  /// de l'acte 1.
  ///
  /// Avec [withActions] (acte 2 de la spec 009, pdr-0065 D2), la tâche de
  /// Livraison crée en plus la surface `actions` (`createSurface`,
  /// `updateComponents`, `updateDataModel`) après la mutation de la checklist
  /// (A2) : le seul `createSurface` du tour est celui de `actions`.
  Future<void> emitGenesisFollowUp(
    String session,
    GenesisFollowUp followUp, {
    String delegation = 'deleg_2',
    bool withActions = false,
  }) async {
    final surfaces = await ContractFixtures.followUpSurfaces(
      followUp,
      catalogId: catalogId,
    );
    final tasks = <String, String>{for (final s in surfaces) s.agent: s.task};
    emitGenesisPlan(
      session,
      selected: ContractFixtures.act1Agents,
      delegation: delegation,
    );
    _emitActivities(session, 'working', tasks);
    for (var i = 0; i < surfaces.length; i++) {
      emit(
        session,
        'a2ui',
        surfaces[i].messages.single,
        tMs: 3500 + i * 50,
        agent: surfaces[i].agent,
        task: surfaces[i].task,
      );
    }
    if (withActions) await emitGenesisActions(session);
    _emitActivities(session, 'completed', tasks);
  }

  /// Publie la surface `actions` de la fin de l'acte 2 (exemple
  /// `act2-actions.jsonl`) du temps [from] au temps [upTo] inclus. [data]
  /// remplace la valeur du modèle de données (cas hors contrat, état neutre).
  Future<void> emitGenesisActions(
    String session, {
    SurfaceStage from = SurfaceStage.skeleton,
    SurfaceStage upTo = SurfaceStage.data,
    Object? data,
  }) async {
    final messages = await ContractFixtures.actionsMessages(
      catalogId: catalogId,
    );
    for (var i = from.index; i <= upTo.index; i++) {
      var message = messages[i];
      if (i == SurfaceStage.data.index && data != null) {
        final update = Map<String, Object?>.from(
          message['updateDataModel']! as Map,
        );
        update['value'] = data;
        message = <String, Object?>{...message, 'updateDataModel': update};
      }
      emit(
        session,
        'a2ui',
        message,
        tMs: 3500 + i * 50,
        agent: ContractFixtures.actionAgent,
        task: ContractFixtures.act2ActionsTask,
      );
    }
  }

  /// Début de l'acte 3 : `plan` où Livraison est seul retenu (les deux autres
  /// agents en veille), puis `agent.activity working` de Livraison. L'identifiant
  /// d'opération `act-1` n'est pas celui d'une délégation du fournisseur.
  Future<void> emitGenesisActionStart(String session) async {
    emitGenesisPlan(
      session,
      selected: <String>[ContractFixtures.actionAgent],
      delegation: 'act-1',
    );
    _emitActivities(
      session,
      'working',
      <String, String>{ContractFixtures.actionAgent: ContractFixtures.act3Task},
      agents: <String>[ContractFixtures.actionAgent],
    );
  }

  /// Fin de l'acte 3 : le résultat de l'action [action] (`updateDataModel` de
  /// sous-chemin des exemples `act3-*`), puis `agent.activity completed`.
  Future<void> emitGenesisActionResult(String session, String action) async {
    final messages = await ContractFixtures.actionResultMessages(
      action,
      catalogId: catalogId,
    );
    for (final message in messages) {
      emit(
        session,
        'a2ui',
        message,
        tMs: 4000,
        agent: ContractFixtures.actionAgent,
        task: ContractFixtures.act3Task,
      );
    }
    _emitActivities(
      session,
      'completed',
      <String, String>{ContractFixtures.actionAgent: ContractFixtures.act3Task},
      agents: <String>[ContractFixtures.actionAgent],
    );
  }

  void _emitActivities(
    String session,
    String state,
    Map<String, String> tasks, {
    List<String>? agents,
  }) {
    for (final agent in agents ?? ContractFixtures.act1Agents) {
      emit(
        session,
        'agent.activity',
        <String, Object?>{
          'agent': agent,
          'task': tasks[agent],
          'state': state,
          'label': agent,
        },
        tMs: 2050,
        agent: agent,
        task: tasks[agent],
      );
    }
  }

  /// Publie l'enveloppe `plan` de l'orchestrateur : [selected] retenus et
  /// [idle] en veille (par défaut, les autres agents de l'acte 1).
  void emitGenesisPlan(
    String session, {
    required List<String> selected,
    List<String>? idle,
    String delegation = 'deleg_1',
  }) => emit(session, 'plan', <String, Object?>{
    'delegation': delegation,
    'selected': selected,
    'idle':
        idle ??
        ContractFixtures.act1Agents
            .where((a) => !selected.contains(a))
            .toList(),
  }, tMs: 2000);

  /// Publie `agent.activity` ([state] : `working`, `completed`…) pour chacun
  /// des [agents] (par défaut les trois agents de l'acte 1).
  Future<void> emitGenesisActivity(
    String session,
    String state, {
    List<String>? agents,
  }) async {
    final surfaces = await ContractFixtures.act1Surfaces(catalogId: catalogId);
    final tasks = <String, String>{for (final s in surfaces) s.agent: s.task};
    _emitActivities(session, state, tasks, agents: agents);
  }

  /// Publie les messages `a2ui` de la surface [surfaceId] de l'acte 1, du temps
  /// [from] au temps [upTo] inclus (par défaut les trois temps). Permet de
  /// montrer le squelette avant les composants, puis les données.
  Future<void> emitGenesisSurface(
    String session,
    String surfaceId, {
    SurfaceStage from = SurfaceStage.skeleton,
    SurfaceStage upTo = SurfaceStage.data,
  }) async {
    final surfaces = await ContractFixtures.act1Surfaces(catalogId: catalogId);
    final surface = surfaces.firstWhere(
      (s) => s.surfaceId == surfaceId,
      orElse: () => throw ArgumentError('Surface inconnue : $surfaceId'),
    );
    for (var i = from.index; i <= upTo.index; i++) {
      emit(
        session,
        'a2ui',
        surface.messages[i],
        tMs: 3500 + i * 50,
        agent: surface.agent,
        task: surface.task,
      );
    }
  }

  /// Publie une fixture négative du contrat (`invalid/<name>.jsonl`) : les
  /// messages que le client doit refuser (pdr-0053).
  Future<void> emitGenesisInvalid(
    String session,
    String name, {
    String agent = 'Qualité',
    String task = 'task_1',
  }) async {
    final messages = await ContractFixtures.invalidMessages(
      name,
      catalogId: catalogId,
    );
    for (final message in messages) {
      emit(session, 'a2ui', message, tMs: 3500, agent: agent, task: task);
    }
  }

  void _trackSurface(String session, Object? data) {
    if (data is! Map) return;
    final active = _activeSurfaces.putIfAbsent(session, () => <String>{});
    final create = data['createSurface'];
    if (create is Map) active.add(create['surfaceId'] as String);
    final delete = data['deleteSurface'];
    if (delete is Map) active.remove(delete['surfaceId']);
  }

  /// Publie [text] tel quel (même invalide) aux clients de [session] : pour
  /// tester le rejet d'une enveloppe illisible. Jamais mis en backlog.
  void emitRaw(String session, String text) {
    for (final client in _clients.where((c) => c.accepts(session))) {
      client.socket.add(text);
    }
  }

  /// Ferme proprement (ou avec [code]) tous les clients WebSocket de la
  /// session : coupure du canal, vue de l'app comme une perte de connexion.
  Future<void> closeApp(
    String session, {
    int code = WebSocketStatus.normalClosure,
  }) async {
    final targets = _clients.where((c) => c.session == session).toList();
    await Future.wait(targets.map((c) => c.socket.close(code)));
  }

  /// Coupe le serveur : les connexions suivantes sont refusées (injoignable).
  Future<void> stopListening() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
    _clients.clear();
    _record('server down');
  }

  /// Rétablit le serveur sur le même port.
  Future<void> resume() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    _listen(server);
    _record('server up');
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
    for (final client in List<_Client>.of(_clients)) {
      await client.socket.close();
    }
    _clients.clear();
  }

  void _record(String event) {
    events.add(event);
    onEvent?.call(event);
  }

  void _listen(HttpServer server) {
    server.listen((request) => unawaited(_handle(request)));
  }

  Future<void> _handle(HttpRequest request) async {
    if (!(request.method == 'GET' && request.uri.path == '/app')) {
      _requestsByPath.update(
        request.uri.path,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    if (request.headers.host != '127.0.0.1') {
      return _json(
        request.response,
        HttpStatus.misdirectedRequest,
        <String, Object?>{'error': 'host'},
      );
    }
    final path = request.uri.path;
    if (request.method == 'POST' && path == '/voice/sessions') {
      return _post(request);
    }
    if (request.method == 'DELETE' && path.startsWith('/voice/sessions/')) {
      return _delete(request, path.substring('/voice/sessions/'.length));
    }
    if (request.method == 'POST' && path == '/canvas/reset') {
      return _canvasReset(request);
    }
    if (request.method == 'POST' && path == '/canvas/actions') {
      return _canvasAction(request);
    }
    if (request.method == 'GET' && path == '/healthz') {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('ok');
      return request.response.close();
    }
    if (request.method == 'GET' && path == '/app') {
      return _app(request);
    }
    return _json(request.response, HttpStatus.notFound, <String, Object?>{
      'error': 'not found',
    });
  }

  Future<void> _post(HttpRequest request) async {
    final response = request.response;
    final contentType = request.headers.contentType?.mimeType;
    final body = await utf8.decoder.bind(request).join();
    if (postDelay > Duration.zero) await Future<void>.delayed(postDelay);
    switch (postMode) {
      case PostMode.rateLimited:
        if (sendRetryAfter) {
          response.headers.set(
            'Retry-After',
            retryAfterRaw ?? '$retryAfterSeconds',
          );
        }
        _record('relay POST 429');
        return _json(response, HttpStatus.tooManyRequests, <String, Object?>{
          'error': 'rate limited',
        });
      case PostMode.badGateway:
        _record('relay POST 502');
        return _json(response, HttpStatus.badGateway, <String, Object?>{
          'error': 'upstream',
        });
      case PostMode.unsupportedMediaType:
        _record('relay POST 415');
        return _json(
          response,
          HttpStatus.unsupportedMediaType,
          <String, Object?>{'error': 'content-type'},
        );
      case PostMode.ok:
      case PostMode.missingSessionId:
      case PostMode.oversizedAnswer:
        break;
    }
    if (contentType != 'application/sdp') {
      return _json(response, HttpStatus.unsupportedMediaType, <String, Object?>{
        'error': 'content-type',
      });
    }
    if (body.trim().isEmpty) {
      return _json(response, HttpStatus.badRequest, <String, Object?>{
        'error': 'empty offer',
      });
    }
    final id = 'sess-${++_counter}';
    _sessions.add(id);
    offers.add(body);
    offerContentTypes.add(contentType);
    _record('relay POST $id');
    // `connecting` avant l'answer, `active` une fois le sideband attaché :
    // publiés avant la connexion du WSS, ils arrivent par le backlog.
    emit(id, 'session.state', <String, Object?>{'state': 'connecting'});
    emit(id, 'session.state', <String, Object?>{'state': 'active'});
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('application', 'sdp');
    if (postMode != PostMode.missingSessionId) {
      response.headers.set('X-Session-Id', id);
    }
    response.write(
      postMode == PostMode.oversizedAnswer
          ? '$answerSdp${'a=x\r\n' * (130 * 1024 ~/ 5)}'
          : answerSdp,
    );
    await response.close();
  }

  /// `POST /canvas/reset` : compte la requête, répond 204, puis émet les
  /// `deleteSurface` de l'orchestrateur pour les surfaces actives de chaque
  /// session, dans l'ordre trié (comme le vrai backend, A4g).
  Future<void> _canvasReset(HttpRequest request) async {
    await request.drain<void>();
    canvasResets++;
    _record('canvas reset');
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    for (final session in List<String>.of(_sessions)) {
      final surfaces = (_activeSurfaces[session] ?? <String>{}).toList()
        ..sort();
      for (final id in surfaces) {
        emit(session, 'a2ui', <String, Object?>{
          'version': 'v0.9',
          'deleteSurface': <String, Object?>{'surfaceId': id},
        }, agent: 'orchestrateur');
      }
    }
  }

  /// `POST /canvas/actions` : journalise le corps, répond selon
  /// [canvasActionStatuses] (202 par défaut, 409 `busy`), puis, si
  /// [actionAutoRun], enchaîne la séquence de l'acte 3 sur la session la plus
  /// récente.
  Future<void> _canvasAction(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    canvasActionBodies.add(body);
    _record('canvas action $body');
    final status = canvasActionStatuses.isEmpty
        ? HttpStatus.accepted
        : canvasActionStatuses.removeAt(0);
    if (status != HttpStatus.accepted) {
      return _json(request.response, status, <String, Object?>{
        'error': status == HttpStatus.conflict ? 'busy' : 'refused',
      });
    }
    request.response.statusCode = HttpStatus.accepted;
    await request.response.close();
    final session = lastSessionId;
    if (!actionAutoRun || session == null) return;
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['action'] is! String) return;
    unawaited(_runAction(session, decoded['action']! as String));
  }

  Future<void> _runAction(String session, String action) async {
    try {
      await emitGenesisActionStart(session);
      await Future<void>.delayed(actionWorkDuration);
      await emitGenesisActionResult(session, action);
    } on Object catch (error) {
      _record('canvas action run abandoned: $error');
    }
  }

  Future<void> _delete(HttpRequest request, String id) async {
    if (deleteDelay > Duration.zero) await Future<void>.delayed(deleteDelay);
    deletes.add(id);
    _record('relay DELETE $id');
    final known = _sessions.contains(id);
    final status =
        deleteStatus ?? (known ? HttpStatus.noContent : HttpStatus.notFound);
    if (status == HttpStatus.noContent) {
      request.response.statusCode = status;
      return request.response.close();
    }
    return _json(request.response, status, <String, Object?>{
      'error': 'delete',
    });
  }

  Future<void> _app(HttpRequest request) async {
    final forced = appRejectStatus;
    if (forced != null) {
      return _json(request.response, forced, <String, Object?>{
        'error': 'forced',
      });
    }
    final filter = request.uri.queryParameters['session'];
    if (filter != null) {
      if (!_idPattern.hasMatch(filter)) {
        return _json(request.response, HttpStatus.badRequest, <String, Object?>{
          'error': 'session',
        });
      }
      if (!_sessions.contains(filter)) {
        _record('app 404 $filter');
        return _json(request.response, HttpStatus.notFound, <String, Object?>{
          'error': 'unknown session',
        });
      }
    }
    appOrigins.add(request.headers.value('origin'));
    final socket = await WebSocketTransformer.upgrade(request);
    final client = _Client(socket, filter);
    _clients.add(client);
    appConnections.add(filter ?? '*');
    _record('app connect ${filter ?? '*'}');
    // Backlog : derniers messages hors `orb.level`, dans l'ordre de publication.
    final replay = _backlog.where((p) => client.accepts(p.session)).toList();
    for (final p in replay.skip(
      replay.length > _backlogLimit ? replay.length - _backlogLimit : 0,
    )) {
      socket.add(p.json);
    }
    socket.listen(
      (_) {},
      onDone: () => _clients.remove(client),
      onError: (Object _) => _clients.remove(client),
    );
  }

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    return response.close();
  }
}

class _Published {
  _Published(this.session, this.type, this.json);
  final String session;
  final String type;
  final String json;
}

class _Client {
  _Client(this.socket, this.session);
  final WebSocket socket;

  /// Filtre `?session=` ; `null` : toutes les sessions.
  final String? session;

  bool accepts(String other) => session == null || session == other;
}
