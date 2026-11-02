import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

void main() {
  final theme = sceneMaterialTheme();

  test('le thème de scène est installé comme extension du ThemeData', () {
    expect(theme.extension<SceneTheme>(), const SceneTheme.dark());
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const SceneTheme.dark().background);
  });

  test('tous les styles de texte de Material font au moins 24 px', () {
    final text = theme.textTheme;
    final styles = <String, TextStyle?>{
      'displayLarge': text.displayLarge,
      'displayMedium': text.displayMedium,
      'displaySmall': text.displaySmall,
      'headlineLarge': text.headlineLarge,
      'headlineMedium': text.headlineMedium,
      'headlineSmall': text.headlineSmall,
      'titleLarge': text.titleLarge,
      'titleMedium': text.titleMedium,
      'titleSmall': text.titleSmall,
      'bodyLarge': text.bodyLarge,
      'bodyMedium': text.bodyMedium,
      'bodySmall': text.bodySmall,
      'labelLarge': text.labelLarge,
      'labelMedium': text.labelMedium,
      'labelSmall': text.labelSmall,
    };
    styles.forEach((name, style) {
      expect(style?.fontSize, isNotNull, reason: name);
      expect(style!.fontSize, greaterThanOrEqualTo(24), reason: name);
    });
  });

  test(
    'Space Grotesk (+ repli) est la famille de tous les styles de Material',
    () {
      final text = theme.textTheme;
      final styles = <String, TextStyle?>{
        'displayLarge': text.displayLarge,
        'displayMedium': text.displayMedium,
        'displaySmall': text.displaySmall,
        'headlineLarge': text.headlineLarge,
        'headlineMedium': text.headlineMedium,
        'headlineSmall': text.headlineSmall,
        'titleLarge': text.titleLarge,
        'titleMedium': text.titleMedium,
        'titleSmall': text.titleSmall,
        'bodyLarge': text.bodyLarge,
        'bodyMedium': text.bodyMedium,
        'bodySmall': text.bodySmall,
        'labelLarge': text.labelLarge,
        'labelMedium': text.labelMedium,
        'labelSmall': text.labelSmall,
      };
      styles.forEach((name, style) {
        expect(style?.fontFamily, SceneFonts.sans, reason: name);
        expect(
          style?.fontFamilyFallback,
          SceneFonts.fallbackList,
          reason: name,
        );
      });
    },
  );

  test('graisses de Material : fontWeight et axe wght identiques', () {
    for (final TextStyle? style in <TextStyle?>[
      theme.textTheme.bodyMedium,
      theme.textTheme.titleLarge,
      theme.textTheme.labelLarge,
      theme.textTheme.displayLarge,
    ]) {
      final int wght = style!.fontWeight!.value;
      expect(style.fontVariations, sceneWeight(wght).variations);
    }
  });

  testWidgets('un Text sans style reçoit Space Grotesk et le repli', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Text('Bonjour')),
      ),
    );
    final RichText rich = tester.widget<RichText>(
      find.descendant(
        of: find.text('Bonjour'),
        matching: find.byType(RichText),
      ),
    );
    final TextStyle style = rich.text.style!;
    expect(style.fontFamily, SceneFonts.sans);
    expect(style.fontFamilyFallback, SceneFonts.fallbackList);
    expect(style.fontSize, greaterThanOrEqualTo(24));
  });

  test('boutons Material : texte en style button (Space Grotesk 600)', () {
    const scene = SceneTheme.dark();
    for (final ButtonStyle? style in <ButtonStyle?>[
      theme.textButtonTheme.style,
      theme.filledButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.elevatedButtonTheme.style,
    ]) {
      final TextStyle? text = style?.textStyle?.resolve(<WidgetState>{});
      expect(text, isNotNull);
      expect(text!.fontFamily, scene.button.fontFamily);
      expect(text.fontSize, scene.button.fontSize);
      expect(text.fontWeight, scene.button.fontWeight);
      expect(text.fontVariations, scene.button.fontVariations);
      expect(text.fontFamilyFallback, SceneFonts.fallbackList);
    }
  });
}
