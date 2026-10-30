import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:feature_replay/feature_replay.dart' show ReplaySettings;

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
    this.canvasActionTimeout = defaultCanvasActionTimeout,
    this.canvasActionRetries = defaultCanvasActionRetries,
    this.canvasActionRetryInterval = defaultCanvasActionRetryInterval,
    this.canvasActionMaxDuration = defaultCanvasActionMaxDuration,
    this.orbSilenceTimeout = const Duration(milliseconds: 600),
    this.orbAttack = const Duration(milliseconds: 80),
    this.orbRelease = const Duration(milliseconds: 250),
    this.orbSpeakingThreshold = 0.03,
    this.replayMaxGap = defaultReplayMaxGap,
    this.replayTick = defaultReplayTick,
    this.replayJournalMaxEntries = defaultReplayJournalMaxEntries,
    this.replayDefaultSpeed = defaultReplaySpeed,
    this.replayCaptureAt,
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
  /// `GENESIS_CANVAS_RESET_RETRIES`, `GENESIS_CANVAS_RESET_RETRY_INTERVAL_MS`,
  /// `GENESIS_CANVAS_ACTION_TIMEOUT_MS`, `GENESIS_CANVAS_ACTION_RETRIES`,
  /// `GENESIS_CANVAS_ACTION_RETRY_INTERVAL_MS`,
  /// `GENESIS_CANVAS_ACTION_MAX_DURATION_MS` et les variables du rejeu
  /// (`GENESIS_REPLAY_MAX_GAP_MS`, `GENESIS_REPLAY_TICK_MS`,
  /// `GENESIS_REPLAY_JOURNAL_MAX`, `GENESIS_REPLAY_SPEED`,
  /// `GENESIS_REPLAY_AT`).
  ///
  /// Lève [GenesisConfigException] si `GENESIS_BACKEND_URL` ou
  /// `GENESIS_CATALOG_ID`, `GENESIS_CANVAS_RESET_TIMEOUT_MS`,
  /// `GENESIS_CANVAS_RESET_RETRIES`, `GENESIS_CANVAS_RESET_RETRY_INTERVAL_MS`
  /// ou l'une des variables `GENESIS_CANVAS_ACTION_*` ou `GENESIS_REPLAY_*`
  /// est invalide.
  factory GenesisConfig.fromEnvironment(
    Map<String, String> environment,
  ) => GenesisConfig(
    scenario: _read(environment, 'GENESIS_SCENARIO'),
    snapshotPath: _read(environment, 'GENESIS_SNAPSHOT'),
    backendUrl: _readBackendUrl(environment),
    catalogId: _readCatalogId(environment),
    appLogPath: _read(environment, 'GENESIS_APP_LOG'),
    canvasResetTimeout: _readCanvasResetTimeout(environment),
    canvasResetRetries: _readCanvasResetRetries(environment),
    canvasResetRetryInterval: _readCanvasResetRetryInterval(environment),
    canvasActionTimeout:
        _readCanvasActionTimeout(environment) ?? defaultCanvasActionTimeout,
    canvasActionRetries:
        _readCanvasActionRetries(environment) ?? defaultCanvasActionRetries,
    canvasActionRetryInterval:
        _readCanvasActionRetryInterval(environment) ??
        defaultCanvasActionRetryInterval,
    canvasActionMaxDuration:
        _readCanvasActionMaxDuration(environment) ??
        defaultCanvasActionMaxDuration,
    replayMaxGap:
        _readMillis(environment, _replayMaxGapVariable, min: 100, max: 60000) ??
        defaultReplayMaxGap,
    replayTick:
        _readMillis(environment, _replayTickVariable, min: 10, max: 1000) ??
        defaultReplayTick,
    replayJournalMaxEntries:
        _readReplayJournalMax(environment) ?? defaultReplayJournalMaxEntries,
    replayDefaultSpeed: _readReplaySpeed(environment) ?? defaultReplaySpeed,
    replayCaptureAt: _readReplayCaptureAt(environment),
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

  /// Délai maximal de `POST /canvas/actions` (un essai)
  /// (`GENESIS_CANVAS_ACTION_TIMEOUT_MS`, 100 à 10000 ms, défaut 2 s).
  final Duration canvasActionTimeout;

  /// Délai par défaut d'un essai d'action (2 s).
  static const Duration defaultCanvasActionTimeout = Duration(seconds: 2);

  /// Nombre de réessais d'une action quand le backend répond « occupé » ou
  /// « sans session » (`GENESIS_CANVAS_ACTION_RETRIES`, 0 à 30, défaut 6 :
  /// 7 requêtes au plus).
  final int canvasActionRetries;

  /// Nombre de réessais d'action par défaut.
  static const int defaultCanvasActionRetries = 6;

  /// Intervalle entre deux essais d'une action
  /// (`GENESIS_CANVAS_ACTION_RETRY_INTERVAL_MS`, 100 à 10000 ms, défaut 1 s).
  final Duration canvasActionRetryInterval;

  /// Intervalle de réessai d'action par défaut (1 s).
  static const Duration defaultCanvasActionRetryInterval = Duration(seconds: 1);

  /// Durée maximale pendant laquelle les boutons d'action restent inactifs
  /// après un 202, si la fin de l'activité des agents n'est pas vue
  /// (`GENESIS_CANVAS_ACTION_MAX_DURATION_MS`, 1000 à 90000 ms, défaut 60 s).
  final Duration canvasActionMaxDuration;

  /// Durée maximale par défaut des boutons inactifs (60 s).
  static const Duration defaultCanvasActionMaxDuration = Duration(seconds: 60);

  /// Écart maximal conservé entre deux messages rejoués, à 1x
  /// (`GENESIS_REPLAY_MAX_GAP_MS`, 100 à 60000 ms, défaut 3 s).
  final Duration replayMaxGap;

  /// Écart maximal par défaut entre deux messages rejoués (3 s).
  static const Duration defaultReplayMaxGap = ReplaySettings.defaultMaxGap;

  /// Pas de l'horloge du lecteur de rejeu (`GENESIS_REPLAY_TICK_MS`, 10 à
  /// 1000 ms, défaut 100 ms).
  final Duration replayTick;

  /// Pas par défaut du lecteur de rejeu (100 ms).
  static const Duration defaultReplayTick = ReplaySettings.defaultTick;

  /// Plafond du journal des messages A2UI (`GENESIS_REPLAY_JOURNAL_MAX`, 1 à
  /// 100000, défaut 5000) : au-delà, il cesse d'enregistrer.
  final int replayJournalMaxEntries;

  /// Plafond par défaut du journal (5000 messages).
  static const int defaultReplayJournalMaxEntries =
      ReplaySettings.defaultJournalMaxEntries;

  /// Vitesse du rejeu au premier démarrage (`GENESIS_REPLAY_SPEED`, l'une des
  /// vitesses proposées par la barre, défaut 1).
  final double replayDefaultSpeed;

  /// Vitesse de rejeu par défaut (1x).
  static const double defaultReplaySpeed = ReplaySettings.defaultStartSpeed;

  /// Position, en fraction de la durée comprimée du rejeu (`GENESIS_REPLAY_AT`,
  /// 0 à 1), où la capture est prise en mode scénario ; `null` : capture de la
  /// fin du scénario, sans entrer en rejeu.
  final double? replayCaptureAt;

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

  static const String _canvasActionTimeoutVariable =
      'GENESIS_CANVAS_ACTION_TIMEOUT_MS';
  static const String _canvasActionRetriesVariable =
      'GENESIS_CANVAS_ACTION_RETRIES';
  static const String _canvasActionRetryIntervalVariable =
      'GENESIS_CANVAS_ACTION_RETRY_INTERVAL_MS';
  static const String _canvasActionMaxDurationVariable =
      'GENESIS_CANVAS_ACTION_MAX_DURATION_MS';

  static Duration? _readCanvasActionTimeout(Map<String, String> environment) {
    final raw = _read(environment, _canvasActionTimeoutVariable);
    if (raw == null) return null;
    final millis = _millisecondsPattern.hasMatch(raw) ? int.parse(raw) : 0;
    if (millis < 100 || millis > 10000) {
      throw const GenesisConfigException(
        'La variable $_canvasActionTimeoutVariable est invalide : un nombre '
        'entier de millisecondes compris entre 100 et 10000 est attendu.',
      );
    }
    return Duration(milliseconds: millis);
  }

  static int? _readCanvasActionRetries(Map<String, String> environment) {
    final raw = _read(environment, _canvasActionRetriesVariable);
    if (raw == null) return null;
    final count = _retriesPattern.hasMatch(raw) ? int.parse(raw) : -1;
    if (count < 0 || count > 30) {
      throw const GenesisConfigException(
        'La variable $_canvasActionRetriesVariable est invalide : un nombre '
        'entier compris entre 0 et 30 est attendu.',
      );
    }
    return count;
  }

  static Duration? _readCanvasActionRetryInterval(
    Map<String, String> environment,
  ) {
    final raw = _read(environment, _canvasActionRetryIntervalVariable);
    if (raw == null) return null;
    final millis = _millisecondsPattern.hasMatch(raw) ? int.parse(raw) : 0;
    if (millis < 100 || millis > 10000) {
      throw const GenesisConfigException(
        'La variable $_canvasActionRetryIntervalVariable est invalide : un '
        'nombre entier de millisecondes compris entre 100 et 10000 est '
        'attendu.',
      );
    }
    return Duration(milliseconds: millis);
  }

  static Duration? _readCanvasActionMaxDuration(
    Map<String, String> environment,
  ) {
    final raw = _read(environment, _canvasActionMaxDurationVariable);
    if (raw == null) return null;
    final millis = _millisecondsPattern.hasMatch(raw) ? int.parse(raw) : 0;
    if (millis < 1000 || millis > 90000) {
      throw const GenesisConfigException(
        'La variable $_canvasActionMaxDurationVariable est invalide : un '
        'nombre entier de millisecondes compris entre 1000 et 90000 est '
        'attendu.',
      );
    }
    return Duration(milliseconds: millis);
  }

  static const String _replayMaxGapVariable = 'GENESIS_REPLAY_MAX_GAP_MS';
  static const String _replayTickVariable = 'GENESIS_REPLAY_TICK_MS';
  static const String _replayJournalMaxVariable = 'GENESIS_REPLAY_JOURNAL_MAX';
  static const String _replaySpeedVariable = 'GENESIS_REPLAY_SPEED';
  static const String _replayCaptureAtVariable = 'GENESIS_REPLAY_AT';
  static final RegExp _positiveIntegerPattern = RegExp(r'^\d{1,6}$');
  static final RegExp _decimalPattern = RegExp(r'^\d(\.\d{1,3})?$');

  static Duration? _readMillis(
    Map<String, String> environment,
    String name, {
    required int min,
    required int max,
  }) {
    final raw = _read(environment, name);
    if (raw == null) return null;
    final millis = _millisecondsPattern.hasMatch(raw) ? int.parse(raw) : -1;
    if (millis < min || millis > max) {
      throw GenesisConfigException(
        'La variable $name est invalide : un nombre entier de millisecondes '
        'compris entre $min et $max est attendu.',
      );
    }
    return Duration(milliseconds: millis);
  }

  static int? _readReplayJournalMax(Map<String, String> environment) {
    final raw = _read(environment, _replayJournalMaxVariable);
    if (raw == null) return null;
    final count = _positiveIntegerPattern.hasMatch(raw) ? int.parse(raw) : 0;
    if (count < 1 || count > 100000) {
      throw const GenesisConfigException(
        'La variable $_replayJournalMaxVariable est invalide : un nombre '
        'entier compris entre 1 et 100000 est attendu.',
      );
    }
    return count;
  }

  static double? _readReplaySpeed(Map<String, String> environment) {
    final raw = _read(environment, _replaySpeedVariable);
    if (raw == null) return null;
    final speed = _decimalPattern.hasMatch(raw) ? double.parse(raw) : null;
    if (speed == null || !ReplaySettings.defaultSpeeds.contains(speed)) {
      throw GenesisConfigException(
        'La variable $_replaySpeedVariable est invalide : l\'une des vitesses '
        '${ReplaySettings.defaultSpeeds.join(', ')} est attendue.',
      );
    }
    return speed;
  }

  static double? _readReplayCaptureAt(Map<String, String> environment) {
    final raw = _read(environment, _replayCaptureAtVariable);
    if (raw == null) return null;
    final fraction = _decimalPattern.hasMatch(raw) ? double.parse(raw) : -1.0;
    if (fraction < 0 || fraction > 1) {
      throw const GenesisConfigException(
        'La variable $_replayCaptureAtVariable est invalide : une fraction '
        'décimale comprise entre 0 et 1 est attendue (par exemple 0.5).',
      );
    }
    return fraction;
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
