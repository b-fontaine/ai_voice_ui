import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;

/// Erreur de configuration de lancement. Le message nomme la variable
/// d'environnement fautive, jamais sa valeur (elle pourrait être sensible).
class GenesisConfigException implements Exception {
  const GenesisConfigException(this.message);

  /// Message en français, affiché sur stderr par `main`.
  final String message;

  @override
  String toString() => 'GenesisConfigException: $message';
}

/// Configuration de lancement de l'app, lue une fois dans `main()` puis
/// injectée par constructeur jusqu'à la page.
///
/// Aucune clé d'API ici : la clé OpenAI reste côté backend (AGENTS.md § 2).
///
/// **Invariant des délais de fermeture** (chaque niveau borne celui qu'il
/// enveloppe) : `sessionCloseTimeout > relayDeleteTimeout +
/// channelCloseTimeout` et `exitCloseTimeout > sessionCloseTimeout + 1 s`.
/// `relayDeleteTimeout` dépasse lui-même le `VOICE_CLOSE_GUARD` (5 s) du
/// backend. Ce sont des réglages, pas des décisions produit.
class GenesisConfig {
  const GenesisConfig({
    this.scenario,
    this.snapshotPath,
    Uri? backendUrl,
    String? catalogId,
    this.appLogPath,
    this.relayCreateTimeout = const Duration(seconds: 20),
    this.relayDeleteTimeout = const Duration(seconds: 7),
    this.channelConnectTimeout = const Duration(seconds: 5),
    this.channelCloseTimeout = const Duration(seconds: 2),
    this.sessionCloseTimeout = const Duration(seconds: 10),
    this.exitCloseTimeout = const Duration(seconds: 12),
    this.iceTimeout = const Duration(seconds: 10),
    Duration? canvasResetTimeout,
    int? canvasResetRetries,
    Duration? canvasResetRetryInterval,
    this.canvasActionTimeout = const Duration(seconds: 2),
    this.canvasActionRetries = 6,
    this.canvasActionRetryInterval = const Duration(seconds: 1),
    this.canvasActionMaxDuration = const Duration(seconds: 60),
    this.orbSilenceTimeout = const Duration(milliseconds: 600),
    this.orbAttack = const Duration(milliseconds: 80),
    this.orbRelease = const Duration(milliseconds: 250),
    this.orbSpeakingThreshold = 0.03,
    // Un paramètre nommé ne peut pas être un formel privé.
    // ignore: prefer_initializing_formals
  }) : _backendUrl = backendUrl,
       // ignore: prefer_initializing_formals
       _catalogId = catalogId,
       // ignore: prefer_initializing_formals
       _canvasResetTimeout = canvasResetTimeout,
       // ignore: prefer_initializing_formals
       _canvasResetRetries = canvasResetRetries,
       // ignore: prefer_initializing_formals
       _canvasResetRetryInterval = canvasResetRetryInterval;

  /// Construit la configuration à partir d'un environnement (en prod
  /// `Platform.environment`). Une variable absente ou vide vaut `null`
  /// (ou la valeur par défaut). Les constantes (délais, orbe) ne sont pas
  /// lues dans l'environnement, sauf `GENESIS_CANVAS_RESET_TIMEOUT_MS`,
  /// `GENESIS_CANVAS_RESET_RETRIES` et `GENESIS_CANVAS_RESET_RETRY_INTERVAL_MS`.
  ///
  /// Lève [GenesisConfigException] si `GENESIS_BACKEND_URL` ou
  /// `GENESIS_CATALOG_ID`, `GENESIS_CANVAS_RESET_TIMEOUT_MS`,
  /// `GENESIS_CANVAS_RESET_RETRIES` ou `GENESIS_CANVAS_RESET_RETRY_INTERVAL_MS`
  /// est invalide.
  factory GenesisConfig.fromEnvironment(Map<String, String> environment) =>
      GenesisConfig(
        scenario: _read(environment, 'GENESIS_SCENARIO'),
        snapshotPath: _read(environment, 'GENESIS_SNAPSHOT'),
        backendUrl: _readBackendUrl(environment),
        catalogId: _readCatalogId(environment),
        appLogPath: _read(environment, 'GENESIS_APP_LOG'),
        canvasResetTimeout: _readCanvasResetTimeout(environment),
        canvasResetRetries: _readCanvasResetRetries(environment),
        canvasResetRetryInterval: _readCanvasResetRetryInterval(environment),
      );

  static const String _backendUrlVariable = 'GENESIS_BACKEND_URL';

  /// URL du backend local par défaut.
  static final Uri defaultBackendUrl = Uri.parse('http://127.0.0.1:8080');

  /// Nom du rejeu `assets/replays/<scenario>.jsonl` ; `null` : canevas vide.
  final String? scenario;

  /// Chemin du PNG à écrire à la fin du rejeu ; `null` : pas de capture.
  final String? snapshotPath;

  // `Uri` n'a pas de constructeur const : la valeur par défaut est portée
  // par le getter, ce qui garde `const GenesisConfig()` possible.
  final Uri? _backendUrl;

  /// URL de base du backend (`GENESIS_BACKEND_URL`).
  Uri get backendUrl => _backendUrl ?? defaultBackendUrl;

  // Comme l'URL du backend : la valeur par défaut est portée par le getter.
  final String? _catalogId;

  /// Identifiant du catalogue A2UI (`GENESIS_CATALOG_ID`), passé au catalogue
  /// de l'app et au validateur. Le défaut est celui du backend
  /// (`A2UI_CATALOG_ID` de `docker-compose.yaml`).
  String get catalogId => _catalogId ?? GenesisContract.defaultCatalogId;

  /// Chemin du journal des enveloppes (`GENESIS_APP_LOG`) ; `null` : inactif.
  final String? appLogPath;

  /// Délai maximal du `POST` d'offre au relais.
  final Duration relayCreateTimeout;

  /// Délai maximal du `DELETE` au relais.
  final Duration relayDeleteTimeout;

  /// Délai maximal de connexion du canal WSS `/app`.
  final Duration channelConnectTimeout;

  /// Délai maximal de fermeture du canal WSS `/app`.
  final Duration channelCloseTimeout;

  /// Délai maximal de fermeture d'une session voix.
  final Duration sessionCloseTimeout;

  /// Délai maximal de fermeture de la session à la sortie de l'app.
  final Duration exitCloseTimeout;

  /// Délai maximal de collecte des candidats ICE.
  final Duration iceTimeout;

  /// Délai maximal de `POST /canvas/reset`
  /// (`GENESIS_CANVAS_RESET_TIMEOUT_MS`, 100 à 10000 ms). La remise à vide
  /// locale n'attend pas le backend : ce délai ne borne que la requête.
  Duration get canvasResetTimeout =>
      _canvasResetTimeout ?? defaultCanvasResetTimeout;

  /// Délai par défaut de la remise à vide (2 s).
  static const Duration defaultCanvasResetTimeout = Duration(seconds: 2);

  final Duration? _canvasResetTimeout;

  /// Nombre de réessais de la remise à vide quand le backend répond « occupé »
  /// (`GENESIS_CANVAS_RESET_RETRIES`, 0 à 30, défaut 8). Le backend refuse
  /// pendant tout un tour (plan, agents, commentaire final).
  int get canvasResetRetries =>
      _canvasResetRetries ?? defaultCanvasResetRetries;

  /// Nombre de réessais par défaut.
  static const int defaultCanvasResetRetries = 8;

  final int? _canvasResetRetries;

  /// Intervalle entre deux réessais
  /// (`GENESIS_CANVAS_RESET_RETRY_INTERVAL_MS`, 100 à 10000 ms, défaut 1,5 s).
  Duration get canvasResetRetryInterval =>
      _canvasResetRetryInterval ?? defaultCanvasResetRetryInterval;

  /// Intervalle de réessai par défaut (1,5 s).
  static const Duration defaultCanvasResetRetryInterval = Duration(
    milliseconds: 1500,
  );

  final Duration? _canvasResetRetryInterval;

  /// Délai maximal de `POST /canvas/actions` (un essai).
  final Duration canvasActionTimeout;

  /// Nombre de réessais d'une action quand le backend répond « occupé » ou
  /// « sans session » (6 réessais : 7 requêtes au plus).
  final int canvasActionRetries;

  /// Intervalle entre deux essais d'une action.
  final Duration canvasActionRetryInterval;

  /// Durée maximale pendant laquelle les boutons d'action restent inactifs
  /// après un 202, si la fin de l'activité des agents n'est pas vue.
  final Duration canvasActionMaxDuration;

  /// Silence au-delà duquel l'orbe retombe au repos.
  final Duration orbSilenceTimeout;

  /// Temps de montée du lissage de l'orbe.
  final Duration orbAttack;

  /// Temps de descente du lissage de l'orbe.
  final Duration orbRelease;

  /// Niveau lissé à partir duquel l'orbe est dite « parle ».
  final double orbSpeakingThreshold;

  static String? _read(Map<String, String> environment, String name) {
    final value = environment[name]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static Uri? _readBackendUrl(Map<String, String> environment) {
    final raw = _read(environment, _backendUrlVariable);
    if (raw == null) return null;
    final Uri uri;
    try {
      uri = Uri.parse(raw);
    } on FormatException {
      throw _invalidBackendUrl();
    }
    final validScheme = uri.scheme == 'http' || uri.scheme == 'https';
    final isOrigin =
        (uri.path.isEmpty || uri.path == '/') &&
        !uri.hasQuery &&
        !uri.hasFragment;
    if (!validScheme ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !isOrigin) {
      throw _invalidBackendUrl();
    }
    return uri;
  }

  static const String _canvasResetTimeoutVariable =
      'GENESIS_CANVAS_RESET_TIMEOUT_MS';
  static final RegExp _millisecondsPattern = RegExp(r'^\d{1,5}$');

  static Duration? _readCanvasResetTimeout(Map<String, String> environment) {
    final raw = _read(environment, _canvasResetTimeoutVariable);
    if (raw == null) return null;
    final millis = _millisecondsPattern.hasMatch(raw) ? int.parse(raw) : 0;
    if (millis < 100 || millis > 10000) {
      throw const GenesisConfigException(
        'La variable $_canvasResetTimeoutVariable est invalide : un nombre '
        'entier de millisecondes compris entre 100 et 10000 est attendu.',
      );
    }
    return Duration(milliseconds: millis);
  }

  static const String _canvasResetRetriesVariable =
      'GENESIS_CANVAS_RESET_RETRIES';
  static const String _canvasResetRetryIntervalVariable =
      'GENESIS_CANVAS_RESET_RETRY_INTERVAL_MS';
  static final RegExp _retriesPattern = RegExp(r'^\d{1,2}$');

  static int? _readCanvasResetRetries(Map<String, String> environment) {
    final raw = _read(environment, _canvasResetRetriesVariable);
    if (raw == null) return null;
    final count = _retriesPattern.hasMatch(raw) ? int.parse(raw) : -1;
    if (count < 0 || count > 30) {
      throw const GenesisConfigException(
        'La variable $_canvasResetRetriesVariable est invalide : un nombre '
        'entier compris entre 0 et 30 est attendu.',
      );
    }
    return count;
  }

  static Duration? _readCanvasResetRetryInterval(
    Map<String, String> environment,
  ) {
    final raw = _read(environment, _canvasResetRetryIntervalVariable);
    if (raw == null) return null;
    final millis = _millisecondsPattern.hasMatch(raw) ? int.parse(raw) : 0;
    if (millis < 100 || millis > 10000) {
      throw const GenesisConfigException(
        'La variable $_canvasResetRetryIntervalVariable est invalide : un '
        'nombre entier de millisecondes compris entre 100 et 10000 est '
        'attendu.',
      );
    }
    return Duration(milliseconds: millis);
  }

  static String? _readCatalogId(Map<String, String> environment) {
    final raw = _read(environment, 'GENESIS_CATALOG_ID');
    if (raw == null) return null;
    final Uri uri;
    try {
      uri = Uri.parse(raw);
    } on FormatException {
      throw _invalidCatalogId();
    }
    if (!uri.hasScheme || uri.toString() != raw) throw _invalidCatalogId();
    return raw;
  }

  static GenesisConfigException _invalidCatalogId() =>
      const GenesisConfigException(
        'La variable GENESIS_CATALOG_ID est invalide : une URI absolue est '
        'attendue (par exemple '
        'https://genesis-canvas.example/a2ui/catalogs/genesis/v1).',
      );

  static GenesisConfigException _invalidBackendUrl() =>
      const GenesisConfigException(
        'La variable $_backendUrlVariable est invalide : une URL http ou '
        'https avec un hôte, sans identifiants, chemin, requête ni fragment '
        'est attendue '
        '(par exemple http://127.0.0.1:8080).',
      );
}
