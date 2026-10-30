import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/app.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../../support/pump_until.dart';

import 'package:testing_voice_fakes/testing_voice_fakes.dart';

/// État partagé entre les étapes des scénarios de session voix.
///
/// Frontières : réseau local réel (`FakeBackend`) et WebRTC (`FakeTransport`).
/// L'app est l'app réelle, configurée par `GENESIS_BACKEND_URL` comme en
/// production ; seule la fabrique de transport est remplacée.
class SessionHarness {
  SessionHarness._();

  /// Attente maximale d'un effet visible (réseau local, sockets réels).
  static const Duration wait = Duration(seconds: 10);

  static bool started = false;

  /// Nombre de requêtes `POST /canvas/reset` déjà reçues quand le speaker clique
  /// sur « Remettre à vide » : l'app en envoie aussi une au démarrage (A3),
  /// l'étape d'acceptation de A4 ne compte que celle qui suit le clic.
  static int resetsBeforeClick = 0;
  static late FakeBackend backend;
  static late FakeTransportFactory transports;

  /// Journal commun (backend et transports) pour vérifier un ordre.
  static final List<String> journal = <String>[];

  static const Key startKey = Key('start-button');
  static const Key stopKey = Key('stop-button');
  static const Key statusKey = Key('status-message');

  static Future<void> startBackend(WidgetTester tester) async {
    // Le binding de test refuse tout HTTP (400) : on rend le réseau local réel.
    HttpOverrides.global = null;
    journal.clear();
    transports = FakeTransportFactory(
      journal.add,
      offerFor: (index) =>
          'v=0\r\no=fake-transport-$index 0 0 IN IP4 0.0.0.0\r\n',
    );
    backend = (await tester.runAsync(
      () => FakeBackend.start(onEvent: journal.add),
    ))!;
    started = true;
  }

  /// Démontage de l'app puis arrêt du serveur (étape `After:` du feature).
  static Future<void> shutDown(WidgetTester tester) async {
    if (!started) return;
    started = false;
    // Le démontage peut lancer une fermeture de session (DELETE) : on laisse
    // la boucle réelle la terminer avant de couper le serveur.
    await tester.pumpWidget(const SizedBox());
    // La fermeture de la page est une chaîne asynchrone qui alterne E/S
    // réelles (DELETE, fermeture du WSS) et continuations dans la zone
    // FakeAsync : on la fait avancer par petits pas AVANT d'écouler le temps
    // simulé, sans quoi ses délais bornés (8 s simulées) expireraient avant la
    // réponse du serveur.
    final session = backend.lastSessionId;
    await pumpUntil(
      tester,
      () =>
          transports.created.every((t) => t.isReleased) &&
          (session == null || backend.appClientCount(session) == 0),
      timeout: wait,
      reason: 'la fermeture de la page ne libère pas le transport ni le WSS',
    );
    await settleReal(tester);
    // Timers armés dans la zone FakeAsync (délais, ticker) : on les écoule.
    await tester.pump(const Duration(seconds: 20));
    await tester.runAsync(backend.close);
  }

  static Future<void> launchApp(
    WidgetTester tester, {
    String? appLogPath,
    StringSink? errorSink,
    String? scenario,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GenesisCanvasApp(
        config: GenesisConfig.fromEnvironment(<String, String>{
          'GENESIS_BACKEND_URL': backend.url,
          'GENESIS_APP_LOG': ?appLogPath,
          'GENESIS_SCENARIO': ?scenario,
        }),
        voiceTransportFactory: transports.call,
        exitHandler: (_) {},
        errorSink: errorSink,
        // Frontière « temps » : le rejeu enchaîne ses messages sans attente.
        replayDelay: scenario == null ? null : (_) async {},
      ),
    );
    await tester.pump();
  }

  /// Exécute [action] dans la zone réelle puis laisse l'app consommer.
  static Future<void> onServer(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    await tester.runAsync(() async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  static Future<void> waitFor(
    WidgetTester tester,
    Finder finder,
    String reason,
  ) => pumpUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    timeout: wait,
    reason: reason,
  );

  static Future<void> tap(WidgetTester tester, Key key) async {
    await waitFor(tester, find.byKey(key), 'bouton $key absent');
    await tester.tap(find.byKey(key), warnIfMissed: false);
    await tester.pump();
  }

  /// Session ouverte de bout en bout : answer appliquée, WSS connecté.
  static Future<void> waitForActiveSession(WidgetTester tester) async {
    await pumpUntil(
      tester,
      () {
        final id = backend.lastSessionId;
        return id != null && backend.appClientCount(id) == 1;
      },
      timeout: wait,
      reason: "aucun WSS /app ouvert par l'app sur la session du relais",
    );
    await waitFor(tester, find.byKey(stopKey), 'bouton Arrêter absent');
  }

  /// Publie sur la session courante les enveloppes de la fixture retenues par
  /// [where], une par une (l'app les reçoit dans l'ordre, sans regroupement).
  static Future<void> emitFixture(
    WidgetTester tester,
    bool Function(Map<String, Object?> envelope) where,
  ) async {
    final session = backend.lastSessionId!;
    // Lecture de fichier : E/S réelle, donc hors de la zone FakeAsync (sinon
    // l'attente ne se termine jamais).
    final all = (await tester.runAsync(
      () => FakeBackend.fixtureEnvelopes(session),
    ))!;
    final envelopes = all.where(where).toList();
    assert(envelopes.isNotEmpty, 'aucune enveloppe de la fixture retenue');
    for (final envelope in envelopes) {
      await onServer(tester, () async => backend.emitEnvelope(envelope));
    }
  }

  static bool isType(Map<String, Object?> e, String type) => e['type'] == type;

  static bool isActivity(Map<String, Object?> e, String state) =>
      e['type'] == 'agent.activity' &&
      (e['data']! as Map<String, Object?>)['state'] == state;

  /// Attend que le dernier transport créé soit libéré (`stop` puis `dispose`).
  static Future<void> waitForTransportReleased(WidgetTester tester) async {
    await pumpUntil(
      tester,
      () => transports.created.isNotEmpty && transports.created.last.isReleased,
      timeout: wait,
      reason:
          'transport non libéré (stop puis dispose) : '
          '${transports.created.map((t) => t.calls).toList()}',
    );
  }

  /// Niveau lissé affiché par l'orbe (0 = repos).
  static double orbLevel(WidgetTester tester) =>
      tester.widget<VoiceOrb>(find.byKey(const Key('voice-orb'))).level.value;

  static String? statusMessage(WidgetTester tester) {
    final finder = find.byKey(statusKey);
    if (finder.evaluate().isEmpty) return null;
    final texts = find.descendant(
      of: finder,
      matching: find.byType(Text),
      matchRoot: true,
    );
    return tester.widgetList<Text>(texts).map((t) => t.data ?? '').join(' ');
  }
}
