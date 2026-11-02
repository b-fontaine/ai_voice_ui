import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Police du texte courant de la scène (celle de la capture Linux).
const String realFontFamily = 'Noto Sans';

/// Polices de repli, dans l'ordre (le glyphe « ★ » vient de DejaVu Sans).
const List<String> realFontFallback = <String>['DejaVu Sans'];

/// Polices réelles de la scène : famille et fichier. Avec la police de test
/// (Ahem), toutes les lignes ont la même hauteur et chaque glyphe fait la
/// taille de la police : ni un débordement dû au repli d'un glyphe ni un
/// libellé tronqué ne se mesurent.
const Map<String, String> realFontFiles = <String, String>{
  'Noto Sans': 'NotoSans-Regular.ttf',
  'DejaVu Sans': 'DejaVuSans.ttf',
};

/// Polices de l'app (paquet `shared_design_system`) : famille préfixée, telle
/// que Flutter la déclare dans le `FontManifest.json` d'une app, et fichier
/// sous `assets/fonts/` du paquet.
const Map<String, String> sceneFontFiles = <String, String>{
  'packages/shared_design_system/Space Grotesk': 'SpaceGrotesk-Variable.ttf',
  'packages/shared_design_system/JetBrains Mono': 'JetBrainsMono-Variable.ttf',
  'packages/shared_design_system/DejaVu Sans': 'DejaVuSans.ttf',
};

/// Dossier des fichiers de police, résolu par le `package_config.json` du
/// workspace (`Isolate.resolvePackageUri` n'est pas disponible sous
/// `flutter test`) : le test peut être lancé depuis n'importe quel dossier du
/// dépôt (hermétique, aucune dépendance aux polices du système).
Future<Directory> fontsDirectory() =>
    _packageDirectory('testing_real_fonts', 'fonts/');

/// Dossier `assets/fonts/` du paquet `shared_design_system`, résolu de la
/// même façon : les fichiers ne sont jamais copiés.
Future<Directory> sceneFontsDirectory() =>
    _packageDirectory('shared_design_system', 'assets/fonts/');

Future<Directory> _packageDirectory(String name, String subdirectory) async {
  var dir = Directory.current.absolute;
  while (true) {
    final File config = File('${dir.path}/.dart_tool/package_config.json');
    if (config.existsSync()) {
      final Map<String, Object?> json =
          jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
      for (final Object? entry in json['packages']! as List<Object?>) {
        final Map<String, Object?> package = entry! as Map<String, Object?>;
        if (package['name'] == name) {
          final Uri root = config.parent.uri.resolve('${package['rootUri']}/');
          return Directory.fromUri(root.resolve(subdirectory));
        }
      }
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        '$name introuvable dans un package_config.json '
        '(est-il une dépendance du paquet testé ?)',
      );
    }
    dir = parent;
  }
}

/// Charge les polices réelles dans le moteur de test. À appeler dans
/// `setUpAll`. [alsoAs] : familles supplémentaires qui reçoivent aussi la
/// police du texte courant (par exemple `Roboto`, la famille par défaut du
/// thème Material, pour qu'une app qui ne fixe pas sa police s'affiche avec
/// elle). [sceneFonts] charge aussi les trois familles de l'app sous leurs
/// noms préfixés (`FontLoader` depuis les octets du paquet de design).
Future<void> loadRealFonts({
  List<String> alsoAs = const <String>[],
  bool sceneFonts = true,
}) async {
  final Directory dir = await fontsDirectory();
  final Map<String, Uint8List> bytesOf = <String, Uint8List>{
    for (final MapEntry<String, String> font in realFontFiles.entries)
      font.key: File('${dir.path}/${font.value}').readAsBytesSync(),
  };
  Future<void> load(String family, Uint8List bytes) async {
    final FontLoader loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  for (final MapEntry<String, Uint8List> font in bytesOf.entries) {
    await load(font.key, font.value);
  }
  for (final String family in alsoAs) {
    await load(family, bytesOf[realFontFamily]!);
  }
  if (sceneFonts) {
    final Directory scene = await sceneFontsDirectory();
    for (final MapEntry<String, String> font in sceneFontFiles.entries) {
      await load(
        font.key,
        File('${scene.path}/${font.value}').readAsBytesSync(),
      );
    }
  }
}
