import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Usage: aucune police n'est chargée par le réseau
///
/// Aucun `pubspec.yaml` du dépôt (app, paquets, bancs de test) ne dépend de
/// `google_fonts`, qui télécharge ses polices à l'exécution.
Future<void> aucunePoliceNestChargeeParLeReseau(WidgetTester tester) async {
  Directory root = Directory.current.absolute;
  while (!(Directory('${root.path}/packages').existsSync() &&
      Directory('${root.path}/apps').existsSync())) {
    final Directory parent = root.parent;
    expect(
      parent.path,
      isNot(root.path),
      reason: 'racine du dépôt introuvable',
    );
    root = parent;
  }
  final List<String> offenders = <String>[];
  for (final String dir in <String>['apps', 'packages', 'testing']) {
    final Directory base = Directory('${root.path}/$dir');
    if (!base.existsSync()) continue;
    for (final FileSystemEntity e in base.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('/pubspec.yaml')) continue;
      if (e.path.contains('/build/') || e.path.contains('/.dart_tool/')) {
        continue;
      }
      final bool uses = e.readAsLinesSync().any(
        (String l) => RegExp(r'^\s*google_fonts\s*:').hasMatch(l),
      );
      if (uses) offenders.add(e.path);
    }
  }
  expect(
    offenders,
    isEmpty,
    reason:
        'google_fonts télécharge les polices au réseau :\n'
        '${offenders.join('\n')}',
  );
}
