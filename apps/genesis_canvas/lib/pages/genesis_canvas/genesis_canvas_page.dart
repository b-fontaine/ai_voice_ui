import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:entity_session/entity_session.dart'
    show A2uiEnvelopeReceived, SessionEvent;
import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentActivityBloc, AgentActivitySourceSubscribed;
import 'package:feature_canvas/feature_canvas.dart'
    show
        CanvasBloc,
        CanvasBoard,
        CanvasSourceStatus,
        CanvasSourceSubscribed,
        CanvasState;
import 'package:feature_voice_session/feature_voice_session.dart'
    show
        LiveSessionEventSource,
        OrbLevelController,
        OrbSmoother,
        TranscriptBloc,
        TranscriptSourceSubscribed,
        VoiceSession,
        VoiceSessionBloc,
        VoiceSessionSubscribed;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart' show Catalog, SurfaceController;
import 'package:get_it/get_it.dart';
import 'package:shared_core/shared_core.dart' show ExitHandler;

import '../../app/config/genesis_config.dart';
import '../../app/lifecycle/exit_guard.dart';
import '../../widgets/agents_rail/agents_rail.dart';
import '../../widgets/top_bar/top_bar.dart';
import 'capture_service.dart';
import 'engine_error_watcher.dart';

/// Fabrique du service de capture : la page lui fournit la fonction de sortie
/// finale (code ajusté par les erreurs du moteur).
typedef SnapshotFactory = CaptureService Function(ExitHandler exitHandler);

/// Page unique : barre du haut (orbe, transcription, bouton), rail des
/// agents, puis canevas.
///
/// **Racine de composition** : seul endroit, avec `app/di`, qui touche à
/// [GetIt] (reçu par constructeur, jamais lu depuis un widget ni un Bloc). Elle
/// résout UNE `VoiceSession`, construit avec cette instance la source
/// d'événements et le `VoiceSessionBloc`, puis branche tous les abonnés avant
/// toute connexion (le flux est en diffusion : un abonné tardif perdrait des
/// événements). Elle possède ce qu'elle crée et le ferme dans l'ordre (voir
/// `_shutdown`).
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
    this.replay,
    this.onClosing,
  });

  /// Graphe de dépendances de cette app (instance propre, configurée par la
  /// couche `app`).
  final GetIt getIt;
  final List<Catalog> catalogs;
  final SnapshotFactory snapshotFactory;
  final ExitHandler exitHandler;

  /// Destination des erreurs de rejeu et de capture (`stderr` en prod).
  final StringSink errorSink;

  /// Messages A2UI à rejouer ; `null` : source vivante, canevas vide au départ.
  final Stream<A2uiMessage>? replay;

  /// Reçoit la fermeture asynchrone lancée par le `dispose` de la page, pour
  /// que le propriétaire du graphe ne le libère qu'une fois la page fermée.
  final ValueChanged<Future<void>>? onClosing;

  @override
  State<GenesisCanvasPage> createState() => _GenesisCanvasPageState();
}

class _GenesisCanvasPageState extends State<GenesisCanvasPage>
    with TickerProviderStateMixin {
  late final GenesisConfig _config = widget.getIt<GenesisConfig>();

  // Voix : UNE session, partagée par la source d'événements et le Bloc.
  late final VoiceSession _session = widget.getIt<VoiceSession>();
  late final LiveSessionEventSource _source = LiveSessionEventSource(_session);
  late final VoiceSessionBloc _voiceBloc = VoiceSessionBloc(_session);
  late final TranscriptBloc _transcriptBloc = widget.getIt<TranscriptBloc>();
  late final AgentActivityBloc _agentsBloc = widget.getIt<AgentActivityBloc>();
  late final OrbLevelController _orb = OrbLevelController(
    vsync: this,
    events: _source.events,
    smoother: OrbSmoother(
      attack: _config.orbAttack,
      release: _config.orbRelease,
    ),
    silenceTimeout: _config.orbSilenceTimeout,
  );

  // Canevas.
  late final SurfaceController _controller = SurfaceController(
    catalogs: widget.catalogs,
  );
  late final CanvasBloc _bloc = CanvasBloc(_controller);
  final GlobalKey _boundaryKey = GlobalKey();
  late final EngineErrorWatcher _engineErrors = EngineErrorWatcher(
    onSubmit: _controller.onSubmit,
    errorSink: widget.errorSink,
  );
  late final CaptureService _snapshot = widget.snapshotFactory(
    // Une capture réussie ne vaut pas succès si le moteur a signalé des erreurs.
    (code) =>
        widget.exitHandler(code == 0 && _engineErrors.count > 0 ? 1 : code),
  );

  late final ExitGuard _exitGuard = ExitGuard(
    _session.stop,
    _config.exitCloseTimeout,
  );
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onExitRequested: _exitGuard.onExitRequested,
  );

  bool get _replayMode => widget.replay != null;

  /// Captures et rejeus : l'animation de l'orbe est coupée pour que les images
  /// restent déterministes (et que `pumpAndSettle` converge).
  bool get _animationsOff => _replayMode || _snapshot.isActive;

  @override
  void initState() {
    super.initState();
    // Écoute dès la création : le moteur ne rejoue pas les erreurs passées.
    _engineErrors;
    _lifecycle;
    _orb;
    // Tous les abonnés se branchent avant toute connexion.
    _voiceBloc.add(const VoiceSessionSubscribed());
    _transcriptBloc.add(TranscriptSourceSubscribed(_source.events));
    _agentsBloc.add(AgentActivitySourceSubscribed(_source.events));
    final replay = widget.replay;
    if (replay != null) {
      _bloc.add(CanvasSourceSubscribed(replay));
    } else {
      // Sous-flux dérivé UNE fois, donné une fois au Bloc du canevas.
      _bloc.add(CanvasSourceSubscribed(_a2uiMessages(_source.events)));
      if (_snapshot.isActive) {
        // Sans scénario : capture du canevas vide après la première frame.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(_captureWhenSettled()),
        );
      }
    }
  }

  static Stream<A2uiMessage> _a2uiMessages(Stream<SessionEvent> events) =>
      events
          .where((event) => event is A2uiEnvelopeReceived)
          .map((event) => (event as A2uiEnvelopeReceived).message);

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
  /// 5. Blocs de transcription, d'activité puis du canevas ;
  /// 6. moteur genui, une fois le Bloc du canevas fermé.
  Future<void> _shutdown() async {
    final bound = _config.sessionCloseTimeout;
    await _step('Bloc de session', _voiceBloc.close);
    await _step('arrêt de la session', _session.stop, timeout: bound);
    await _step('libération de la session', _session.dispose, timeout: bound);
    await _step('source d\'événements', _source.dispose);
    await _step('Bloc de transcription', _transcriptBloc.close);
    await _step('Bloc des agents', _agentsBloc.close);
    await _step('Bloc du canevas', _bloc.close);
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

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<VoiceSessionBloc>.value(value: _voiceBloc),
      BlocProvider<TranscriptBloc>.value(value: _transcriptBloc),
      BlocProvider<AgentActivityBloc>.value(value: _agentsBloc),
      BlocProvider<CanvasBloc>.value(value: _bloc),
    ],
    child: BlocListener<CanvasBloc, CanvasState>(
      listenWhen: (previous, current) =>
          previous.sourceStatus != current.sourceStatus,
      listener: _onSourceChanged,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: ColoredBox(
          color: const Color(0xFF0B0B14),
          child: Column(
            children: <Widget>[
              TickerMode(
                enabled: !_animationsOff,
                child: TopBar(
                  orbLevel: _orb.level,
                  speakingThreshold: _config.orbSpeakingThreshold,
                  startEnabled: !_replayMode,
                ),
              ),
              const AgentsRail(),
              Expanded(
                child: CanvasBoard(
                  key: const Key('canvas-board'),
                  controller: _controller,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
