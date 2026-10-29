import 'dart:async';

import 'package:feature_canvas/api/canvas.dart'
    show CanvasBloc, CanvasSourceStatus, CanvasSourceSubscribed, CanvasState;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart'
    show BasicCatalogItems, Catalog, SurfaceController;
import 'package:shared_core/shared_core.dart'
    show ExitHandler, ReplayDelay, SnapshotService;

import '../../app/config/genesis_config.dart';
import '../../app/scenario/scenario_player.dart';
import '../../widgets/canvas_board/canvas_board.dart';
import '../../widgets/top_bar/top_bar.dart';

/// Page unique : orbe en haut, canevas dessous.
///
/// Racine de composition : elle crée le moteur genui (catalogue de base) et le
/// `CanvasBloc`, qu'elle injecte par constructeur, puis les libère.
///
/// Si la configuration nomme un scénario, elle le rejoue dans le Bloc ; à la
/// fin du rejeu, elle déclenche la capture PNG si un chemin est configuré.
class GenesisCanvasPage extends StatefulWidget {
  const GenesisCanvasPage({
    super.key,
    required this.config,
    required this.assetBundle,
    required this.exitHandler,
    required this.errorSink,
    this.replayDelay,
  });

  final GenesisConfig config;
  final AssetBundle assetBundle;
  final ExitHandler exitHandler;

  /// Destination des erreurs de rejeu et de capture (`stderr` en prod).
  final StringSink errorSink;

  /// Attente entre deux messages du rejeu ; `null` : délai réel.
  final ReplayDelay? replayDelay;

  @override
  State<GenesisCanvasPage> createState() => _GenesisCanvasPageState();
}

class _GenesisCanvasPageState extends State<GenesisCanvasPage> {
  late final SurfaceController _controller = SurfaceController(
    catalogs: <Catalog>[BasicCatalogItems.asCatalog()],
  );
  late final CanvasBloc _bloc = CanvasBloc(_controller);
  final GlobalKey _boundaryKey = GlobalKey();
  late final SnapshotService _snapshot = SnapshotService(
    path: widget.config.snapshotPath,
    exitHandler: widget.exitHandler,
    errorSink: widget.errorSink,
  );

  @override
  void initState() {
    super.initState();
    final scenario = widget.config.scenario;
    if (scenario != null) {
      _bloc.add(
        CanvasSourceSubscribed(
          ScenarioPlayer(
            bundle: widget.assetBundle,
            delay: widget.replayDelay,
          ).messages(scenario),
        ),
      );
    }
  }

  void _onSourceChanged(BuildContext context, CanvasState state) {
    switch (state.sourceStatus) {
      case CanvasSourceStatus.completed:
        if (_snapshot.isActive) unawaited(_captureWhenSettled());
      case CanvasSourceStatus.failed:
        widget.errorSink.writeln(
          'Rejeu "${widget.config.scenario}" impossible : ${state.sourceError}',
        );
        if (_snapshot.isActive) widget.exitHandler(1);
      case CanvasSourceStatus.none:
      case CanvasSourceStatus.playing:
        break;
    }
  }

  Future<void> _captureWhenSettled() async {
    // Laisse genui construire la surface avant la capture.
    for (var i = 0; i < 2; i++) {
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted) await _snapshot.captureAndExit(_boundaryKey);
  }

  @override
  void dispose() {
    // Le Bloc se ferme (annule le flux de rejeu) avant de libérer le moteur.
    unawaited(_bloc.close().whenComplete(_controller.dispose));
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
              Expanded(child: CanvasBoardView(controller: _controller)),
            ],
          ),
        ),
      ),
    ),
  );
}
