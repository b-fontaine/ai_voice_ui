import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

void main() {
  const SceneTheme theme = SceneTheme.dark();
  final ButtonStyle style = sceneTargetStyle(theme);

  test('le focus clavier dessine un anneau accent de 2 points', () {
    final BorderSide? side = style.side?.resolve(<WidgetState>{
      WidgetState.focused,
    });
    expect(side?.color, theme.accent);
    expect(side?.width, 2);
  });

  test('sans focus, aucune bordure', () {
    expect(style.side?.resolve(<WidgetState>{}), BorderSide.none);
    expect(
      style.side?.resolve(<WidgetState>{WidgetState.hovered}),
      BorderSide.none,
    );
  });

  test('la cible fait au moins 48 points de haut, sans marge', () {
    expect(style.minimumSize?.resolve(<WidgetState>{})?.height, 48);
    expect(style.padding?.resolve(<WidgetState>{}), EdgeInsets.zero);
    expect(
      sceneTargetStyle(theme, height: 56).minimumSize?.resolve({})?.height,
      56,
    );
  });

  test('le fond est transparent et le rayon par défaut est md', () {
    expect(style.backgroundColor?.resolve(<WidgetState>{})?.a, 0);
    expect(
      style.shape?.resolve(<WidgetState>{}),
      const RoundedRectangleBorder(borderRadius: SceneRadius.borderMd),
    );
  });
}
