import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Dossier des polices du paquet (les tests tournent à la racine du paquet).
final Directory _fontsDir = Directory('assets/fonts');

const List<String> _binaryFiles = <String>[
  'SpaceGrotesk-Variable.ttf',
  'JetBrainsMono-Variable.ttf',
  'DejaVuSans.ttf',
  'OFL-SpaceGrotesk.txt',
  'OFL-JetBrainsMono.txt',
  'LICENSE-DejaVu.txt',
];

String _sha256(String name) => sha256
    .convert(File('${_fontsDir.path}/$name').readAsBytesSync())
    .toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('familles', () {
    test('les noms portent le préfixe du paquet, en clair', () {
      expect(SceneFonts.sans, 'packages/shared_design_system/Space Grotesk');
      expect(SceneFonts.mono, 'packages/shared_design_system/JetBrains Mono');
      expect(SceneFonts.fallback, 'packages/shared_design_system/DejaVu Sans');
      expect(SceneFonts.fallbackList, <String>[SceneFonts.fallback]);
    });

    test('le pubspec déclare les trois familles et leurs fichiers', () async {
      // Sous `flutter test` du paquet lui-même, Flutter ne préfixe pas ses
      // propres familles ; le préfixe est posé quand une app dépend du paquet
      // (vérifié par le step U-02 sur le FontManifest de l'app).
      final String manifest = await rootBundle.loadString('FontManifest.json');
      final Map<String, List<String>> assetsOf = <String, List<String>>{
        for (final dynamic f in jsonDecode(manifest) as List<dynamic>)
          (f as Map<String, dynamic>)['family'] as String: <String>[
            for (final dynamic font in f['fonts'] as List<dynamic>)
              (font as Map<String, dynamic>)['asset'] as String,
          ],
      };
      String bare(String family) =>
          family.replaceFirst('packages/shared_design_system/', '');
      for (final String family in <String>[
        SceneFonts.sans,
        SceneFonts.mono,
        SceneFonts.fallback,
      ]) {
        final String? key = assetsOf.keys
            .where((String k) => bare(k) == bare(family))
            .firstOrNull;
        expect(key, isNotNull, reason: 'famille $family absente: $assetsOf');
        expect(assetsOf[key], hasLength(1));
        expect(assetsOf[key]!.single, endsWith('.ttf'));
      }
    });
  });

  group('licences', () {
    test('registerSceneFontLicenses alimente LicenseRegistry, deux appels '
        'ne dupliquent rien', () async {
      registerSceneFontLicenses();
      registerSceneFontLicenses();
      final List<LicenseEntry> entries = await LicenseRegistry.licenses
          .toList();
      for (final String name in <String>['Space Grotesk', 'JetBrains Mono']) {
        final List<LicenseEntry> mine = entries
            .where((LicenseEntry e) => e.packages.contains(name))
            .toList();
        expect(mine, hasLength(1), reason: 'licence de $name');
        final String text = mine.single.paragraphs
            .map((LicenseParagraph p) => p.text)
            .join('\n');
        expect(text, contains('SIL OPEN FONT LICENSE'));
        expect(text, contains(name));
      }
    });
  });

  group('intégrité des fichiers', () {
    test('aucun nom de fichier ne contient de crochet', () {
      final List<String> names = _fontsDir
          .listSync()
          .map((FileSystemEntity e) => e.uri.pathSegments.last)
          .toList();
      expect(names, isNotEmpty);
      expect(
        names.where((String n) => n.contains(RegExp('[\\[\\]]'))),
        isEmpty,
      );
    });

    test('tous les fichiers attendus sont présents', () {
      final Set<String> names = _fontsDir
          .listSync()
          .map((FileSystemEntity e) => e.uri.pathSegments.last)
          .toSet();
      expect(names, containsAll(_binaryFiles));
    });

    for (final String doc in <String>['README.md', 'LICENSES.md']) {
      test('$doc consigne le SHA-256 recalculé de chaque fichier', () {
        final String text = File('${_fontsDir.path}/$doc').readAsStringSync();
        for (final String name in _binaryFiles) {
          expect(text, contains(name), reason: '$doc ne cite pas $name');
          expect(
            text,
            contains(_sha256(name)),
            reason: '$doc : empreinte de $name absente ou périmée',
          );
        }
      });
    }

    test('les documents épinglent le commit de google/fonts', () {
      const String commit = '6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec';
      for (final String doc in <String>['README.md', 'LICENSES.md']) {
        expect(
          File('${_fontsDir.path}/$doc').readAsStringSync(),
          contains(commit),
        );
      }
    });

    test('les deux OFL ne déclarent aucun nom de police réservé', () {
      for (final String name in <String>[
        'OFL-SpaceGrotesk.txt',
        'OFL-JetBrainsMono.txt',
      ]) {
        final String first = File('${_fontsDir.path}/$name')
            .readAsLinesSync()
            .first;
        expect(first, startsWith('Copyright'));
        expect(first, isNot(contains('Reserved Font Name')));
      }
    });
  });
}
