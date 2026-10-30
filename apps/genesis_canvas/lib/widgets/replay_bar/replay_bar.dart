import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

/// Emplacement de la zone « REJEU » (D3) : libellé et commandes visibles mais
/// inactives jusqu'au rejeu A2UI (J6).
class ReplayBar extends StatelessWidget {
  const ReplayBar({super.key = const Key('replay-bar')});

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final ButtonStyle inactive = IconButton.styleFrom(
      // Inactives mais lisibles à distance (le gris par défaut disparaît).
      disabledForegroundColor: theme.neutralForeground,
      iconSize: 36,
    );
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'REJEU',
                style: theme.label.copyWith(color: theme.accent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: null,
                    style: inactive,
                    icon: const Icon(
                      Icons.play_arrow,
                      semanticLabel: 'Lecture',
                    ),
                  ),
                  IconButton(
                    onPressed: null,
                    style: inactive,
                    icon: const Icon(Icons.pause, semanticLabel: 'Pause'),
                  ),
                  IconButton(
                    onPressed: null,
                    style: inactive,
                    icon: const Icon(
                      Icons.replay,
                      semanticLabel: 'Recommencer',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
