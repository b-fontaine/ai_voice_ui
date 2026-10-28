import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

/// Espacements du DS, exposés via une ThemeExtension.
@immutable
class DsSpacing extends ThemeExtension<DsSpacing> {
  const DsSpacing({required this.sm, required this.md});

  static const regular = DsSpacing(sm: 8, md: 16);

  final double sm;
  final double md;

  @override
  DsSpacing copyWith({double? sm, double? md}) =>
      DsSpacing(sm: sm ?? this.sm, md: md ?? this.md);

  @override
  DsSpacing lerp(DsSpacing? other, double t) => other == null
      ? this
      : DsSpacing(
          sm: lerpDouble(sm, other.sm, t)!,
          md: lerpDouble(md, other.md, t)!,
        );
}

extension DsSpacingContext on BuildContext {
  DsSpacing get dsSpacing => Theme.of(this).extension<DsSpacing>()!;
}
