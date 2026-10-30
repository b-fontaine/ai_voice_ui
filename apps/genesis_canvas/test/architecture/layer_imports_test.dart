import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // AGENTS.md § 2 : les imports ne descendent que vers les couches
  // inférieures. `app` est au-dessus de `pages` et de `widgets`.
  for (final layer in <String>['pages', 'widgets']) {
    test('lib/$layer n\'importe rien de la couche app', () {
      final files = Directory('lib/$layer')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      final upward = RegExp(
        r'''import\s+['"](?:[^'"]*\.\./app/|package:genesis_canvas/app/)''',
      );
      for (final file in files) {
        expect(
          upward.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: '${file.path} importe la couche app',
        );
      }
    });
  }
}
