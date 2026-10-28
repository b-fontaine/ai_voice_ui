import 'package:material_ui/material_ui.dart';

import 'ds_spacing.dart';

enum _DsButtonVariant { filled, tonal }

/// Bouton du DS. Variantes par constructeurs nommés.
class DsButton extends StatelessWidget {
  /// Bouton principal.
  const DsButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : _variant = _DsButtonVariant.filled;

  /// Bouton secondaire, tonal.
  const DsButton.tonal({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : _variant = _DsButtonVariant.tonal;

  final String label;

  /// `null` désactive le bouton.
  final VoidCallback? onPressed;
  final IconData? icon;
  final _DsButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final spacing = context.dsSpacing;
    final child = Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm),
      child: Text(label),
    );
    final iconWidget = icon == null ? null : Icon(icon);
    return switch (_variant) {
      _DsButtonVariant.filled => iconWidget == null
          ? FilledButton(onPressed: onPressed, child: child)
          : FilledButton.icon(onPressed: onPressed, icon: iconWidget, label: child),
      _DsButtonVariant.tonal => iconWidget == null
          ? FilledButton.tonal(onPressed: onPressed, child: child)
          : FilledButton.tonalIcon(onPressed: onPressed, icon: iconWidget, label: child),
    };
  }
}
