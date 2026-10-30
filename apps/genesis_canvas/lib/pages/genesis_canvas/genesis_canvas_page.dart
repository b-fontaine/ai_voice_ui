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
        CanvasActionBloc,
        CanvasActionScope,
        CanvasActionSettings,
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
        ProtocolFeedState,
        ProtocolSourceSubscribed;
import 'package:feature_stage_controls/feature_stage_controls.dart'
    show StageBloc, StageResetRequested;
import 'package:feature_voice_session/feature_voice_session.dart'
    show
        Connecting,
        Failed,
        Idle,
        LiveSessionEventSource,
        OrbLevelController,
        OrbSmoother,
        Stopping,
        TranscriptBloc,
        TranscriptSourceSubscribed,
        VoiceSession,
        VoiceSessionBloc,
        VoiceSessionStatus,
        VoiceSessionSubscribed;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart' show Catalog, SurfaceController;
import 'package:get_it/get_it.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart'
    show CanvasActionClient, CanvasResetClient, CanvasResetResult;
import 'package:shared_core/shared_core.dart'
    show AppClock, ExitGuard, ExitHandler, ReplayedMessage;
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

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

/// Page unique à six zones (écran de 1920 × 1080, budget de `plan.md` de la
/// spec 007) : barre du haut (orbe, transcription, acte, remise à vide,
/// bouton), rail des agents, canevas, puis une rangée du bas (étagère du
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
  late final AgentActivityBloc _agentsBloc = widget.getIt<AgentActivityBloc>();
  // Écran de fabrication : panneau du protocole (horloge de l'app, pdr-0038),
  // étagère du catalogue et régie des actes.
  late final ProtocolFeedBloc _protocolBloc = ProtocolFeedBloc(
    clock: widget.getIt<AppClock>(),
  );
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

  bool get _replayMode => widget.replay != null;

  /// Captures et rejeus : l'animation de l'orbe est coupée pour que les images
  /// restent déterministes (et que `pumpAndSettle` converge).
  bool get _animationsOff => _replayMode || _snapshot.isActive;

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
    _agentsBloc.add(AgentActivitySourceSubscribed(_source.events));
    _activitySubscription = _agentsBloc.stream
        .map((AgentActivityState state) => state.anyBusy)
        .distinct()
        .listen(
          (bool busy) => _actionBloc.add(ActionActivityChanged(busy: busy)),
        );
    // Panneau et étagère lisent le flux validé (tous les messages, avec leur
    // verdict) par des branches qui gardent en mémoire ce qui arrive avant
    // l'abonnement effectif du Bloc.
    _protocolBloc.add(ProtocolSourceSubscribed(_gate.validatedBranch()));
    _shelfBloc.add(CatalogShelfSourceSubscribed(_gate.validatedBranch()));
    // Un seul flux de `SessionEvent` entre dans le gate : le flux vivant, ou
    // le rejeu encapsulé en enveloppes (la source vivante n'alimente alors pas
    // le canevas). Le Bloc ne reçoit que les messages acceptés.
    final replay = widget.replay;
    _bloc.add(CanvasSourceSubscribed(_gate.accepted));
    _gate.attach(
      replay == null ? _source.events : A2uiGate.replayEvents(replay),
    );
    if (replay == null) {
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
    _gate.reset();
    _bloc.add(const CanvasResetRequested());
    _protocolBloc.add(const ProtocolFeedCleared());
    _shelfBloc.add(const CatalogShelfCleared());
    _agentsBloc.add(const AgentActivityReset());
    _stageBloc.add(const StageResetRequested());
    _actionBloc.add(const ActionStageReset());
    unawaited(_requestBackendReset());
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
    // « Rejeu impossible » ne concerne que le rejeu ; la source vivante ne
    // se termine qu'à la fermeture de la page.
    if (!_replayMode) return;
    switch (state.sourceStatus) {
      case CanvasSourceStatus.completed:
        if (_snapshot.isActive) unawaited(_captureWhenSettled());
      case CanvasSourceStatus.failed:
        widget.errorSink.writeln('Rejeu impossible : ${state.sourceError}');
        if (_snapshot.isActive) widget.exitHandler(1);
      case CanvasSourceStatus.none:
      case CanvasSourceStatus.playing:
        break;
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
    if (!mounted) {
      widget.errorSink.writeln('Capture impossible : page démontée.');
      widget.exitHandler(1);
      return;
    }
    await _snapshot.captureAndExit(_boundaryKey);
  }

  @override
  void dispose() {
    // Plus de réessai de remise à vide une fois la page fermée.
    _resetGeneration++;
    _cancelRetryWait();
    unawaited(_statusSubscription?.cancel());
    unawaited(_activitySubscription?.cancel());
    _lifecycle.dispose();
    // L'orbe est un abonné de la source et porte un Ticker de ce State : elle
    // se ferme tout de suite (le mixin refuse un Ticker actif au dispose), donc
    // avant la source qu'elle écoute.
    _orb.dispose();
    final closing = _shutdown();
    unawaited(closing);
    widget.onClosing?.call(closing);
    super.dispose();
  }

  /// Fermeture ordonnée, jamais d'exception non gérée : un objet n'est libéré
  /// qu'après ses consommateurs.
  ///
  /// 1. `VoiceSessionBloc` (plus de commande ni d'abonné au statut) ;
  /// 2. arrêt de la session, borné ;
  /// 3. libération de la session ;
  /// 4. source d'événements (la session ne lui émet plus rien) ;
  /// 5. filtre A2UI (il se nourrit de la source) ;
  /// 6. Blocs de transcription, d'action, d'activité (que le Bloc d'action
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
    await _step('filtre A2UI', _gate.dispose);
    await _step('Bloc de transcription', _transcriptBloc.close);
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
  /// reste (572 px : grille 2 × 250 et bandeau de 72). La barre supérieure cède
  /// 32 px (160 → 128), le rail garde ses 200 px (cinq lignes possibles).
  static const double _railHeight = 200;
  static const double _bottomRowHeight = 140;
  static const double _replayWidth = 480;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider<VoiceSessionBloc>.value(value: _voiceBloc),
      BlocProvider<TranscriptBloc>.value(value: _transcriptBloc),
      BlocProvider<AgentActivityBloc>.value(value: _agentsBloc),
      BlocProvider<CanvasActionBloc>.value(value: _actionBloc),
      BlocProvider<CanvasBloc>.value(value: _bloc),
      BlocProvider<ProtocolFeedBloc>.value(value: _protocolBloc),
      BlocProvider<CatalogShelfBloc>.value(value: _shelfBloc),
      BlocProvider<StageBloc>.value(value: _stageBloc),
    ],
    child: MultiBlocListener(
      listeners: [
        BlocListener<CanvasBloc, CanvasState>(
          listenWhen: (previous, current) =>
              previous.sourceStatus != current.sourceStatus,
          listener: _onSourceChanged,
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
                      child: TopBar(
                        orbLevel: _orb.level,
                        speakingThreshold: _settings.orbSpeakingThreshold,
                        startEnabled: !_replayMode,
                        stage: StageBar(onResetPressed: _resetStage),
                      ),
                    ),
                    const SizedBox(height: _gap),
                    const SizedBox(height: _railHeight, child: AgentsRail()),
                    const SizedBox(height: _gap),
                    Expanded(
                      child:
                          BlocSelector<
                            ProtocolFeedBloc,
                            ProtocolFeedState,
                            String?
                          >(
                            selector: (state) => state.highlightedSurfaceId,
                            builder: (context, highlighted) =>
                                CanvasActionScope(
                                  // Rejeu : aucune requête ne part.
                                  enabled: !_replayMode,
                                  child: CanvasBoard(
                                    key: const Key('canvas-board'),
                                    controller: _controller,
                                    highlightedSurfaceId: highlighted,
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
                          SizedBox(width: ProtocolPanel.collapsedSize.width),
                        ],
                      ),
                    ),
                  ],
                ),
                // Replié, le panneau occupe son emplacement ; déplié, il
                // grandit vers le haut et recouvre le canevas à droite sans le
                // redimensionner.
                const Positioned(right: 0, bottom: 0, child: ProtocolPanel()),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
