import 'package:ds_spike/ds_spike.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' show textContrastGuideline;
import 'package:material_ui/material_ui.dart' as m;
import 'package:widgetbook/widgetbook.dart';

import 'components.g.dart';

/// Les widgets du DS cherchent les ancêtres `Theme`/`Material` de
/// material_ui : l'appBuilder par défaut (flutter/material) ne convient pas.
Widget materialUiAppBuilder(BuildContext context, Widget child) {
  return m.MaterialApp(
    debugShowCheckedModeBanner: false,
    // Marge : sans elle, les cibles qui touchent le bord du snapshot
    // échappent au contrôle de taille (isAtBoundary).
    home: m.Material(
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    ),
  );
}

/// Règles desktop : WCAG 2.2 AA (2.5.8, 24×24) au lieu des seuils tactiles
/// 48/44 du jeu `recommended`, que la densité compacte ne respecte pas.
const desktopGuidelines = <WidgetbookGuideline>[
  MinTapTargetGuideline(
    id: 'tap-target-wcag-aa',
    size: Size(24, 24),
    helpUrl: 'https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html',
  ),
  LabeledTappableGuideline(),
  FlutterGuideline(textContrastGuideline, id: 'text-contrast'),
];

Widget dsThemeBuilder(BuildContext context, m.ThemeData theme, Widget child) =>
    m.Theme(
      data: theme,
      // Fond de surface pour voir le thème sombre.
      child: m.ColoredBox(color: theme.colorScheme.surface, child: child),
    );

final config = Config(
  components: components,
  accessibilityConfig: const AccessibilityConfig(guidelines: desktopGuidelines),
  // Chaque story est capturée (et auditée) en clair et en sombre. Déclarer
  // des définitions supprime le scénario implicite « Default » : d'où « Light ».
  scenarioConfig: ScenarioConfig(
    definitions: [
      ScenarioDefinition(
        name: 'Light',
        modes: [ThemeMode<m.ThemeData>('Light', DsTheme.light(), dsThemeBuilder)],
      ),
      ScenarioDefinition(
        name: 'Dark',
        modes: [ThemeMode<m.ThemeData>('Dark', DsTheme.dark(), dsThemeBuilder)],
      ),
    ],
  ),
  appBuilder: materialUiAppBuilder,
  addons: [
    ViewportAddon(Viewports.all),
    ThemeAddon<m.ThemeData>(
      {'Light': DsTheme.light(), 'Dark': DsTheme.dark()},
      dsThemeBuilder,
    ),
    TextScaleAddon(),
    AlignmentAddon(),
    SemanticsAddon(),
  ],
);
