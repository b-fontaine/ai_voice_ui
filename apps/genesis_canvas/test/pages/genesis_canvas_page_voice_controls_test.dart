import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart'
    as flutter_test
    show testWidgets;
import 'package:testing_voice_fakes/testing_voice_fakes.dart';

import '../support/page_rig.dart';

/// Raccourcis `M` (micro) et `Échap` (faire taire) et boutons de la régie
/// (014, T14) : la page porte les commandes, la session voix est la vraie sur
/// les faux de frontière (transport WebRTC, relais, canal).
void main() {
  late PageRig rig;

  // Démontage puis fermeture ordonnée de la page : le minuteur de fin
  // d'interruption de l'orbe ne doit pas survivre au test.
  void testWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => flutter_test.testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });

  FakeTransport transport() => rig.harness.transports.last;
  Finder silenceButton() => find.byKey(const Key('silence-button'));
  Finder micButton() => find.byKey(const Key('mic-button'));

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  Future<void> tapButton(WidgetTester tester, Finder button) async {
    await tester.tap(button);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  Future<void> activeSession(WidgetTester tester) async {
    rig = PageRig(tester);
    await rig.mount(tester);
    await rig.start(tester);
  }

  testWidgets('Échap sans aucun focus : la voix de l\'IA est coupée, '
      'la session reste ouverte', (tester) async {
    await activeSession(tester);
    expect(FocusManager.instance.primaryFocus?.context, isNotNull);

    await press(tester, LogicalKeyboardKey.escape);

    expect(transport().remoteAudioEnabled, isFalse);
    expect(rig.harness.session.current.runtimeType.toString(), 'Active');
  });

  testWidgets('M sans aucun focus : coupe puis rétablit le micro, la valeur '
      'cible vient de l\'état courant', (tester) async {
    await activeSession(tester);

    await press(tester, LogicalKeyboardKey.keyM);
    expect(transport().micEnabled, isFalse);
    expect(find.text('Rétablir le micro'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.keyM);
    expect(transport().micEnabled, isTrue);
    expect(find.text('Couper le micro'), findsOneWidget);
  });

  testWidgets('le bouton « Faire taire » coupe la voix de l\'IA et se '
      'désactive', (tester) async {
    await activeSession(tester);

    await tapButton(tester, silenceButton());

    expect(transport().remoteAudioEnabled, isFalse);
    expect(
      tester.widget<ButtonStyleButton>(silenceButton()).onPressed,
      isNull,
      reason: 'idempotent : inactif tant que l\'orbe est interrompue',
    );
  });

  testWidgets('après le clic sur un bouton qui se désactive, les raccourcis '
      'répondent encore', (tester) async {
    await activeSession(tester);
    // Le bouton porte le focus (clavier ou clic), puis se désactive.
    Focus.of(tester.element(find.text('Faire taire'))).requestFocus();
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('genesis-shortcuts'),
    );

    await tapButton(tester, silenceButton());
    await press(tester, LogicalKeyboardKey.keyM);

    expect(transport().micEnabled, isFalse);
  });

  testWidgets('le bouton micro coupe puis rétablit la piste locale', (
    tester,
  ) async {
    await activeSession(tester);

    await tapButton(tester, micButton());
    expect(transport().micEnabled, isFalse);
    await tapButton(tester, micButton());
    expect(transport().micEnabled, isTrue);
    await press(tester, LogicalKeyboardKey.keyM);
    expect(transport().micEnabled, isFalse);
  });

  testWidgets('Espace n\'a aucun effet', (tester) async {
    await activeSession(tester);

    await press(tester, LogicalKeyboardKey.space);

    expect(transport().remoteAudioEnabled, isTrue);
    expect(transport().micEnabled, isTrue);
  });

  testWidgets('hors session : M et Échap sont sans effet', (tester) async {
    rig = PageRig(tester);
    await rig.mount(tester);

    await press(tester, LogicalKeyboardKey.keyM);
    await press(tester, LogicalKeyboardKey.escape);

    expect(rig.harness.transports, isEmpty);
    expect(rig.errors.toString(), isEmpty);
  });
}
