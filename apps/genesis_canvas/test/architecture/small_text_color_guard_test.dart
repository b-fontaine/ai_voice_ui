import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contraste des petits textes (pdr-0088 F12, plan P5) : un texte de moins de
/// 24 px (18,66 px en gras) n'est jamais en `inkFaint` ni en `agentIdle`
/// (4,35:1 au mieux, sous les 4,5:1 du texte courant) : il prend `ink-muted`.
/// `ink-faint` reste pour le décoratif (axes, traits, points) et les composants
/// inactifs.
///
/// Détecteur : hors du paquet de design, une source de `lib/` ne passe
/// `inkFaint` ni `agentIdle` à un style de texte (`TextStyle(...)` ou
/// `.copyWith(...)` ouvert, non refermé, avant l'usage). LIMITE : une couleur
/// lue dans une variable intermédiaire puis posée sur un texte ne se détecte
/// pas par expression régulière ; la suite d'acceptation (V-11) mesure les
/// textes réellement rendus.

Directory _root() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/tools/loop/gate.sh').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('racine du dépôt introuvable');
    }
    dir = parent;
  }
  return dir;
}

List<File> _libSources(Directory root) {
  final files = <File>[];
  for (final name in <String>['apps', 'packages']) {
    final dir = Directory('${root.path}/$name');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      final relative = entity.path.substring(root.path.length + 1);
      if (!relative.contains('/lib/')) continue;
      if (relative.startsWith('packages/shared/design_system/')) continue;
      if (relative.contains('/build/') ||
          relative.contains('/.dart_tool/') ||
          relative.contains('/ephemeral/')) {
        continue;
      }
      files.add(entity);
    }
  }
  return files;
}

/// Source sans commentaires de ligne, en gardant la numérotation.
String _withoutLineComments(String source) => source
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
    .join('\n');

final RegExp _faint = RegExp(r'\b(inkFaint|agentIdle)\b');

/// Numéros de ligne (à partir de 1) où une couleur interdite est passée à un
/// style de texte.
List<int> faintTextColorLines(String source) {
  final code = _withoutLineComments(source);
  final hits = <int>[];
  for (final match in _faint.allMatches(code)) {
    final before = code.substring(0, match.start);
    // Début de l'instruction ou du bloc courant.
    final start = [
      before.lastIndexOf(';'),
      before.lastIndexOf('{'),
      before.lastIndexOf('}'),
    ].reduce((a, b) => a > b ? a : b);
    final statement = before.substring(start + 1);
    // Un `TextStyle(` ou un `copyWith(` ouvert, sans parenthèse imbriquée.
    if (RegExp(r'(TextStyle|copyWith)\([^()]*$').hasMatch(statement)) {
      hits.add('\n'.allMatches(before).length + 1);
    }
  }
  return hits;
}

void main() {
  group('détecteur (auto-test)', () {
    test('signale copyWith(color: theme.inkFaint)', () {
      const src = 'final s = theme.data.copyWith(color: theme.inkFaint);';
      expect(faintTextColorLines(src), <int>[1]);
    });
    test('signale TextStyle(color: agentIdle) sur plusieurs lignes', () {
      const src =
          'final s = TextStyle(\n  fontWeight: w,\n  color: t.agentIdle,\n);';
      expect(faintTextColorLines(src), <int>[3]);
    });
    test('laisse le décoratif (trait, point, axe)', () {
      const src =
          'axisColor: theme.inkFaint,\n'
          'AgentRunState.idle => theme.agentIdle,\n'
          'Paint()..color = theme.inkFaint;';
      expect(faintTextColorLines(src), isEmpty);
    });
    test('ignore un commentaire', () {
      const src = '// theme.data.copyWith(color: theme.inkFaint)';
      expect(faintTextColorLines(src), isEmpty);
    });
  });

  test('aucun style de texte de lib/ en inkFaint ni agentIdle', () {
    final root = _root();
    final offenders = <String>[];
    for (final file in _libSources(root)) {
      for (final line in faintTextColorLines(file.readAsStringSync())) {
        offenders.add('${file.path.substring(root.path.length + 1)}:$line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'texte de moins de 24 px en ink-faint ou agentIdle (pdr-0088 F12 : '
          'ink-muted) :\n${offenders.join('\n')}',
    );
  });
}
