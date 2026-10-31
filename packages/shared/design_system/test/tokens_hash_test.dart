import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le fichier généré porte le sha256 des tokens : il est périmé si les
/// `tokens/*.tokens.json` ont changé sans relancer `tool/build_tokens.sh`.
/// Le contrôle ne demande pas Node (adr-0005, pdr-0075 D4).
void main() {
  test('scene_tokens.g.dart correspond aux tokens sources', () {
    final generated = File('lib/src/generated/scene_tokens.g.dart');
    expect(
      generated.existsSync(),
      isTrue,
      reason: 'fichier généré absent : lancer tool/build_tokens.sh',
    );

    final files =
        Directory('tokens')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.tokens.json'))
            .toList()
          ..sort(
            (a, b) =>
                a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last),
          );
    expect(files, isNotEmpty);

    final builder = BytesBuilder();
    for (final file in files) {
      builder.add(file.readAsBytesSync());
    }
    final expected = sha256.convert(builder.toBytes()).toString();

    final header = RegExp(
      r'^// tokens-sha256: ([0-9a-f]{64})$',
      multiLine: true,
    ).firstMatch(generated.readAsStringSync());
    expect(header, isNotNull, reason: 'en-tête « tokens-sha256 » introuvable');
    expect(
      header!.group(1),
      expected,
      reason: 'fichier généré périmé : lancer tool/build_tokens.sh',
    );
  });
}
