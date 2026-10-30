import 'package:flutter/material.dart';

import 'scene_theme.dart';

/// État neutre (RG-10) : message court, jamais d'erreur affichée.
class DsNeutralState extends StatelessWidget {
  const DsNeutralState({super.key, this.message = 'Données indisponibles'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = SceneTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 32,
              color: theme.textSecondary,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: theme.body.copyWith(color: theme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
