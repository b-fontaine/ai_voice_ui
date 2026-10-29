import 'package:feature_canvas/api/canvas.dart' show CanvasBloc;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart'
    show BasicCatalogItems, Catalog, SurfaceController;

import '../../widgets/canvas_board/canvas_board.dart';
import '../../widgets/top_bar/top_bar.dart';

/// Page unique : orbe en haut, canevas dessous.
///
/// Racine de composition : elle crée le moteur genui (catalogue de base) et le
/// `CanvasBloc`, qu'elle injecte par constructeur, puis les libère.
class GenesisCanvasPage extends StatefulWidget {
  const GenesisCanvasPage({super.key});

  @override
  State<GenesisCanvasPage> createState() => _GenesisCanvasPageState();
}

class _GenesisCanvasPageState extends State<GenesisCanvasPage> {
  late final SurfaceController _controller = SurfaceController(
    catalogs: <Catalog>[BasicCatalogItems.asCatalog()],
  );
  late final CanvasBloc _bloc = CanvasBloc(_controller);

  @override
  void dispose() {
    _bloc.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<CanvasBloc>.value(
    value: _bloc,
    child: ColoredBox(
      color: const Color(0xFF0B0B14),
      child: Column(
        children: <Widget>[
          const Padding(padding: EdgeInsets.all(16), child: VoiceOrb()),
          Expanded(child: CanvasBoardView(controller: _controller)),
        ],
      ),
    ),
  );
}
