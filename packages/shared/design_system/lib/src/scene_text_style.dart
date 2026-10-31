import 'package:flutter/widgets.dart';

/// Style résolu comme le fait `Text` dans [context] : le style ambiant
/// (`DefaultTextStyle`, donc la famille du thème) fusionné avec [style].
///
/// Sert partout où un texte n'est pas rendu par un `Text` (`TextPainter`,
/// boutons Material dont le style remplace celui de l'ambiance).
TextStyle sceneTextStyle(BuildContext context, TextStyle style) =>
    DefaultTextStyle.of(context).style.merge(style);
