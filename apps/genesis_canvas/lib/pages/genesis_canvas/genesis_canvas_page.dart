import 'dart:async';

import 'package:feature_agent_activity/feature_agent_activity.dart'
    show
        AgentActivityBloc,
        AgentActivityReset,
        AgentActivitySourceSubscribed,
        AgentActivityState;
import 'package:feature_canvas/feature_canvas.dart'
    show
        A2uiGate,
        ActionActivityChanged,
        ActionFailed,
        ActionSessionClosed,
        ActionStageReset,
        ActionIdle,
        ActionRunning,
        CanvasActionBloc,
        CanvasActionScope,
        CanvasActionSettings,
        DecisionStatusObserved,
        CanvasActionState,
        CanvasBloc,
        CanvasBoard,
        CanvasResetRequested,
        CanvasSourceStatus,
        CanvasSourceSubscribed,
        CanvasState;
import 'package:feature_catalog_shelf/feature_catalog_shelf.dart'
    show CatalogShelfBloc, CatalogShelfCleared, CatalogShelfSourceSubscribed;
import 'package:feature_protocol_feed/feature_protocol_feed.dart'
    show
        ProtocolFeedBloc,
        ProtocolFeedCleared,
        ProtocolFeedEntriesCleared,
        ProtocolFeedState,
        ProtocolSourceSubscribed;
import 'package:entity_session/entity_session.dart' show A2uiJournal;
import 'package:feature_replay/feature_replay.dart'
    show
        ReplayActive,
        ReplayBloc,
        ReplayBusyChanged,
        ReplayPausePressed,
        ReplayPlayPressed,
        ReplayPlayer,
        ReplayRouter,
        ReplaySeeked,
        ReplaySettings,
        ReplayStage,
        ReplayState,
        ReplayStatus;
import 'package:feature_stage_controls/feature_stage_controls.dart'
    show StageActReached, StageBloc, StageResetRequested;
import 'package:feature_voice_session/feature_voice_session.dart'
    show
        Active,
        Connecting,
        Failed,
        Idle,
        LiveSessionEventSource,
        Interrupted,
        canSilence,
        OrbLevelController,
        OrbPhase,
        OrbPhaseBloc,
        OrbPhaseSourceSubscribed,
        OrbSmoother,
        Stopping,
        TranscriptBloc,
        TranscriptResumed,
        TranscriptSourceSubscribed,
        VoiceMicMuteRequested,
        VoiceSession,
        VoiceSessionBloc,
        VoiceSessionStatus,
        VoiceSessionSubscribed;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart' show Catalog, SurfaceController;
import 'package:get_it/get_it.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart'
    show CanvasActionClient, CanvasResetClient, CanvasResetResult;
import 'package:shared_core/shared_core.dart'
    show AppClock, ExitGuard, ExitHandler, ReplayedMessage;
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotionScope, SceneTheme;

import '../../widgets/agents_rail/agents_rail.dart';
import '../../widgets/catalog_shelf/catalog_shelf.dart';
import '../../widgets/protocol_panel/protocol_panel.dart';
import '../../widgets/replay_bar/replay_bar.dart';
import '../../widgets/stage_bar/stage_bar.dart';
import '../../widgets/top_bar/top_bar.dart';
import 'capture_service.dart';
import 'engine_error_watcher.dart';
import 'genesis_canvas_page_settings.dart';

/// Fabrique du service de capture : la page lui fournit la fonction de sortie
/// finale (code ajusté par les erreurs du moteur).
typedef SnapshotFactory = CaptureService Function(ExitHandler exitHandler);

/// Page unique à six zones (écran de 1920 × 1080, budget des hauteurs :
/// pdr-0075 D1, spec 013) : barre du haut (orbe, transcription, acte, remise
/// à vide, bouton), rail des agents, canevas, puis une rangée du bas (étagère du
/// catalogue, zone Rejeu et panneau du protocole). Le panneau déplié recouvre
/// le canevas à droite sans le redimensionner.
///
/// **Racine de composition** : seul endroit, avec `app/di`, qui touche à
/// [GetIt] (reçu par constructeur, jamais lu depuis un widget ni un Bloc). Elle
/// résout UNE `VoiceSession`, construit avec cette instance la source
/// d'événements et le `VoiceSessionBloc`, puis branche tous les abonnés avant
/// toute connexion (le flux est en diffusion : un abonné tardif perdrait des
/// événements). Elle possède ce qu'elle crée et le ferme dans l'ordre (voir
/// `_shutdown`). Elle est aussi l'**unique coordinatrice** de la remise à vide
/// (`_resetStage`) : les features ne se lisent pas entre elles.
///
/// Mode scénario (un flux de rejeu est fourni) : la source vivante n'est pas
/// branchée au canevas et « Démarrer » est désactivé ; à la fin du rejeu, la
/// capture PNG est déclenchée si le service est actif.
class GenesisCanvasPage extends StatefulWidget {
  const GenesisCanvasPage({
    super.key,
    required this.getIt,
    required this.catalogs,
    required this.snapshotFactory,
    required this.exitHandler,
    required this.errorSink,
    required this.settings,
    this.replay,
    this.onClosing,
  }) : assert(
         catalogs.length == 1,
         'la page attend exactement un catalogue (source unique de son id)',
       );

  /// Graphe de dépendances de cette app (instance propre, configurée par la
  /// couche `app`).
  final GetIt getIt;

  /// Catalogue du moteur : exactement un.
  final List<Catalog> catalogs;

  /// Identifiant du catalogue que le validateur A2UI exige dans
  /// `createSurface` : dérivé de [catalogs], jamais fourni à part.
  String get catalogId =>
      catalogs.single.catalogId ??
      (throw StateError("le catalogue de la page n'a pas d'identifiant"));
  final SnapshotFactory snapshotFactory;
  final ExitHandler exitHandler;

  /// Destination des erreurs de rejeu et de capture (`stderr` en prod).
  final StringSink errorSink;

  /// Réglages de l'orbe et délais de fermeture (fournis par la couche `app`).
  final GenesisCanvasPageSettings settings;

  /// Messages A2UI à rejouer (ligne brute et message décodé) ; `null` : source vivante, canevas vide au départ.
  final Stream<ReplayedMessage>? replay;

  /// Reçoit la fermeture asynchrone lancée par le `dispose` de la page, pour
  /// que le propriétaire du graphe ne le libère qu'une fois la page fermée.
  final ValueChanged<Future<void>>? onClosing;

  @override
  State<GenesisCanvasPage> createState() => _GenesisCanvasPageState();
}

class _GenesisCanvasPageState extends State<GenesisCanvasPage>
    with TickerProviderStateMixin {
  GenesisCanvasPageSettings get _settings => widget.settings;

  // Voix : UNE session, partagée par la source d'événements et le Bloc.
  late final VoiceSession _session = widget.getIt<VoiceSession>();
  late final LiveSessionEventSource _source = LiveSessionEventSource(
    _session,
    onIgnored: (reason) => widget.errorSink.writeln('Message ignoré : $reason'),
  );
  late final VoiceSessionBloc _voiceBloc = VoiceSessionBloc(_session);
  late final TranscriptBloc _transcriptBloc = widget.getIt<TranscriptBloc>();
  // Phase de l'orbe (écoute, parole, interrompue) : réglée par la
  // configuration, construite ici (racine de composition) avec la source.
  late final OrbPhaseBloc _phaseBloc = OrbPhaseBloc(
    speakingThreshold: _settings.orbSpeakingThreshold,
    resumeSilence: _settings.interruptResumeSilence,
    maxInterruption: _settings.interruptMaxDuration,
    stopSpan: _settings.interruptStopSpan,
  );
  StreamSubscription<OrbPhase>? _phaseSubscription;
  bool _wasInterrupted = false;
  // Raccourcis facultatifs `M` (micro) et `Échap` (faire taire), jamais
  // `Espace` (014, pdr-0033). Le nœud de focus de la racine reçoit les
  // touches même sans clic préalable ; quand un bouton focalisé se désactive,
  // Flutter rend le focus au dernier nœud de la portée (testé).
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'genesis-shortcuts');
  late final AgentActivityBloc _agentsBloc = widget.getIt<AgentActivityBloc>();
  // Écran de fabrication : panneau du protocole (horloge de l'app, pdr-0038),
  // étagère du catalogue et régie des actes.
  late final ProtocolFeedBloc _protocolBloc = ProtocolFeedBloc(
    clock: widget.getIt<AppClock>(),
  );
  // Surface en évidence du panneau du protocole : le canevas la lit par
  // cellule, sans que le board ni les voisines se reconstruisent (013, P6).
  final ValueNotifier<String?> _highlight = ValueNotifier<String?>(null);
  late final CatalogShelfBloc _shelfBloc = CatalogShelfBloc();
  late final StageBloc _stageBloc = StageBloc();
  // Résolu une fois ici (racine de composition) ; le widget ne voit qu'un
  // callback.
  late final CanvasResetClient _resetClient = widget.getIt<CanvasResetClient>();
  // Actions des composants générés (Barre d'actions) : le client est résolu
  // ici (racine de composition), le Bloc ne voit qu'un port.
  late final CanvasActionBloc _actionBloc = CanvasActionBloc(
    client: widget.getIt<CanvasActionClient>(),
    settings: CanvasActionSettings(
      retries: _settings.canvasActionRetries,
      retryInterval: _settings.canvasActionRetryInterval,
      maxDuration: _settings.canvasActionMaxDuration,
    ),
  );
  // Relais de l'activité des agents vers le Bloc d'action : les slices ne se
  // lisent pas entre elles, c'est la page qui les relie.
  StreamSubscription<bool>? _activitySubscription;
  // Occupation relayée au rejeu : « un agent travaille OU une action est en
  // cours » (A5). Les deux sources sont combinées ici, la page étant la seule
  // à connaître les deux slices.
  StreamSubscription<bool>? _actionBusySubscription;
  bool _agentsBusy = false;
  bool _actionBusy = false;
  // Affecté dans `initState` (abonné de la source, il porte un Ticker).
  late final OrbLevelController _orb;

  // Canevas.
  late final SurfaceController _controller = SurfaceController(
    catalogs: widget.catalogs,
  );
  late final CanvasBloc _bloc = CanvasBloc(_controller);
  // UNE instance du validateur A2UI pour la session, en direct comme en rejeu.
  late final A2uiGate _gate = A2uiGate(
    catalogId: widget.catalogId,
    onRejected: _onMessageRejected,
  );
  // Journal des messages A2UI de la session (rejeu de l'acte 4) : en mémoire
  // seulement, jamais écrit ailleurs.
  late final A2uiJournal _journal = A2uiJournal(
    maxEntries: _settings.replayJournalMaxEntries,
  );

  /// Journal des messages enregistrés (lecture seule pour les tests).
  @visibleForTesting
  A2uiJournal get journal => _journal;

  /// Routeur du rejeu, pour observer l'ordre de fermeture dans les tests.
  @visibleForTesting
  ReplayRouter get router => _router;

  // Seul flux qui entre dans le gate : vivant (ou scénario), enregistré au
  // passage ; le lecteur de rejeu s'y substituera. Créé dans `initState`.
  late final ReplayRouter _router;
  StreamSubscription<int>? _journalFullSubscription;
  // Pilote du rejeu de l'acte 4 : seul appelant du routeur (mode) et du port
  // `ReplayStage` (créé dans `initState`, après le routeur).
  late final ReplayBloc _replayBloc;
  // Refus vus : un rejeu qui en contient ne vaut pas succès (comme une erreur
  // du moteur).
  int _rejectedCount = 0;
  final GlobalKey _boundaryKey = GlobalKey();
  // Affecté dans `initState` : écoute dès la création (le moteur ne rejoue
  // pas les erreurs passées).
  late final EngineErrorWatcher _engineErrors;
  late final CaptureService _snapshot = widget.snapshotFactory(
    // Une capture réussie ne vaut pas succès si le moteur a signalé des erreurs.
    (code) => widget.exitHandler(
      code == 0 && (_engineErrors.count > 0 || _rejectedCount > 0) ? 1 : code,
    ),
  );

  late final ExitGuard _exitGuard = ExitGuard(
    _session.stop,
    _settings.exitCloseTimeout,
  );
  late final AppLifecycleListener _lifecycle;

  /// Mode scénario (000) : un flux de messages fourni remplace la source
  /// vivante. À ne pas confondre avec le rejeu de l'acte 4 (journal de la
  /// session en cours).
  bool get _scenarioMode => widget.replay != null;

  /// Captures et scénarios : l'animation de l'orbe est coupée pour que les
  /// images restent déterministes (et que `pumpAndSettle` converge).
  bool get _animationsOff => _scenarioMode || _snapshot.isActive;

  // Réglage d'animation de la scène : durée nulle en scénario, en capture et
  // sous « réduire les animations » ; vitesse du rejeu en cours sinon.
  Widget _motionScope({required Widget child}) =>
      BlocSelector<ReplayBloc, ReplayState, double>(
        selector: (state) => state is ReplayActive ? state.snapshot.speed : 1,
        builder: (context, speed) => SceneMotionScope(
          disabled:
              (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
              _animationsOff,
          speed: speed,
          child: child,
        ),
      );

  @override
  void initState() {
    super.initState();
    // Écoute dès la création : le moteur ne rejoue pas les erreurs passées.
    _engineErrors = EngineErrorWatcher(
      onSubmit: _controller.onSubmit,
      errorSink: widget.errorSink,
    );
    _lifecycle = AppLifecycleListener(
      onExitRequested: _exitGuard.onExitRequested,
    );
    _orb = OrbLevelController(
      vsync: this,
      events: _source.events,
      smoother: OrbSmoother(
        attack: _settings.orbAttack,
        release: _settings.orbRelease,
      ),
      silenceTimeout: _settings.orbSilenceTimeout,
    );
    // Tous les abonnés se branchent avant toute connexion.
    _voiceBloc.add(const VoiceSessionSubscribed());
    _transcriptBloc.add(TranscriptSourceSubscribed(_source.events));
    _phaseBloc.add(OrbPhaseSourceSubscribed(_source.events));
    _phaseSubscription = _phaseBloc.stream.listen(_onOrbPhase);
    _agentsBloc.add(AgentActivitySourceSubscribed(_source.events));
    // Un seul flux de `SessionEvent` entre dans le gate : le flux vivant, ou
    // le rejeu encapsulé en enveloppes (la source vivante n'alimente alors pas
    // le canevas). Le Bloc ne reçoit que les messages acceptés.
    final replay = widget.replay;
    _bloc.add(CanvasSourceSubscribed(_gate.accepted));
    _router = ReplayRouter(
      live: replay == null ? _source.events : A2uiGate.replayEvents(replay),
      journal: _journal,
      nowMs: widget.getIt<AppClock>().nowUnixMs,
    );
    _gate.attach(_router.events);
    _journalFullSubscription = _router.journalFull.listen(
      (count) => widget.errorSink.writeln(
        'Rejeu : journal plein ($count messages), '
        'la suite n\'est pas enregistrée',
      ),
    );
    final replaySettings = ReplaySettings(
      tick: _settings.replayTick,
      maxGap: _settings.replayMaxGap,
      defaultSpeed: _settings.replayDefaultSpeed,
    );
    _replayBloc = ReplayBloc(
      router: _router,
      stage: _PageReplayStage(
        clear: () => _clearScene(keepPanelOpen: true),
        exit: _exitReplayStage,
      ),
      settings: replaySettings,
      playerFactory: (entries, {required inject, required clearStage}) =>
          ReplayPlayer(
            entries: entries,
            settings: replaySettings,
            inject: inject,
            clearStage: clearStage,
          ),
    );
    // Le routeur et le Bloc du rejeu existent déjà : les relais d'occupation ci-dessous
    // l'alimentent (ils ne tiennent pas seulement parce que les flux sont
    // asynchrones).
    _activitySubscription = _agentsBloc.stream
        .map((AgentActivityState state) => state.anyBusy)
        .distinct()
        .listen((bool busy) {
          _actionBloc.add(ActionActivityChanged(busy: busy));
          _agentsBusy = busy;
          _relayBusy();
        });
    _actionBusySubscription = _actionBloc.stream
        .map((CanvasActionState state) => state is! ActionIdle)
        .distinct()
        .listen((bool busy) {
          _actionBusy = busy;
          _relayBusy();
        });
    // Panneau et étagère lisent le flux validé (tous les messages, avec leur
    // verdict) par des branches qui gardent en mémoire ce qui arrive avant
    // l'abonnement effectif du Bloc.
    _protocolBloc.add(ProtocolSourceSubscribed(_gate.validatedBranch()));
    _shelfBloc.add(CatalogShelfSourceSubscribed(_gate.validatedBranch()));
    if (replay != null) {
      // Le routeur ne ferme pas sa sortie à la fin du flux : la fin du
      // scénario déclenche la capture (comportement de 000).
      unawaited(_router.liveDone.then((_) => _onScenarioDone()));
    } else {
      // Démarrage en mode vivant (pdr-0064, D6) : l'écran est déjà vide, mais
      // le canevas du backend peut garder des surfaces d'une exécution
      // précédente ; une mutation par données seules viserait alors une
      // surface inconnue de l'app. Une seule demande, avant la première
      // session (le bouton Démarrer n'a pas encore été touché), au mieux :
      // l'échec est consigné sans bloquer. Aucune remise à vide visuelle.
      unawaited(_requestBackendReset());
      _startupResetGeneration = _resetGeneration;
      _statusSubscription = _session.status.listen(_onSessionStatus);
      if (_snapshot.isActive) {
        // Sans scénario : capture du canevas vide après la première frame.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(_captureWhenSettled()),
        );
      }
    }
  }

  /// Relaie au rejeu l'occupation combinée (agents ou action en cours).
  ///
  /// Le mode scénario n'interdit pas « Lecture » (pdr-0062) : il n'y a ni
  /// session voix ni action, donc aucune occupation à protéger, et la Lecture
  /// y reste cliquable même après la fin du scénario.
  void _relayBusy() =>
      _replayBloc.add(ReplayBusyChanged(_agentsBusy || _actionBusy));

  /// Sortie du rejeu (« Direct »), appelée par le Bloc du rejeu AVANT que le
  /// routeur ne revienne en direct : écrit le nombre de messages vivants
  /// écartés (jamais leur contenu) puis remet la scène à vide.
  void _exitReplayStage() {
    final int discarded = _router.discardedLiveCount;
    if (discarded > 0) {
      widget.errorSink.writeln('Rejeu : $discarded messages vivants écartés');
    }
    _resetStage();
  }

  /// Consigne le code fermé du refus, jamais le contenu du message.
  void _onMessageRejected(String code) {
    _rejectedCount++;
    widget.errorSink.writeln('Message A2UI refusé : $code');
  }

  /// Remise à vide de la scène (FR-11, D4) : l'**unique** coordinatrice, dans
  /// l'ordre exact de A4a :
  ///
  /// 1. le validateur A2UI repart de zéro, de façon synchrone (une surface
  ///    recréée ensuite n'est pas refusée comme « existante ») ;
  /// 2. un ordre à chaque Bloc (canevas, panneau, étagère, rail, acte 1) ;
  /// 3. la demande au backend de retirer les surfaces actives, au mieux et
  ///    sans attendre : l'écran est déjà vide.
  ///
  /// Le Bloc d'action abandonne l'action en cours (étape 2, avec les autres
  /// Blocs) : les boutons redeviennent actifs.
  void _resetStage() {
    _clearScene(keepPanelOpen: false);
    _router.clearJournal();
    _agentsBloc.add(const AgentActivityReset());
    _stageBloc.add(const StageResetRequested());
    _actionBloc.add(const ActionStageReset());
    unawaited(_requestBackendReset());
  }

  /// Identifiant de la surface de la Barre d'actions (fin de l'acte 2).
  static const String _actionsSurfaceId = 'actions';

  /// Fait avancer l'indicateur d'acte (jamais en arrière). Sans effet en mode
  /// scénario et pendant le rejeu de l'acte 4 : un message rejoué ou vivant
  /// ne décrit pas l'avancement de la démo.
  void _reachAct(int act) {
    if (_scenarioMode || _replayBloc.state is ReplayActive) return;
    _stageBloc.add(StageActReached(act));
  }

  /// Étapes 1 et 2 de [_resetStage] pour ce qui est visible de la scène
  /// (canevas, panneau, étagère), de façon synchrone : le validateur repart de
  /// zéro. Avec [keepPanelOpen] (positionnement du rejeu), le panneau garde
  /// son état replié ou déplié : le JSON ouvert ne se referme pas. Ni le
  /// backend, ni le journal, ni l'acte, ni les agents, ni le Bloc d'action ne
  /// sont touchés.
  void _clearScene({required bool keepPanelOpen}) {
    _gate.reset();
    _bloc.add(const CanvasResetRequested());
    _protocolBloc.add(
      keepPanelOpen
          ? const ProtocolFeedEntriesCleared()
          : const ProtocolFeedCleared(),
    );
    _shelfBloc.add(const CatalogShelfCleared());
  }

  /// Génération de la demande de remise à vide en cours. Une nouvelle demande
  /// **remplace** la précédente (qui s'arrête à son prochain réveil) plutôt
  /// qu'elle n'est ignorée : l'écran vient d'être revidé, c'est la dernière
  /// demande qui reflète l'état voulu, et il n'y a jamais deux boucles.
  int _resetGeneration = 0;

  /// Génération de la demande lancée au démarrage (mode vivant), `null` hors
  /// de ce mode.
  int? _startupResetGeneration;
  StreamSubscription<VoiceSessionStatus>? _statusSubscription;
  Timer? _retryTimer;
  Completer<void>? _retryWait;

  /// Demande au backend de retirer ses surfaces. Tant qu'il répond `busy`
  /// (409 : un tour est en cours), la demande est réessayée, jusqu'à
  /// `canvasResetRetries` fois, à `canvasResetRetryInterval` d'écart : les
  /// `deleteSurface` renvoyés par le backend sont ignorés par le validateur,
  /// le réessai est sans risque. Tout autre refus ou échec est consigné sans
  /// réessai ; le client ne lève pas d'exception. La boucle s'arrête à la
  /// fermeture de la page ou quand une demande plus récente la remplace.
  Future<void> _requestBackendReset() async {
    final int generation = ++_resetGeneration;
    _cancelRetryWait();
    var retriesLeft = _settings.canvasResetRetries;
    while (true) {
      final CanvasResetResult result = await _resetClient.reset();
      if (result == CanvasResetResult.done || generation != _resetGeneration) {
        return;
      }
      if (result != CanvasResetResult.busy || retriesLeft == 0) {
        widget.errorSink.writeln(
          'Remise à vide : le backend ne l\'a pas appliquée (${result.name}).',
        );
        return;
      }
      retriesLeft--;
      await _waitBeforeRetry(_settings.canvasResetRetryInterval);
      if (generation != _resetGeneration) return;
    }
  }

  /// Au premier passage à `Connecting`, la remise à vide de démarrage, si elle
  /// est encore en réessai, est abandonnée : elle viderait le tableau en pleine
  /// démo. Une remise à vide plus récente (manuelle) n'est pas touchée.
  ///
  /// Une session qui se ferme (arrêt, échec) libère aussi l'action en cours :
  /// plus rien n'arrivera pour elle.
  void _onSessionStatus(VoiceSessionStatus status) {
    if (status is Idle || status is Stopping || status is Failed) {
      _actionBloc.add(const ActionSessionClosed());
    }
    if (status is! Connecting) return;
    final int? startup = _startupResetGeneration;
    if (startup == null) return;
    _startupResetGeneration = null;
    if (_resetGeneration == startup) {
      _resetGeneration++;
      _cancelRetryWait();
    }
  }

  /// Attente annulable (un `Timer` conservé, jamais orphelin).
  Future<void> _waitBeforeRetry(Duration interval) {
    final wait = Completer<void>();
    _retryWait = wait;
    _retryTimer = Timer(interval, () {
      _retryTimer = null;
      if (!wait.isCompleted) wait.complete();
    });
    return wait.future;
  }

  /// Annule l'attente en cours : sa boucle se réveille aussitôt et constate
  /// que sa génération est périmée.
  void _cancelRetryWait() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final wait = _retryWait;
    _retryWait = null;
    if (wait != null && !wait.isCompleted) wait.complete();
  }

  void _onSourceChanged(BuildContext context, CanvasState state) {
    // « Rejeu impossible » ne concerne que le mode scénario ; la source
    // vivante ne se termine qu'à la fermeture de la page.
    if (!_scenarioMode) return;
    switch (state.sourceStatus) {
      case CanvasSourceStatus.failed:
        widget.errorSink.writeln('Rejeu impossible : ${state.sourceError}');
        if (_snapshot.isActive) widget.exitHandler(1);
      case CanvasSourceStatus.none:
      case CanvasSourceStatus.playing:
      case CanvasSourceStatus.completed:
        break;
    }
  }

  /// Fin du flux du scénario : capture, sauf si le flux a échoué (la sortie en
  /// erreur est alors déjà demandée par [_onSourceChanged]). Avec
  /// `replayCaptureAt`, la page entre d'abord en rejeu et s'y positionne.
  void _onScenarioDone() {
    if (!_snapshot.isActive) return;
    final double? at = _settings.replayCaptureAt;
    if (at == null) {
      unawaited(_captureWhenSettled());
    } else {
      unawaited(_positionReplayThenCapture(at));
    }
  }

  /// Capture à mi-parcours du rejeu (A3) : le journal du scénario est
  /// enregistré ; la page lance le rejeu, se place à la fraction [at] de la
  /// durée comprimée puis met en pause, et capture une fois la barrière du
  /// positionnement passée.
  Future<void> _positionReplayThenCapture(double at) async {
    if (_bloc.state.sourceStatus == CanvasSourceStatus.failed) return;
    if (!_router.hasPlayableJournal) {
      widget.errorSink.writeln(
        'Capture impossible : le rejeu n\'a aucun message à rejouer.',
      );
      widget.exitHandler(1);
      return;
    }
    // Chaque attente est bornée (« Lecture » peut être refusée : agent
    // occupé, journal sans `createSurface`) et suivie d'une garde `mounted` :
    // jamais d'`add` sur un Bloc fermé par `dispose`.
    final Duration bound = _settings.exitCloseTimeout;
    final Future<ReplayActive> entered = _replayBloc.stream
        .where((ReplayState state) => state is ReplayActive)
        .cast<ReplayActive>()
        .first
        .timeout(bound);
    _replayBloc.add(const ReplayPlayPressed());
    final ReplayActive? active = await _awaitReplay(entered);
    if (active == null || !mounted) return;
    final Duration target = Duration(
      microseconds: (active.snapshot.duration.inMicroseconds * at).round(),
    );
    final Future<ReplayActive> paused = _replayBloc.stream
        .where(
          (ReplayState state) =>
              state is ReplayActive &&
              state.snapshot.status == ReplayStatus.paused &&
              state.snapshot.position == target,
        )
        .cast<ReplayActive>()
        .first
        .timeout(bound);
    _replayBloc
      ..add(ReplaySeeked(target))
      ..add(const ReplayPausePressed());
    if (await _awaitReplay(paused) == null || !mounted) return;
    // La barrière du positionnement est un minuteur de durée nulle armé avant
    // celui-ci : une fois passé, les messages jusqu'à la position sont
    // réinjectés.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _captureWhenSettled();
  }

  /// Attend un état du rejeu ; rend `null` si l'attente échoue (délai dépassé,
  /// Bloc fermé). Page encore montée : consigne l'erreur et demande la sortie
  /// en erreur ; page démontée : silence (la fermeture a déjà la main).
  Future<ReplayActive?> _awaitReplay(Future<ReplayActive> waiting) async {
    try {
      return await waiting;
    } on Object {
      if (mounted) {
        widget.errorSink.writeln(
          'Capture impossible : le rejeu n\'a pas démarré.',
        );
        widget.exitHandler(1);
      }
      return null;
    }
  }

  /// Nombre maximal de frames attendues avant la capture.
  static const int _maxSettleFrames = 10;

  Future<void> _captureWhenSettled() async {
    // Au moins une frame (genui construit la surface), puis tant qu'une frame
    // reste programmée (validation asynchrone), dans la limite du plafond.
    final binding = WidgetsBinding.instance;
    var frames = 0;
    do {
      binding.scheduleFrame();
      await binding.endOfFrame;
      frames++;
    } while (frames < _maxSettleFrames && binding.hasScheduledFrame);
    if (_bloc.state.sourceStatus == CanvasSourceStatus.failed) return;
    if (!mounted) {
      widget.errorSink.writeln('Capture impossible : page démontée.');
      widget.exitHandler(1);
      return;
    }
    await _snapshot.captureAndExit(_boundaryKey);
  }

  @override
  void dispose() {
    _shortcutFocus.dispose();
    // Plus de réessai de remise à vide une fois la page fermée.
    _resetGeneration++;
    _cancelRetryWait();
    unawaited(_statusSubscription?.cancel());
    unawaited(_phaseSubscription?.cancel());
    unawaited(_activitySubscription?.cancel());
    unawaited(_journalFullSubscription?.cancel());
    unawaited(_actionBusySubscription?.cancel());
    _lifecycle.dispose();
    _highlight.dispose();
    // L'orbe est un abonné de la source et porte un Ticker de ce State : elle
    // se ferme tout de suite (le mixin refuse un Ticker actif au dispose), donc
    // avant la source qu'elle écoute.
    _orb.dispose();
    // Le Bloc du rejeu se ferme ici, avant tout le reste et une seule fois :
    // sa partie synchrone détruit le lecteur (minuteurs coupés) sans attendre
    // la fermeture asynchrone, et il n'écoute plus le routeur ni la scène.
    unawaited(_replayBloc.close());
    // Le minuteur d'une action en cours (60 s) dort dans `_sleep` : la remise à
    // zéro, synchrone, le réveille avant que le teardown n'attende le Bloc.
    _actionBloc.add(const ActionStageReset());
    final closing = _shutdown();
    unawaited(closing);
    widget.onClosing?.call(closing);
    super.dispose();
  }

  // Fin d'une interruption vocale (FR-19) : la page relie la phase de l'orbe
  // aux trois consommateurs qui ne se lisent pas entre eux : la voix de l'IA,
  // le niveau de l'orbe et la ligne de transcription.
  void _onOrbPhase(OrbPhase phase) {
    final interrupted = phase is Interrupted;
    final resumed = _wasInterrupted && !interrupted;
    _wasInterrupted = interrupted;
    if (!resumed) return;
    unawaited(_session.resumeRemoteAudio());
    _orb.resume();
    _transcriptBloc.add(const TranscriptResumed());
  }

  // Faire taire l'IA (S-09) : coupe la piste distante sans fermer la session.
  // La reprise passe par `_onOrbPhase`, comme après `voice.interrupted`.
  void _silenceRemote() {
    unawaited(_session.silenceRemote());
  }

  // Micro : la valeur cible se calcule depuis l'état courant du Bloc ; sans
  // effet hors session `Active`.
  void _toggleMic() {
    final status = _voiceBloc.state;
    if (status is! Active) return;
    _voiceBloc.add(VoiceMicMuteRequested(!status.micMuted));
  }

  /// Fermeture ordonnée, jamais d'exception non gérée : un objet n'est libéré
  /// qu'après ses consommateurs.
  ///
  /// 1. `VoiceSessionBloc` (plus de commande ni d'abonné au statut) ;
  /// 2. arrêt de la session, borné ;
  /// 3. libération de la session ;
  /// 4. source d'événements (la session ne lui émet plus rien) ;
  /// 5. routeur du rejeu (il lit la source), puis filtre A2UI (il lit le
  ///    routeur) ; le Bloc du rejeu, lui, est déjà fermé par `dispose`, avant
  ///    toute cette séquence ;
  /// 6. Blocs de transcription, de phase de l'orbe, d'action, d'activité (que le Bloc d'action
  ///    écoute, par la page) puis du canevas ;
  /// 7. Blocs du panneau du protocole, de l'étagère et de la régie : ils
  ///    lisent le gate, donc ils ne se ferment qu'après lui ;
  /// 8. moteur genui, une fois le Bloc du canevas fermé.
  Future<void> _shutdown() async {
    final bound = _settings.sessionCloseTimeout;
    await _step('Bloc de session', _voiceBloc.close);
    await _step('arrêt de la session', _session.stop, timeout: bound);
    await _step('libération de la session', _session.dispose, timeout: bound);
    await _step('source d\'événements', _source.dispose);
    await _step('routeur du rejeu', () async => _router.dispose());
    await _step('filtre A2UI', _gate.dispose);
    await _step('Bloc de transcription', _transcriptBloc.close);
    await _step('Bloc de phase de l\'orbe', _phaseBloc.close);
    await _step('Bloc d\'action', _actionBloc.close);
    await _step('Bloc des agents', _agentsBloc.close);
    await _step('Bloc du canevas', _bloc.close);
    await _step('Bloc du protocole', _protocolBloc.close);
    await _step('Bloc de l\'étagère', _shelfBloc.close);
    await _step('Bloc de la régie', _stageBloc.close);
    await _step('surveillance du moteur', _engineErrors.dispose);
    _controller.dispose();
  }

  Future<void> _step(
    String name,
    Future<void> Function() action, {
    Duration? timeout,
  }) async {
    try {
      final running = action();
      await (timeout == null ? running : running.timeout(timeout));
    } on Object catch (error) {
      widget.errorSink.writeln('Fermeture : $name a échoué ($error).');
    }
  }

  /// Marges et intervalles entre zones : 40 px au total à la verticale (20 px
  /// de moins qu'en 007, repris par le bandeau de la Barre d'actions, A1 de
  /// 009).
  static const double _marginX = 24;
  static const double _marginY = 8;
  static const double _gap = 8;

  /// Hauteurs fixes du budget des zones à 1920 × 1080 ; le canevas prend le
  /// reste (676 px : grille 2 × 302 et bandeau de 72, soit 1080 moins 128, 96 et
  /// 140 px de zones et 40 px d'écarts : 3 écarts de 8 et 2 marges verticales de
  /// 8). La barre supérieure fait
  /// 128 px et le rail, horizontal et de hauteur fixe même vide, 96 px (A1 de
  /// 013, pdr-0075 D1).
  static const double _railHeight = AgentsRail.height;
  static const double _bottomRowHeight = 140;
  static const double _replayWidth = 480;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider<VoiceSessionBloc>.value(value: _voiceBloc),
      BlocProvider<TranscriptBloc>.value(value: _transcriptBloc),
      BlocProvider<OrbPhaseBloc>.value(value: _phaseBloc),
      BlocProvider<AgentActivityBloc>.value(value: _agentsBloc),
      BlocProvider<CanvasActionBloc>.value(value: _actionBloc),
      BlocProvider<CanvasBloc>.value(value: _bloc),
      BlocProvider<ProtocolFeedBloc>.value(value: _protocolBloc),
      BlocProvider<CatalogShelfBloc>.value(value: _shelfBloc),
      BlocProvider<StageBloc>.value(value: _stageBloc),
      BlocProvider<ReplayBloc>.value(value: _replayBloc),
    ],
    child: MultiBlocListener(
      listeners: [
        BlocListener<CanvasBloc, CanvasState>(
          listenWhen: (previous, current) =>
              previous.sourceStatus != current.sourceStatus,
          listener: _onSourceChanged,
        ),
        // Le statut de décision du data model (`/checklist/decisionStatus`)
        // alimente le Bloc d'action : c'est lui qui garde la décision prise.
        BlocListener<CanvasBloc, CanvasState>(
          listenWhen: (previous, current) =>
              previous.decisionStatus != current.decisionStatus &&
              current.decisionStatus != null,
          listener: (context, state) =>
              _actionBloc.add(DecisionStatusObserved(state.decisionStatus!)),
        ),
        // La surbrillance du panneau du protocole alimente le canevas.
        BlocListener<ProtocolFeedBloc, ProtocolFeedState>(
          listenWhen: (previous, current) =>
              previous.highlightedSurfaceId != current.highlightedSurfaceId,
          listener: (context, state) =>
              _highlight.value = state.highlightedSurfaceId,
        ),
        // Avance automatique de l'indicateur d'acte (011, T24) : la surface
        // `actions` apparaît à la fin de l'acte 2 (pdr-0061).
        BlocListener<CanvasBloc, CanvasState>(
          listenWhen: (previous, current) =>
              previous.phaseOf(_actionsSurfaceId) == null &&
              current.phaseOf(_actionsSurfaceId) != null,
          listener: (context, state) => _reachAct(2),
        ),
        // Un clic accepté (202) : signal local, jamais rejoué.
        BlocListener<CanvasActionBloc, CanvasActionState>(
          listenWhen: (previous, current) =>
              previous is! ActionRunning && current is ActionRunning,
          listener: (context, state) => _reachAct(3),
        ),
        // Seule la cause fermée de l'échec est consignée, jamais le détail du
        // backend.
        BlocListener<CanvasActionBloc, CanvasActionState>(
          listenWhen: (previous, current) => current is ActionFailed,
          listener: (context, state) => widget.errorSink.writeln(
            'Action : le backend ne l\'a pas appliquée '
            '(${(state as ActionFailed).reason.name}).',
          ),
        ),
      ],
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.keyM): const _MicIntent(),
          const SingleActivator(LogicalKeyboardKey.escape):
              const _SilenceIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _MicIntent: CallbackAction<_MicIntent>(
              onInvoke: (_) {
                _toggleMic();
                return null;
              },
            ),
            _SilenceIntent: CallbackAction<_SilenceIntent>(
              onInvoke: (_) {
                // Idempotent : sans effet hors `Active` (`silenceRemote`) et
                // tant que l'orbe est déjà interrompue.
                if (canSilence(_voiceBloc.state, _phaseBloc.state)) {
                  _silenceRemote();
                }
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            focusNode: _shortcutFocus,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: ColoredBox(
                color: SceneTheme.of(context).background,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _marginX,
                    vertical: _marginY,
                  ),
                  child: Stack(
                    children: <Widget>[
                      Column(
                        children: <Widget>[
                          TickerMode(
                            enabled: !_animationsOff,
                            // « Démarrer » est inactif en mode scénario et pendant un
                            // rejeu ; la session voix en cours n'est pas touchée.
                            child: BlocSelector<ReplayBloc, ReplayState, bool>(
                              selector: (state) => state is ReplayActive,
                              builder: (context, replaying) => TopBar(
                                orbLevel: _orb.level,
                                speakingThreshold:
                                    _settings.orbSpeakingThreshold,
                                startEnabled: !_scenarioMode && !replaying,
                                stage: StageBar(
                                  onResetPressed: _resetStage,
                                  onSilencePressed: _silenceRemote,
                                  onMicPressed: _toggleMic,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: _gap),
                          // Même réglage d'animation que le canevas : la liaison
                          // de délégation du rail reste fixe quand les
                          // animations sont coupées.
                          _motionScope(
                            child: const SizedBox(
                              height: _railHeight,
                              child: AgentsRail(),
                            ),
                          ),
                          const SizedBox(height: _gap),
                          Expanded(
                            // Réglage d'animation du canevas : durée nulle en
                            // scénario, en capture et sous « réduire les
                            // animations » ; vitesse du rejeu en cours sinon. Pas de
                            // `TickerMode` ici : il figerait l'apparition à
                            // l'opacité 0.
                            child: _motionScope(
                              child:
                                  BlocSelector<ReplayBloc, ReplayState, bool>(
                                    selector: (state) => state is ReplayActive,
                                    // Rejeu (scénario ou acte 4) : aucune requête ne
                                    // part.
                                    builder: (context, replaying) =>
                                        CanvasActionScope(
                                          enabled: !_scenarioMode && !replaying,
                                          child: CanvasBoard(
                                            key: const Key('canvas-board'),
                                            controller: _controller,
                                            highlight: _highlight,
                                          ),
                                        ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: _gap),
                          SizedBox(
                            height: _bottomRowHeight,
                            child: Row(
                              children: <Widget>[
                                const Expanded(child: CatalogShelf()),
                                const SizedBox(width: 16),
                                const SizedBox(
                                  width: _replayWidth,
                                  child: ReplayBar(),
                                ),
                                const SizedBox(width: 16),
                                // Emplacement du panneau replié : le panneau lui-même
                                // est posé par-dessus (voir ci-dessous).
                                SizedBox(
                                  width: ProtocolPanel.collapsedSize.width,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Replié, le panneau occupe son emplacement ; déplié, il
                      // grandit vers le haut et recouvre le canevas à droite sans le
                      // redimensionner.
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: ProtocolPanel(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Port du rejeu vers la scène : la page lui prête ses deux gestes.
class _PageReplayStage implements ReplayStage {
  const _PageReplayStage({required this._clear, required this._exit});

  final void Function() _clear;
  final void Function() _exit;

  @override
  void clear() => _clear();

  @override
  void exit() => _exit();
}

/// Intentions des raccourcis de la page (014).
class _MicIntent extends Intent {
  const _MicIntent();
}

class _SilenceIntent extends Intent {
  const _SilenceIntent();
}
