import 'dart:io';

import 'package:test/test.dart';

/// Remonte depuis le répertoire courant jusqu'à la racine du workspace
/// (celle qui contient `packages/shared/backend_channel`).
File _backendChannelPubspec() {
  Directory dir = Directory.current.absolute;
  while (true) {
    final File candidate = File(
      '${dir.path}/packages/shared/backend_channel/pubspec.yaml',
    );
    if (candidate.existsSync()) return candidate;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail('pubspec.yaml de backend_channel introuvable');
    }
    dir = parent;
  }
}

void main() {
  test('backend_channel ne dépend ni de entity_session ni d\'une feature', () {
    final String content = _backendChannelPubspec().readAsStringSync();
    expect(content, isNot(contains('entity_session')));
    expect(content, isNot(matches(RegExp(r'^\s*feature_', multiLine: true))));
  });
}
