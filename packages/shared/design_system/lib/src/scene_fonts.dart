import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Familles de police embarquées par le paquet (U11).
///
/// Les familles sont déclarées sans préfixe dans le pubspec et référencées
/// avec le préfixe `packages/shared_design_system/` posé par Flutter dans le
/// `FontManifest.json` de l'app.
/// Le paramètre `package:` de `TextStyle` est volontairement évité : il
/// préfixerait aussi `fontFamilyFallback` et le neutraliserait.
abstract final class SceneFonts {
  static const String _prefix = 'packages/shared_design_system/';

  /// Texte courant et titres (fichier variable, axe `wght` 300 à 700).
  static const String sans = '${_prefix}Space Grotesk';

  /// Données, verdicts, libellés (fichier variable, axe `wght` 100 à 800).
  static const String mono = '${_prefix}JetBrains Mono';

  /// Repli des glyphes absents des deux familles (✓ ▲ ▶ ↺ ◆ ★, U+202F).
  static const String fallback = '${_prefix}DejaVu Sans';

  /// Valeur de `TextStyle.fontFamilyFallback`.
  static const List<String> fallbackList = <String>[fallback];
}

bool _licensesRegistered = false;

const List<(String, String)> _licenseAssets = <(String, String)>[
  (
    'Space Grotesk',
    'packages/shared_design_system/assets/fonts/OFL-SpaceGrotesk.txt',
  ),
  (
    'JetBrains Mono',
    'packages/shared_design_system/assets/fonts/OFL-JetBrainsMono.txt',
  ),
  (
    'DejaVu Sans',
    'packages/shared_design_system/assets/fonts/LICENSE-DejaVu.txt',
  ),
];

/// Enregistre les licences des trois polices (OFL pour Space Grotesk et
/// JetBrains Mono, Bitstream Vera pour DejaVu Sans) dans le [LicenseRegistry]
/// (page de licences de l'app). Idempotent : un second appel ne fait rien.
void registerSceneFontLicenses() {
  if (_licensesRegistered) return;
  _licensesRegistered = true;
  LicenseRegistry.addLicense(() async* {
    for (final (String name, String asset) in _licenseAssets) {
      final String text = await rootBundle.loadString(asset);
      yield LicenseEntryWithLineBreaks(<String>[name], text);
    }
  });
}
