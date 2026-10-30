import 'dart:convert';
import 'dart:io';

import 'package:entity_catalog/entity_catalog.dart';
import 'package:test/test.dart';

/// Parité avec le validateur Go (spec 007, A5c) : chaque fixture négative
/// partagée est rejouée sur un validateur NEUF ; tous les messages sont
/// acceptés sauf le dernier, refusé avec le code de `expected.json`.
Directory _invalidDir() {
  var dir = Directory.current.absolute;
  while (true) {
    final c = Directory('${dir.path}/contracts/a2ui/genesis/v1/invalid');
    if (c.existsSync()) return c;
    if (dir.parent.path == dir.path) throw StateError('contracts/ introuvable');
    dir = dir.parent;
  }
}

void main() {
  final dir = _invalidDir();
  final expected = Map<String, String>.from(
    jsonDecode(File('${dir.path}/expected.json').readAsStringSync()) as Map,
  );
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.jsonl'))
      .toList();

  test('autant de fixtures .jsonl que d entrées de expected.json', () {
    expect(files, isNotEmpty);
    expect(files.length, expected.length);
    expect(
      files.map((f) => f.uri.pathSegments.last).toSet(),
      expected.keys.toSet(),
    );
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    test('$name est refusée avec ${expected[name]}', () {
      final messages = const LineSplitter()
          .convert(
            file.readAsStringSync().replaceAll(
              r'${CATALOG_ID}',
              GenesisContract.defaultCatalogId,
            ),
          )
          .where((l) => l.trim().isNotEmpty)
          .map((l) => Map<String, Object?>.from(jsonDecode(l) as Map))
          .toList();
      expect(messages, isNotEmpty);
      final validator = GenesisMessageValidator();
      for (var i = 0; i < messages.length; i++) {
        final verdict = validator.check(messages[i]).verdict;
        if (i < messages.length - 1) {
          expect(
            verdict,
            const ValidationAccepted(),
            reason: 'message ${i + 1}',
          );
        } else {
          expect(verdict, ValidationRejected(expected[name]!));
        }
      }
    });
  }
}
