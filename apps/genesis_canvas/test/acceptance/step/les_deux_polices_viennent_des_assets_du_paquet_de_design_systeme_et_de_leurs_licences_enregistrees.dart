import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/scene_style_harness.dart';

/// Usage: les deux polices viennent des assets du paquet de design système et de leurs licences enregistrées
///
/// `FontManifest.json` déclare `Space Grotesk` et `JetBrains Mono` sous le
/// préfixe du paquet `shared_design_system`, avec des fichiers du même paquet ;
/// le `LicenseRegistry` porte leurs licences OFL.
Future<void>
lesDeuxPolicesViennentDesAssetsDuPaquetDeDesignSystemeEtDeLeursLicencesEnregistrees(
  WidgetTester tester,
) async {
  final String manifest = await SceneStyleHarness.fontManifest(tester);
  final List<dynamic> families = manifest.isEmpty
      ? <dynamic>[]
      : jsonDecode(manifest) as List<dynamic>;
  for (final String name in <String>[
    SceneStyleHarness.spaceGrotesk,
    SceneStyleHarness.jetBrainsMono,
  ]) {
    final String declared = '${SceneStyleHarness.packagePrefix}$name';
    final Map<String, dynamic>? entry = families
        .cast<Map<String, dynamic>>()
        .where((Map<String, dynamic> f) => f['family'] == declared)
        .firstOrNull;
    expect(
      entry,
      isNotNull,
      reason:
          'FontManifest.json ne déclare pas la famille « $declared » '
          '(familles : ${families.map((dynamic f) => (f as Map)['family']).join(', ')})',
    );
    final List<String> assets = <String>[
      for (final dynamic font in entry!['fonts'] as List<dynamic>)
        (font as Map<String, dynamic>)['asset'] as String,
    ];
    expect(
      assets,
      isNotEmpty,
      reason: '« $declared » ne déclare aucun fichier',
    );
    expect(
      assets.every(
        (String a) => a.startsWith('packages/shared_design_system/'),
      ),
      isTrue,
      reason: '« $declared » doit venir des assets du paquet : $assets',
    );
  }

  final List<LicenseEntry> licenses = (await tester.runAsync(
    () => LicenseRegistry.licenses.toList(),
  ))!;
  for (final String name in <String>[
    SceneStyleHarness.spaceGrotesk,
    SceneStyleHarness.jetBrainsMono,
  ]) {
    final bool registered = licenses.any((LicenseEntry e) {
      final String packages = e.packages.join(' ').toLowerCase();
      final String text = e.paragraphs
          .map((LicenseParagraph p) => p.text)
          .join('\n');
      return packages.contains(name.toLowerCase()) &&
          text.contains('SIL OPEN FONT LICENSE');
    });
    expect(
      registered,
      isTrue,
      reason: 'licence OFL de « $name » absente du LicenseRegistry',
    );
  }
}
