import 'package:flutter/material.dart';

import 'scene_status.dart';
import 'scene_theme.dart';

/// Pastille de statut : la couleur vient du [SceneStatus], le libellé
/// (fourni par le backend) est affiché tel quel. Statut `null` : style neutre.
class DsStatusChip extends StatelessWidget {
  const DsStatusChip({super.key, required this.status, required this.label});

  /// Remplissage horizontal de chaque côté du libellé.
  static const double horizontalPadding = 16;

  final SceneStatus? status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = SceneTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.statusBackground(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 6,
        ),
        child: Text(
          label,
          style: theme.label.copyWith(color: theme.statusForeground(status)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
