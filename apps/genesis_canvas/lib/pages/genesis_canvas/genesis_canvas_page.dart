import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:feature_canvas/feature_canvas.dart'
    show
        CanvasBloc,
        CanvasBoard,
        CanvasSourceStatus,
        CanvasSourceSubscribed,
        CanvasState;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart' show Catalog, SurfaceController;
import 'package:shared_core/shared_core.dart' show ExitHandler;

import '../../widgets/top_bar/top_bar.dart';
import 'capture_service.dart';
import 'engine_error_watcher.dart';

/// Fabrique du service de capture : la page lui fournit la fonction de sortie
/// finale (code ajusté par les erreurs du moteur).
typedef SnapshotFactory = CaptureService Function(ExitHandler exitHandler);

/// Page unique : orbe en haut, canevas dessous.
///
/// Racine de composition du moteur : elle crée le moteur genui (avec les
/// catalogues reçus) et le `CanvasBloc`, qu'elle injecte par constructeur,
/// puis les libère. Elle ne connaît ni la configuration ni les assets : la
/// couche `app` lui fournit le flux de rejeu et la fabrique de capture.
///
/// Si un flux de rejeu est fourni, elle le rejoue dans le Bloc ; à la fin du
/// rejeu, elle déclenche la capture PNG si le service est actif.
class GenesisCanvasPage extends StatefulWidget {
  const GenesisCanvasPage({
    super.key,
    required this.catalogs,
    required this.snapshotFactory,
    required this.exitHandler,
    required this.errorSink,
    this.replay,
  });

  final List<Catalog> catalogs;
  final SnapshotFactory snapshotFactory;
  final ExitHandler exitHandler;

  /// Destination des erreurs de rejeu et de capture (`stderr` en prod).
  final StringSink errorSink;

  /// Messages A2UI à rejouer ; `null` : canevas vide.
  final Stream<A2uiMessage>? replay;

  @override
  State<GenesisCanvasPage> createState() => _GenesisCanvasPageState();
}

class _GenesisCanvasPageState extends State<GenesisCanvasPage> {
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

  @override
  void initState() {
    super.initState();
    // Écoute dès la création : le moteur ne rejoue pas les erreurs passées.
    _engineErrors;
    final replay = widget.replay;
    if (replay != null) {
      _bloc.add(CanvasSourceSubscribed(replay));
    } else if (_snapshot.isActive) {
      // Sans scénario : capture du canevas vide après la première frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_captureWhenSettled()),
      );
    }
  }

  void _onSourceChanged(BuildContext context, CanvasState state) {
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
    // Le Bloc se ferme (annule le flux de rejeu) avant de libérer le moteur.
    unawaited(
      _bloc.close().whenComplete(() async {
        await _engineErrors.dispose();
        _controller.dispose();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<CanvasBloc>.value(
    value: _bloc,
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
              const Padding(padding: EdgeInsets.all(16), child: VoiceOrb()),
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
