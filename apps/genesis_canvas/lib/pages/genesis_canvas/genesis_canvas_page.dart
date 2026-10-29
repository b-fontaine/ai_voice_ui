import 'package:flutter/widgets.dart';

import '../../widgets/canvas_board/canvas_board.dart';
import '../../widgets/top_bar/top_bar.dart';

/// Page unique : orbe en haut, canevas dessous.
class GenesisCanvasPage extends StatelessWidget {
  const GenesisCanvasPage({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF0B0B14),
    child: Column(
      children: <Widget>[
        Padding(padding: EdgeInsets.all(16), child: VoiceOrb()),
        Expanded(child: CanvasBoardView()),
      ],
    ),
  );
}
