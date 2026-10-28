import 'package:material_ui/material_ui.dart';

import 'ds_spacing.dart';

/// Thèmes du DS : graine unique, clair et sombre.
abstract final class DsTheme {
  static const _seed = Color(0xFF3355FF);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    ),
    visualDensity: VisualDensity.compact,
    extensions: const [DsSpacing.regular],
  );
}
